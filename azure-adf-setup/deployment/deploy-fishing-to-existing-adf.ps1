# Deploy Global Fishing Watch Analysis to Existing Azure Data Factory
# This script deploys the fishing analysis artifacts to an already created Data Factory

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
    [string]$SqlPassword,
    
    [Parameter(Mandatory=$true)]
    [string]$GFWApiToken,
    
    [Parameter(Mandatory=$false)]
    [string]$DatabricksWorkspaceName
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🐟 Deploying Global Fishing Watch Analysis to Existing ADF" -ForegroundColor Green
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

# Create containers for fishing data
Write-Host "📦 Creating storage containers for fishing data..." -ForegroundColor Yellow
$containers = @("raw-data", "processed-data", "insights")
foreach ($container in $containers) {
    try {
        az storage container create --name $container --account-name $StorageAccountName --account-key $storageKey
        
        # Create subdirectories for fishing events
        if ($container -eq "raw-data") {
            az storage blob directory create --container-name $container --directory-path "fishing-events" --account-name $StorageAccountName --account-key $storageKey
        }
        if ($container -eq "processed-data") {
            az storage blob directory create --container-name $container --directory-path "fishing-events" --account-name $StorageAccountName --account-key $storageKey
        }
        
        Write-Host "✅ Container '$container' ready for fishing data" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Container '$container' might already exist" -ForegroundColor Yellow
    }
}

# Deploy Global Fishing Watch API linked service
Write-Host "🌐 Deploying Global Fishing Watch API linked service..." -ForegroundColor Yellow
$gfwLinkedService = @{
    "name" = "GlobalFishingWatchAPI"
    "properties" = @{
        "type" = "RestService"
        "typeProperties" = @{
            "url" = "https://gateway.api.globalfishingwatch.org"
            "enableServerCertificateValidation" = $true
            "authenticationType" = "Anonymous"
        }
        "parameters" = @{
            "apiToken" = @{
                "type" = "string"
            }
        }
    }
} | ConvertTo-Json -Depth 10

$gfwLinkedService | Out-File -FilePath ".\temp-gfw-linked-service.json" -Encoding UTF8
az datafactory linked-service create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "GlobalFishingWatchAPI" --file ".\temp-gfw-linked-service.json"
Remove-Item ".\temp-gfw-linked-service.json"
Write-Host "✅ GFW API linked service deployed" -ForegroundColor Green

# Update storage linked service for Data Lake Gen2
Write-Host "💾 Updating storage linked service for Data Lake Gen2..." -ForegroundColor Yellow
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
Write-Host "✅ Storage linked service updated" -ForegroundColor Green

# Update SQL linked service
Write-Host "🗄️ Updating SQL linked service..." -ForegroundColor Yellow
$sqlLinkedService = @{
    "name" = "AzureSqlDatabase"
    "properties" = @{
        "type" = "AzureSqlDatabase"
        "typeProperties" = @{
            "connectionString" = "Server=tcp:$SqlServerName.database.windows.net,1433;Initial Catalog=$SqlDatabaseName;Persist Security Info=False;User ID=$SqlUsername;Password=$SqlPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
        }
    }
} | ConvertTo-Json -Depth 10

$sqlLinkedService | Out-File -FilePath ".\temp-sql-linked-service.json" -Encoding UTF8
az datafactory linked-service create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "AzureSqlDatabase" --file ".\temp-sql-linked-service.json"
Remove-Item ".\temp-sql-linked-service.json"
Write-Host "✅ SQL linked service updated" -ForegroundColor Green

# Deploy Databricks linked service if workspace name provided
if ($DatabricksWorkspaceName) {
    Write-Host "📊 Deploying Databricks linked service..." -ForegroundColor Yellow
    $databricksLinkedService = @{
        "name" = "AzureDatabricks"
        "properties" = @{
            "type" = "AzureDatabricks"
            "typeProperties" = @{
                "domain" = "https://adb-$(Get-Random).azuredatabricks.net"
                "newClusterNodeType" = "Standard_DS3_v2"
                "newClusterNumOfWorker" = "1"
                "newClusterVersion" = "7.3.x-scala2.12"
                "newClusterInitScripts" = @()
            }
        }
    } | ConvertTo-Json -Depth 10
    
    $databricksLinkedService | Out-File -FilePath ".\temp-databricks-linked-service.json" -Encoding UTF8
    az datafactory linked-service create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "AzureDatabricks" --file ".\temp-databricks-linked-service.json"
    Remove-Item ".\temp-databricks-linked-service.json"
    Write-Host "✅ Databricks linked service deployed" -ForegroundColor Green
}

