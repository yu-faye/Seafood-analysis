# Azure Data Factory Deployment Script for Norwegian Seafood Analysis
# This script deploys the complete ADF solution to Azure

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location = "West Europe",
    
    [Parameter(Mandatory=$true)]
    [string]$DataFactoryName,
    
    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,
    
    [Parameter(Mandatory=$true)]
    [string]$SqlServerName,
    
    [Parameter(Mandatory=$true)]
    [string]$SqlDatabaseName,
    
    [Parameter(Mandatory=$true)]
    [string]$SqlUsername,
    
    [Parameter(Mandatory=$true)]
    [string]$SqlPassword
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🚀 Starting Azure Data Factory Deployment for Norwegian Seafood Analysis" -ForegroundColor Green
Write-Host "=" * 70

# Check if Azure CLI is installed and user is logged in
Write-Host "🔍 Checking Azure CLI and authentication..." -ForegroundColor Yellow
try {
    $azAccount = az account show 2>$null | ConvertFrom-Json
    if (-not $azAccount) {
        Write-Error "Not logged in to Azure CLI. Please run 'az login' first."
        exit 1
    }
    Write-Host "✅ Logged in as: $($azAccount.user.name)" -ForegroundColor Green
} catch {
    Write-Error "Azure CLI not found or not logged in. Please install Azure CLI and run 'az login'."
    exit 1
}

# Create resource group if it doesn't exist
Write-Host "📁 Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
$rgExists = az group exists --name $ResourceGroupName
if ($rgExists -eq "false") {
    az group create --name $ResourceGroupName --location $Location
    Write-Host "✅ Resource group created" -ForegroundColor Green
} else {
    Write-Host "✅ Resource group already exists" -ForegroundColor Green
}

# Deploy ARM template
Write-Host "🏗️ Deploying Azure resources..." -ForegroundColor Yellow
$templateFile = ".\arm-templates\data-factory-template.json"
$parameters = @{
    "dataFactoryName" = $DataFactoryName
    "storageAccountName" = $StorageAccountName
    "sqlServerName" = $SqlServerName
    "sqlDatabaseName" = $SqlDatabaseName
    "location" = $Location
}

$deploymentResult = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file $templateFile `
    --parameters dataFactoryName=$DataFactoryName storageAccountName=$StorageAccountName sqlServerName=$SqlServerName sqlDatabaseName=$SqlDatabaseName location=$Location `
    --output json | ConvertFrom-Json

if ($deploymentResult.properties.provisioningState -eq "Succeeded") {
    Write-Host "✅ Azure resources deployed successfully" -ForegroundColor Green
} else {
    Write-Error "❌ Deployment failed: $($deploymentResult.properties.error.message)"
    exit 1
}

# Get storage account key
Write-Host "🔑 Getting storage account key..." -ForegroundColor Yellow
$storageKey = az storage account keys list --resource-group $ResourceGroupName --account-name $StorageAccountName --query "[0].value" -o tsv

# Create containers in storage account
Write-Host "📦 Creating storage containers..." -ForegroundColor Yellow
az storage container create --name "raw-data" --account-name $StorageAccountName --account-key $storageKey
az storage container create --name "processed-data" --account-name $StorageAccountName --account-key $storageKey
az storage container create --name "insights" --account-name $StorageAccountName --account-key $storageKey
Write-Host "✅ Storage containers created" -ForegroundColor Green

# Deploy ADF artifacts
Write-Host "📊 Deploying ADF artifacts..." -ForegroundColor Yellow

# Set ADF context
az datafactory configure --resource-group $ResourceGroupName --factory-name $DataFactoryName

# Deploy linked services
Write-Host "🔗 Deploying linked services..." -ForegroundColor Yellow
az datafactory linked-service create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "AzureDataLakeStorageGen2" --file ".\linked-services\azure-storage-linked-service.json"
az datafactory linked-service create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "AzureSqlDatabase" --file ".\linked-services\azure-sql-linked-service.json"
Write-Host "✅ Linked services deployed" -ForegroundColor Green

# Deploy datasets
Write-Host "📋 Deploying datasets..." -ForegroundColor Yellow
az datafactory dataset create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "RawSeafoodData" --file ".\datasets\raw-seafood-data.json"
az datafactory dataset create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "ProcessedSeafoodData" --file ".\datasets\processed-seafood-data.json"
Write-Host "✅ Datasets deployed" -ForegroundColor Green

