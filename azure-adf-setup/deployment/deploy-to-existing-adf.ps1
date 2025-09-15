# Deploy Norwegian Seafood Analysis to Existing Azure Data Factory
# This script deploys the ADF artifacts to an already created Data Factory

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
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

Write-Host "🚀 Deploying Norwegian Seafood Analysis to Existing ADF" -ForegroundColor Green
Write-Host "=" * 60

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

# Verify resources exist
Write-Host "🔍 Verifying Azure resources..." -ForegroundColor Yellow

# Check Data Factory
try {
    $adf = az datafactory show --resource-group $ResourceGroupName --name $DataFactoryName --output json | ConvertFrom-Json
    Write-Host "✅ Data Factory found: $($adf.name)" -ForegroundColor Green
} catch {
    Write-Error "❌ Data Factory '$DataFactoryName' not found in resource group '$ResourceGroupName'"
    exit 1
}

# Check Storage Account
try {
    $storage = az storage account show --resource-group $ResourceGroupName --name $StorageAccountName --output json | ConvertFrom-Json
    Write-Host "✅ Storage Account found: $($storage.name)" -ForegroundColor Green
} catch {
    Write-Error "❌ Storage Account '$StorageAccountName' not found in resource group '$ResourceGroupName'"
    exit 1
}

# Check SQL Server
try {
    $sqlServer = az sql server show --resource-group $ResourceGroupName --name $SqlServerName --output json | ConvertFrom-Json
    Write-Host "✅ SQL Server found: $($sqlServer.name)" -ForegroundColor Green
} catch {
    Write-Error "❌ SQL Server '$SqlServerName' not found in resource group '$ResourceGroupName'"
    exit 1
}

# Get storage account key
Write-Host "🔑 Getting storage account key..." -ForegroundColor Yellow
$storageKey = az storage account keys list --resource-group $ResourceGroupName --account-name $StorageAccountName --query "[0].value" -o tsv

# Create containers if they don't exist
Write-Host "📦 Creating storage containers..." -ForegroundColor Yellow
$containers = @("raw-data", "processed-data", "insights")
foreach ($container in $containers) {
    try {
        az storage container create --name $container --account-name $StorageAccountName --account-key $storageKey
        Write-Host "✅ Container '$container' created" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Container '$container' might already exist" -ForegroundColor Yellow
    }
}

# Set ADF context
Write-Host "🎯 Setting ADF context..." -ForegroundColor Yellow
az datafactory configure --resource-group $ResourceGroupName --factory-name $DataFactoryName

# Deploy linked services
Write-Host "🔗 Deploying linked services..." -ForegroundColor Yellow

# Create storage linked service with actual values
$storageLinkedService = @{
    "name" = "AzureDataLakeStorageGen2"
    "properties" = @{
        "type" = "AzureBlobFS"
        "typeProperties" = @{
            "url" = "https://$StorageAccountName.dfs.core.windows.net"
            "accountKey" = @{
                "type" = "SecureString"
                "value" = $storageKey
            }
        }
    }
} | ConvertTo-Json -Depth 10

$storageLinkedService | Out-File -FilePath ".\temp-storage-linked-service.json" -Encoding UTF8
az datafactory linked-service create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "AzureDataLakeStorageGen2" --file ".\temp-storage-linked-service.json"
Remove-Item ".\temp-storage-linked-service.json"
Write-Host "✅ Storage linked service deployed" -ForegroundColor Green

# Create SQL linked service
$sqlLinkedService = @{
    "name" = "AzureSqlDatabase"
    "properties" = @{
        "type" = "AzureSqlDatabase"
        "typeProperties" = @{
            "connectionString" = "Server=tcp:$SqlServerName.database.windows.net,1433;Initial Catalog=$SqlDatabaseName;Persist Security Info=False;User ID=$SqlUsername;Password=$SqlPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
            "password" = @{
                "type" = "SecureString"
                "value" = $SqlPassword
            }
        }
    }
} | ConvertTo-Json -Depth 10

$sqlLinkedService | Out-File -FilePath ".\temp-sql-linked-service.json" -Encoding UTF8
az datafactory linked-service create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "AzureSqlDatabase" --file ".\temp-sql-linked-service.json"
Remove-Item ".\temp-sql-linked-service.json"
Write-Host "✅ SQL linked service deployed" -ForegroundColor Green

# Deploy datasets
Write-Host "📋 Deploying datasets..." -ForegroundColor Yellow
az datafactory dataset create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "RawSeafoodData" --file ".\datasets\raw-seafood-data.json"
az datafactory dataset create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "ProcessedSeafoodData" --file ".\datasets\processed-seafood-data.json"
Write-Host "✅ Datasets deployed" -ForegroundColor Green

# Deploy pipeline
Write-Host "🔧 Deploying pipeline..." -ForegroundColor Yellow
az datafactory pipeline create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "SeafoodDataProcessingPipeline" --file ".\pipelines\seafood-data-pipeline.json"
Write-Host "✅ Pipeline deployed" -ForegroundColor Green

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
Write-Host "=" * 60
Write-Host "📊 Data Factory: $DataFactoryName" -ForegroundColor Cyan
Write-Host "💾 Storage Account: $StorageAccountName" -ForegroundColor Cyan
Write-Host "🗄️ SQL Server: $SqlServerName" -ForegroundColor Cyan
Write-Host "📋 SQL Database: $SqlDatabaseName" -ForegroundColor Cyan
Write-Host "🔗 Resource Group: $ResourceGroupName" -ForegroundColor Cyan

Write-Host "`n📋 NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Execute the SQL script: .\sql\create-tables.sql" -ForegroundColor White
Write-Host "2. Upload the Databricks notebook: .\scripts\databricks-notebook.py" -ForegroundColor White
Write-Host "3. Test the pipeline by running it manually in ADF Studio" -ForegroundColor White
Write-Host "4. Configure Power BI connection to the SQL database" -ForegroundColor White

Write-Host "`n🔗 USEFUL LINKS:" -ForegroundColor Yellow
Write-Host "• ADF Studio: https://adf.azure.com/en/factory/$DataFactoryName" -ForegroundColor White
Write-Host "• Azure Portal: https://portal.azure.com" -ForegroundColor White

Write-Host "`n✅ Norwegian Seafood Analysis is now deployed to your existing ADF!" -ForegroundColor Green

