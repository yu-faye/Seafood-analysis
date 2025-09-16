# Global Fishing Watch Analysis - Azure Data Factory Deployment Script
# Updated for port visit analysis and investment insights

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
    [string]$SqlPassword,
    
    [Parameter(Mandatory=$true)]
    [string]$GFWApiToken,
    
    [Parameter(Mandatory=$false)]
    [string]$DatabricksWorkspaceName = "$($ResourceGroupName)-databricks",
    
    [Parameter(Mandatory=$false)]
    [string]$KeyVaultName = "$($ResourceGroupName)-kv"
)

Write-Host "🚀 Starting Global Fishing Watch Analysis Deployment..." -ForegroundColor Green
Write-Host "=" * 60

# Function to check if resource exists
function Test-AzureResource {
    param(
        [string]$ResourceName,
        [string]$ResourceType,
        [string]$ResourceGroup
    )
    
    try {
        $resource = Get-AzResource -ResourceGroupName $ResourceGroup -Name $ResourceName -ResourceType $ResourceType -ErrorAction SilentlyContinue
        return $null -ne $resource
    }
    catch {
        return $false
    }
}

# Function to wait for resource deployment
function Wait-ForDeployment {
    param(
        [string]$ResourceName,
        [string]$ResourceType,
        [string]$ResourceGroup,
        [int]$TimeoutMinutes = 10
    )
    
    Write-Host "⏳ Waiting for $ResourceName deployment..." -ForegroundColor Yellow
    $timeout = (Get-Date).AddMinutes($TimeoutMinutes)
    
    do {
        Start-Sleep -Seconds 30
        $exists = Test-AzureResource -ResourceName $ResourceName -ResourceType $ResourceType -ResourceGroup $ResourceGroup
        if ((Get-Date) -gt $timeout) {
            throw "Timeout waiting for $ResourceName deployment"
        }
    } while (-not $exists)
    
    Write-Host "✅ $ResourceName deployed successfully" -ForegroundColor Green
}