# Deploy pipeline
Write-Host "🔧 Deploying pipeline..." -ForegroundColor Yellow
az datafactory pipeline create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "SeafoodDataProcessingPipeline" --file ".\pipelines\seafood-data-pipeline.json"
Write-Host "✅ Pipeline deployed" -ForegroundColor Green

# Create SQL database tables
Write-Host "🗄️ Creating SQL database tables..." -ForegroundColor Yellow
$sqlConnectionString = "Server=tcp:$SqlServerName.database.windows.net,1433;Initial Catalog=$SqlDatabaseName;Persist Security Info=False;User ID=$SqlUsername;Password=$SqlPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

# Note: In a real deployment, you would use sqlcmd or another tool to execute the SQL script
Write-Host "⚠️ Please manually execute the SQL script: .\sql\create-tables.sql" -ForegroundColor Yellow
Write-Host "   Connection string: $sqlConnectionString" -ForegroundColor Yellow

# Create trigger for daily execution
Write-Host "⏰ Creating daily trigger..." -ForegroundColor Yellow
$triggerJson = @{
    "name" = "DailySeafoodProcessing"
    "properties" = @{
        "type" = "ScheduleTrigger"
        "typeProperties" = @{
            "recurrence" = @{
                "frequency" = "Day"
                "interval" = 1
                "startTime" = (Get-Date).AddDays(1).ToString("yyyy-MM-ddT06:00:00Z")
                "timeZone" = "UTC"
            }
        }
        "pipelines" = @(
            @{
                "pipelineReference" = @{
                    "type" = "PipelineReference"
                    "referenceName" = "SeafoodDataProcessingPipeline"
                }
                "parameters" = @{
                    "storageAccount" = $StorageAccountName
                }
            }
        )
    }
} | ConvertTo-Json -Depth 10

$triggerJson | Out-File -FilePath ".\temp-trigger.json" -Encoding UTF8
az datafactory trigger create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "DailySeafoodProcessing" --file ".\temp-trigger.json"
Remove-Item ".\temp-trigger.json"
Write-Host "✅ Daily trigger created" -ForegroundColor Green

# Start the trigger
Write-Host "▶️ Starting trigger..." -ForegroundColor Yellow
az datafactory trigger start --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "DailySeafoodProcessing"
Write-Host "✅ Trigger started" -ForegroundColor Green

# Display summary
Write-Host "`n🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "=" * 70
Write-Host "📊 Data Factory: $DataFactoryName" -ForegroundColor Cyan
Write-Host "💾 Storage Account: $StorageAccountName" -ForegroundColor Cyan
Write-Host "🗄️ SQL Server: $SqlServerName" -ForegroundColor Cyan
Write-Host "📋 SQL Database: $SqlDatabaseName" -ForegroundColor Cyan
Write-Host "🔗 Resource Group: $ResourceGroupName" -ForegroundColor Cyan
Write-Host "📍 Location: $Location" -ForegroundColor Cyan

Write-Host "`n📋 NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Execute the SQL script: .\sql\create-tables.sql" -ForegroundColor White
Write-Host "2. Upload the Databricks notebook: .\scripts\databricks-notebook.py" -ForegroundColor White
Write-Host "3. Configure Power BI connection to the SQL database" -ForegroundColor White
Write-Host "4. Test the pipeline by running it manually" -ForegroundColor White
Write-Host "5. Monitor the pipeline execution in the ADF portal" -ForegroundColor White

Write-Host "`n🔗 USEFUL LINKS:" -ForegroundColor Yellow
Write-Host "• ADF Portal: https://portal.azure.com/#@$($azAccount.tenantId)/resource/subscriptions/$($azAccount.id)/resourceGroups/$ResourceGroupName/providers/Microsoft.DataFactory/factories/$DataFactoryName" -ForegroundColor White
Write-Host "• Storage Account: https://portal.azure.com/#@$($azAccount.tenantId)/resource/subscriptions/$($azAccount.id)/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$StorageAccountName" -ForegroundColor White
Write-Host "• SQL Database: https://portal.azure.com/#@$($azAccount.tenantId)/resource/subscriptions/$($azAccount.id)/resourceGroups/$ResourceGroupName/providers/Microsoft.Sql/servers/$SqlServerName" -ForegroundColor White

Write-Host "`n✅ Norwegian Seafood Analysis is now running on Azure Data Factory!" -ForegroundColor Green