# Deploy fishing events datasets
Write-Host "📋 Deploying fishing events datasets..." -ForegroundColor Yellow

# GFW Events API Dataset
$gfwApiDataset = @{
    "name" = "GFWEventsAPI"
    "properties" = @{
        "type" = "RestResource"
        "typeProperties" = @{
            "relativeUrl" = "/v3/events"
            "requestMethod" = "GET"
            "additionalHeaders" = @{
                "Authorization" = "Bearer $GFWApiToken"
                "Content-Type" = "application/json"
            }
        }
        "linkedServiceName" = @{
            "referenceName" = "GlobalFishingWatchAPI"
            "type" = "LinkedServiceReference"
        }
    }
} | ConvertTo-Json -Depth 10

$gfwApiDataset | Out-File -FilePath ".\temp-gfw-dataset.json" -Encoding UTF8
az datafactory dataset create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "GFWEventsAPI" --file ".\temp-gfw-dataset.json"
Remove-Item ".\temp-gfw-dataset.json"

# Raw Fishing Events Dataset
$rawFishingDataset = @{
    "name" = "RawFishingEventsData"
    "properties" = @{
        "type" = "Json"
        "typeProperties" = @{
            "location" = @{
                "type" = "AzureBlobFSLocation"
                "fileSystem" = "raw-data"
                "folderPath" = "fishing-events"
            }
        }
        "linkedServiceName" = @{
            "referenceName" = "AzureDataLakeStorageGen2"
            "type" = "LinkedServiceReference"
        }
    }
} | ConvertTo-Json -Depth 10

$rawFishingDataset | Out-File -FilePath ".\temp-raw-fishing-dataset.json" -Encoding UTF8
az datafactory dataset create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "RawFishingEventsData" --file ".\temp-raw-fishing-dataset.json"
Remove-Item ".\temp-raw-fishing-dataset.json"

# Processed Fishing Events Dataset
$processedFishingDataset = @{
    "name" = "ProcessedFishingEventsData"
    "properties" = @{
        "type" = "DelimitedText"
        "typeProperties" = @{
            "location" = @{
                "type" = "AzureBlobFSLocation"
                "fileSystem" = "processed-data"
                "folderPath" = "fishing-events"
                "fileName" = "processed_fishing_events.csv"
            }
            "columnDelimiter" = ","
            "rowDelimiter" = "`n"
            "encoding" = "UTF-8"
            "firstRowAsHeader" = $true
            "quoteChar" = "`""
        }
        "linkedServiceName" = @{
            "referenceName" = "AzureDataLakeStorageGen2"
            "type" = "LinkedServiceReference"
        }
    }
} | ConvertTo-Json -Depth 10

$processedFishingDataset | Out-File -FilePath ".\temp-processed-fishing-dataset.json" -Encoding UTF8
az datafactory dataset create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "ProcessedFishingEventsData" --file ".\temp-processed-fishing-dataset.json"
Remove-Item ".\temp-processed-fishing-dataset.json"

# Fishing Events Table Dataset
$fishingTableDataset = @{
    "name" = "FishingEventsTable"
    "properties" = @{
        "type" = "AzureSqlTable"
        "typeProperties" = @{
            "schema" = "dbo"
            "table" = "FishingEvents"
        }
        "linkedServiceName" = @{
            "referenceName" = "AzureSqlDatabase"
            "type" = "LinkedServiceReference"
        }
    }
} | ConvertTo-Json -Depth 10

$fishingTableDataset | Out-File -FilePath ".\temp-fishing-table-dataset.json" -Encoding UTF8
az datafactory dataset create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "FishingEventsTable" --file ".\temp-fishing-table-dataset.json"
Remove-Item ".\temp-fishing-table-dataset.json"

Write-Host "✅ Fishing events datasets deployed" -ForegroundColor Green