try {
    # Check if logged in to Azure
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "❌ Please login to Azure first using Connect-AzAccount" -ForegroundColor Red
        exit 1
    }

    Write-Host "📋 Deployment Configuration:" -ForegroundColor Cyan
    Write-Host "  Resource Group: $ResourceGroupName"
    Write-Host "  Location: $Location"
    Write-Host "  Data Factory: $DataFactoryName"
    Write-Host "  Storage Account: $StorageAccountName"
    Write-Host "  SQL Server: $SqlServerName"
    Write-Host "  SQL Database: $SqlDatabaseName"
    Write-Host "  Databricks Workspace: $DatabricksWorkspaceName"
    Write-Host "  Key Vault: $KeyVaultName"
    Write-Host ""

    # 1. Create Resource Group
    Write-Host "🏗️  Step 1: Creating Resource Group..." -ForegroundColor Blue
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        New-AzResourceGroup -Name $ResourceGroupName -Location $Location
        Write-Host "✅ Resource Group created: $ResourceGroupName" -ForegroundColor Green
    } else {
        Write-Host "✅ Resource Group already exists: $ResourceGroupName" -ForegroundColor Green
    }

    # 2. Create Key Vault for storing secrets
    Write-Host "🔐 Step 2: Creating Key Vault..." -ForegroundColor Blue
    if (-not (Test-AzureResource -ResourceName $KeyVaultName -ResourceType "Microsoft.KeyVault/vaults" -ResourceGroup $ResourceGroupName)) {
        $keyVault = New-AzKeyVault -ResourceGroupName $ResourceGroupName -Name $KeyVaultName -Location $Location -EnabledForTemplateDeployment
        Write-Host "✅ Key Vault created: $KeyVaultName" -ForegroundColor Green
        
        # Store secrets
        $sqlPasswordSecure = ConvertTo-SecureString -String $SqlPassword -AsPlainText -Force
        $gfwTokenSecure = ConvertTo-SecureString -String $GFWApiToken -AsPlainText -Force
        
        Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name "SqlPassword" -SecretValue $sqlPasswordSecure
        Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name "GFWApiToken" -SecretValue $gfwTokenSecure
        Write-Host "✅ Secrets stored in Key Vault" -ForegroundColor Green
    } else {
        Write-Host "✅ Key Vault already exists: $KeyVaultName" -ForegroundColor Green
    }

    # 3. Create Storage Account (Data Lake Gen2)
    Write-Host "💾 Step 3: Creating Storage Account..." -ForegroundColor Blue
    if (-not (Test-AzureResource -ResourceName $StorageAccountName -ResourceType "Microsoft.Storage/storageAccounts" -ResourceGroup $ResourceGroupName)) {
        $storageAccount = New-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -Location $Location -SkuName "Standard_LRS" -Kind "StorageV2" -EnableHierarchicalNamespace $true
        Wait-ForDeployment -ResourceName $StorageAccountName -ResourceType "Microsoft.Storage/storageAccounts" -ResourceGroup $ResourceGroupName
        
        # Create containers
        $ctx = $storageAccount.Context
        New-AzStorageContainer -Name "raw-data" -Context $ctx -Permission Off
        New-AzStorageContainer -Name "processed-data" -Context $ctx -Permission Off
        New-AzStorageContainer -Name "insights" -Context $ctx -Permission Off
        Write-Host "✅ Storage Account and containers created" -ForegroundColor Green
    } else {
        Write-Host "✅ Storage Account already exists: $StorageAccountName" -ForegroundColor Green
    }

    # 4. Create SQL Server and Database
    Write-Host "🗄️  Step 4: Creating SQL Server and Database..." -ForegroundColor Blue
    if (-not (Test-AzureResource -ResourceName $SqlServerName -ResourceType "Microsoft.Sql/servers" -ResourceGroup $ResourceGroupName)) {
        $sqlPasswordSecure = ConvertTo-SecureString -String $SqlPassword -AsPlainText -Force
        $sqlCredential = New-Object System.Management.Automation.PSCredential ($SqlUsername, $sqlPasswordSecure)
        
        $sqlServer = New-AzSqlServer -ResourceGroupName $ResourceGroupName -ServerName $SqlServerName -Location $Location -SqlAdministratorCredentials $sqlCredential
        
        # Configure firewall to allow Azure services
        New-AzSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $SqlServerName -FirewallRuleName "AllowAzureServices" -StartIpAddress "0.0.0.0" -EndIpAddress "0.0.0.0"
        
        # Create database
        New-AzSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $SqlServerName -DatabaseName $SqlDatabaseName -Edition "Basic"
        Write-Host "✅ SQL Server and Database created" -ForegroundColor Green
    } else {
        Write-Host "✅ SQL Server already exists: $SqlServerName" -ForegroundColor Green
    }

    # 5. Create Databricks Workspace
    Write-Host "📊 Step 5: Creating Databricks Workspace..." -ForegroundColor Blue
    if (-not (Test-AzureResource -ResourceName $DatabricksWorkspaceName -ResourceType "Microsoft.Databricks/workspaces" -ResourceGroup $ResourceGroupName)) {
        # Use ARM template for Databricks deployment
        $databricksTemplate = @{
            '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
            contentVersion = "1.0.0.0"
            parameters = @{
                workspaceName = @{
                    type = "string"
                    defaultValue = $DatabricksWorkspaceName
                }
                location = @{
                    type = "string"
                    defaultValue = $Location
                }
            }
            resources = @(
                @{
                    type = "Microsoft.Databricks/workspaces"
                    apiVersion = "2018-04-01"
                    name = "[parameters('workspaceName')]"
                    location = "[parameters('location')]"
                    properties = @{
                        managedResourceGroupId = "[subscriptionResourceId('Microsoft.Resources/resourceGroups', concat('databricks-rg-', parameters('workspaceName'), '-', uniqueString(parameters('workspaceName'), resourceGroup().id)))]"
                    }
                }
            )
        }
        
        $templateFile = "$env:TEMP\databricks-template.json"
        $databricksTemplate | ConvertTo-Json -Depth 10 | Out-File -FilePath $templateFile
        
        New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $templateFile -workspaceName $DatabricksWorkspaceName -location $Location
        Write-Host "✅ Databricks Workspace created" -ForegroundColor Green
    } else {
        Write-Host "✅ Databricks Workspace already exists: $DatabricksWorkspaceName" -ForegroundColor Green
    }

    # 6. Create Data Factory
    Write-Host "🏭 Step 6: Creating Data Factory..." -ForegroundColor Blue
    if (-not (Test-AzureResource -ResourceName $DataFactoryName -ResourceType "Microsoft.DataFactory/factories" -ResourceGroup $ResourceGroupName)) {
        $dataFactory = Set-AzDataFactoryV2 -ResourceGroupName $ResourceGroupName -Name $DataFactoryName -Location $Location
        Write-Host "✅ Data Factory created: $DataFactoryName" -ForegroundColor Green
    } else {
        Write-Host "✅ Data Factory already exists: $DataFactoryName" -ForegroundColor Green
    }

    # 7. Deploy Data Factory Components
    Write-Host "⚙️  Step 7: Deploying Data Factory Components..." -ForegroundColor Blue
    
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $baseDir = Split-Path -Parent $scriptDir
    
    # Get storage account key
    $storageKey = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName)[0].Value
    
    Write-Host "  📡 Deploying Linked Services..." -ForegroundColor Cyan
    
    # Deploy Azure Storage Linked Service
    $storageLinkedServiceContent = Get-Content "$baseDir\linked-services\azure-storage-linked-service.json" | ConvertFrom-Json
    $storageLinkedServiceContent.properties.typeProperties.url = "https://$StorageAccountName.dfs.core.windows.net"
    $storageLinkedServiceContent.properties.typeProperties.accountKey.value = $storageKey
    
    $tempStorageFile = "$env:TEMP\storage-linked-service.json"
    $storageLinkedServiceContent | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempStorageFile
    Set-AzDataFactoryV2LinkedService -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -File $tempStorageFile -Force
    
    # Deploy SQL Linked Service
    $sqlLinkedServiceContent = Get-Content "$baseDir\linked-services\azure-sql-linked-service.json" | ConvertFrom-Json
    $connectionString = "Server=tcp:$SqlServerName.database.windows.net,1433;Initial Catalog=$SqlDatabaseName;Persist Security Info=False;User ID=$SqlUsername;Password=$SqlPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
    $sqlLinkedServiceContent.properties.typeProperties.connectionString = $connectionString
    
    $tempSqlFile = "$env:TEMP\sql-linked-service.json"
    $sqlLinkedServiceContent | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempSqlFile
    Set-AzDataFactoryV2LinkedService -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -File $tempSqlFile -Force
    
    # Deploy GFW API Linked Service
    Set-AzDataFactoryV2LinkedService -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -File "$baseDir\linked-services\global-fishing-watch-api.json" -Force
    
    Write-Host "  📊 Deploying Datasets..." -ForegroundColor Cyan
    
    # Deploy Datasets
    $datasets = @(
        "gfw-events-api.json",
        "raw-fishing-events-data.json", 
        "processed-fishing-events-data.json",
        "fishing-events-table.json"
    )
    
    foreach ($dataset in $datasets) {
        Set-AzDataFactoryV2Dataset -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -File "$baseDir\datasets\$dataset" -Force
    }
    
    Write-Host "  🔄 Deploying Pipeline..." -ForegroundColor Cyan
    
    # Deploy Pipeline
    Set-AzDataFactoryV2Pipeline -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -File "$baseDir\pipelines\fishing-events-pipeline.json" -Force
    
    Write-Host "✅ Data Factory components deployed successfully" -ForegroundColor Green

    # 8. Execute SQL Scripts
    Write-Host "🗄️  Step 8: Setting up Database Schema..." -ForegroundColor Blue
    
    $sqlScriptPath = "$baseDir\sql\create-fishing-events-tables.sql"
    if (Test-Path $sqlScriptPath) {
        $sqlScript = Get-Content $sqlScriptPath -Raw
        
        # Connect to SQL Database and execute script
        $connectionString = "Server=tcp:$SqlServerName.database.windows.net,1433;Initial Catalog=$SqlDatabaseName;Persist Security Info=False;User ID=$SqlUsername;Password=$SqlPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
        
        try {
            # Split script by GO statements and execute each batch
            $batches = $sqlScript -split '\bGO\b'
            
            Add-Type -AssemblyName "System.Data"
            $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
            $connection.Open()
            
            foreach ($batch in $batches) {
                $batch = $batch.Trim()
                if ($batch -ne "") {
                    $command = New-Object System.Data.SqlClient.SqlCommand($batch, $connection)
                    $command.ExecuteNonQuery() | Out-Null
                }
            }
            
            $connection.Close()
            Write-Host "✅ Database schema created successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠️  Warning: Could not execute SQL script automatically. Please run it manually." -ForegroundColor Yellow
            Write-Host "   SQL Script location: $sqlScriptPath" -ForegroundColor Yellow
        }
    }

    # 9. Create Pipeline Trigger
    Write-Host "⏰ Step 9: Creating Pipeline Trigger..." -ForegroundColor Blue
    
    $triggerName = "DailyFishingEventsProcessing"
    $trigger = Get-AzDataFactoryV2Trigger -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -Name $triggerName -ErrorAction SilentlyContinue
    
    if (-not $trigger) {
        $triggerDefinition = @{
            name = $triggerName
            properties = @{
                type = "ScheduleTrigger"
                typeProperties = @{
                    recurrence = @{
                        frequency = "Day"
                        interval = 1
                        startTime = (Get-Date).AddDays(1).ToString("yyyy-MM-ddT06:00:00Z")
                        timeZone = "UTC"
                    }
                }
                pipelines = @(
                    @{
                        pipelineReference = @{
                            type = "PipelineReference"
                            referenceName = "FishingEventsDataProcessingPipeline"
                        }
                        parameters = @{
                            storageAccount = $StorageAccountName
                            gfwApiToken = $GFWApiToken
                        }
                    }
                )
            }
        }
        
        $tempTriggerFile = "$env:TEMP\daily-trigger.json"
        $triggerDefinition | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempTriggerFile
        
        Set-AzDataFactoryV2Trigger -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -File $tempTriggerFile -Force
        Write-Host "✅ Daily trigger created (starts tomorrow at 06:00 UTC)" -ForegroundColor Green
    } else {
        Write-Host "✅ Trigger already exists: $triggerName" -ForegroundColor Green
    }

    # 10. Final Summary
    Write-Host ""
    Write-Host "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "=" * 60
    Write-Host ""
    Write-Host "📋 Deployment Summary:" -ForegroundColor Cyan
    Write-Host "  ✅ Resource Group: $ResourceGroupName"
    Write-Host "  ✅ Key Vault: $KeyVaultName"
    Write-Host "  ✅ Storage Account: $StorageAccountName"
    Write-Host "  ✅ SQL Server: $SqlServerName"
    Write-Host "  ✅ SQL Database: $SqlDatabaseName"
    Write-Host "  ✅ Databricks Workspace: $DatabricksWorkspaceName"
    Write-Host "  ✅ Data Factory: $DataFactoryName"
    Write-Host "  ✅ Pipeline: FishingEventsDataProcessingPipeline"
    Write-Host "  ✅ Daily Trigger: Enabled (06:00 UTC)"
    Write-Host ""
    Write-Host "🔗 Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Open Azure Data Factory Studio: https://adf.azure.com"
    Write-Host "  2. Upload Databricks notebook: $baseDir\scripts\databricks-fishing-events-processor.py"
    Write-Host "  3. Configure Databricks cluster and update linked service"
    Write-Host "  4. Test the pipeline by running it manually"
    Write-Host "  5. Monitor pipeline execution and data quality"
    Write-Host ""
    Write-Host "📊 Access URLs:" -ForegroundColor Cyan
    Write-Host "  • Data Factory: https://portal.azure.com/#@/resource/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.DataFactory/factories/$DataFactoryName"
    Write-Host "  • Databricks: https://portal.azure.com/#@/resource/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.Databricks/workspaces/$DatabricksWorkspaceName"
    Write-Host "  • SQL Database: https://portal.azure.com/#@/resource/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.Sql/servers/$SqlServerName/databases/$SqlDatabaseName"
    Write-Host ""
    Write-Host "💡 The pipeline is scheduled to run daily at 06:00 UTC" -ForegroundColor Green
    Write-Host "💡 Check the monitoring section in Data Factory for execution status" -ForegroundColor Green
    Write-Host ""

}
catch {
    Write-Host ""
    Write-Host "❌ DEPLOYMENT FAILED!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "🔍 Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check Azure permissions (Contributor role required)"
    Write-Host "  2. Verify resource names are unique globally"
    Write-Host "  3. Check Azure subscription limits"
    Write-Host "  4. Review error details above"
    Write-Host ""
    exit 1
}