# Deploy fishing events pipeline (simplified version)
Write-Host "🔧 Deploying fishing events pipeline..." -ForegroundColor Yellow
$fishingPipeline = @{
    "name" = "FishingEventsDataProcessingPipeline"
    "properties" = @{
        "description" = "Pipeline to fetch and process Global Fishing Watch API v3 events data"
        "activities" = @(
            @{
                "name" = "FetchFishingEvents"
                "type" = "WebActivity"
                "typeProperties" = @{
                    "url" = "https://gateway.api.globalfishingwatch.org/v3/events"
                    "method" = "GET"
                    "headers" = @{
                        "Authorization" = "Bearer $GFWApiToken"
                        "Content-Type" = "application/json"
                    }
                    "body" = @{
                        "datasets" = @("public-global-fishing-events:v3.0")
                        "start-date" = "@formatDateTime(addDays(utcnow(), -30), 'yyyy-MM-dd')"
                        "end-date" = "@formatDateTime(utcnow(), 'yyyy-MM-dd')"
                        "event-types" = @("port_visit", "fishing")
                        "limit" = 10000
                        "format" = "json"
                    }
                }
            }
        )
        "parameters" = @{
            "storageAccount" = @{
                "type" = "string"
                "defaultValue" = $StorageAccountName
            }
            "gfwApiToken" = @{
                "type" = "string"
                "defaultValue" = $GFWApiToken
            }
        }
    }
} | ConvertTo-Json -Depth 10

$fishingPipeline | Out-File -FilePath ".\temp-fishing-pipeline.json" -Encoding UTF8
az datafactory pipeline create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "FishingEventsDataProcessingPipeline" --file ".\temp-fishing-pipeline.json"
Remove-Item ".\temp-fishing-pipeline.json"
Write-Host "✅ Fishing events pipeline deployed" -ForegroundColor Green

# Create trigger for daily execution
Write-Host "⏰ Creating daily fishing events trigger..." -ForegroundColor Yellow
$triggerJson = @{
    "name" = "DailyFishingEventsProcessing"
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
                    "referenceName" = "FishingEventsDataProcessingPipeline"
                }
                "parameters" = @{
                    "storageAccount" = $StorageAccountName
                    "gfwApiToken" = $GFWApiToken
                }
            }
        )
    }
} | ConvertTo-Json -Depth 10

$triggerJson | Out-File -FilePath ".\temp-fishing-trigger.json" -Encoding UTF8
az datafactory trigger create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "DailyFishingEventsProcessing" --file ".\temp-fishing-trigger.json"
Remove-Item ".\temp-fishing-trigger.json"
Write-Host "✅ Daily fishing events trigger created" -ForegroundColor Green

# Display summary
Write-Host "`n🎉 GLOBAL FISHING WATCH ANALYSIS DEPLOYMENT COMPLETED!" -ForegroundColor Green
Write-Host "=" * 70
Write-Host "🐟 Data Factory: $DataFactoryName" -ForegroundColor Cyan
Write-Host "💾 Storage Account: $StorageAccountName" -ForegroundColor Cyan
Write-Host "🗄️ SQL Server: $SqlServerName" -ForegroundColor Cyan
Write-Host "📋 SQL Database: $SqlDatabaseName" -ForegroundColor Cyan
Write-Host "🔗 Resource Group: $ResourceGroupName" -ForegroundColor Cyan

Write-Host "`n📋 NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Execute the SQL script: .\sql\create-fishing-events-tables.sql" -ForegroundColor White
Write-Host "2. Upload Databricks notebook: .\scripts\databricks-fishing-events-processor.py" -ForegroundColor White
Write-Host "3. Test the fishing events pipeline in ADF Studio" -ForegroundColor White
Write-Host "4. Configure Power BI for investment insights dashboard" -ForegroundColor White
Write-Host "5. Start the daily trigger when ready" -ForegroundColor White

Write-Host "`n🔗 USEFUL LINKS:" -ForegroundColor Yellow
Write-Host "• ADF Studio: https://adf.azure.com/en/factory/$DataFactoryName" -ForegroundColor White
Write-Host "• Azure Portal: https://portal.azure.com" -ForegroundColor White

Write-Host "`n📊 ANALYSIS FOCUS:" -ForegroundColor Yellow
Write-Host "• Port Visit Analysis: PortVisitCount, AvgStayHours, TotalTradeHours, PortVessels" -ForegroundColor White
Write-Host "• Investment Insights: ROI predictions and priority rankings" -ForegroundColor White
Write-Host "• Data Source: Global Fishing Watch API v3 /v3/events endpoint" -ForegroundColor White

Write-Host "`n✅ Global Fishing Watch Analysis is now integrated with your existing ADF!" -ForegroundColor Green
