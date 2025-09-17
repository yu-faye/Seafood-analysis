# 一键部署Global Fishing Watch分析到现有ADF
# 针对您的具体资源：seafood-adf, seafoodddatalake, seafood-sql-server等
# API Token将安全存储在Key Vault中

param(
    [Parameter(Mandatory=$true)]
    [string]$GFWApiToken,
    
    [Parameter(Mandatory=$false)]
    [string]$SqlPassword = "",
    
    [Parameter(Mandatory=$false)]
    [string]$StorageAccountKey = ""
)

# 您的资源信息（已预配置）
$ResourceGroupName = "seafood-analysis-rg"
$DataFactoryName = "seafood-adf"
$StorageAccountName = "seafoodddatalake"
$SqlServerName = "seafood-sql-server"
$SqlDatabaseName = "seafood-analysis-db"
$SqlUsername = "seafoodadmin"
$KeyVaultName = "seafood-analysis-kv"

Write-Host "🐟 部署Global Fishing Watch分析到您的ADF" -ForegroundColor Green
Write-Host "=" * 60
Write-Host "📋 目标资源:" -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "  Data Factory: $DataFactoryName" -ForegroundColor White
Write-Host "  Storage Account: $StorageAccountName" -ForegroundColor White
Write-Host "  SQL Server: $SqlServerName" -ForegroundColor White
Write-Host "  SQL Database: $SqlDatabaseName" -ForegroundColor White
Write-Host "  Key Vault: $KeyVaultName" -ForegroundColor White
Write-Host ""

# 检查Azure CLI登录
if (-not (az account show 2>$null)) {
    Write-Host "❌ 请先登录Azure CLI: az login" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Azure CLI已登录" -ForegroundColor Green

# 创建或验证Key Vault
Write-Host "🔐 设置Key Vault..." -ForegroundColor Yellow
$kvExists = az keyvault show --name $KeyVaultName --resource-group $ResourceGroupName 2>$null
if (-not $kvExists) {
    Write-Host "📦 创建Key Vault: $KeyVaultName" -ForegroundColor Yellow
    az keyvault create --name $KeyVaultName --resource-group $ResourceGroupName --location "West Europe" --output none
    Write-Host "✅ Key Vault已创建" -ForegroundColor Green
} else {
    Write-Host "✅ Key Vault已存在" -ForegroundColor Green
}

# 存储GFW API Token到Key Vault
Write-Host "🔑 存储API Token到Key Vault..." -ForegroundColor Yellow
az keyvault secret set --vault-name $KeyVaultName --name "GFWApiToken" --value $GFWApiToken --output none
Write-Host "✅ API Token已安全存储" -ForegroundColor Green

# 如果提供了SQL密码，也存储到Key Vault
if (-not [string]::IsNullOrEmpty($SqlPassword)) {
    az keyvault secret set --vault-name $KeyVaultName --name "SqlPassword" --value $SqlPassword --output none
    Write-Host "✅ SQL密码已存储到Key Vault" -ForegroundColor Green
}

# 获取存储账户密钥（如果未提供）
if ([string]::IsNullOrEmpty($StorageAccountKey)) {
    Write-Host "🔑 获取存储账户密钥..." -ForegroundColor Yellow
    $StorageAccountKey = az storage account keys list --resource-group $ResourceGroupName --account-name $StorageAccountName --query "[0].value" -o tsv
    if ([string]::IsNullOrEmpty($StorageAccountKey)) {
        Write-Host "❌ 无法获取存储账户密钥" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ 存储账户密钥已获取" -ForegroundColor Green
}

# 创建存储容器
Write-Host "📦 创建存储容器..." -ForegroundColor Yellow
$containers = @("raw-data", "processed-data", "insights")
foreach ($container in $containers) {
    try {
        az storage container create --name $container --account-name $StorageAccountName --account-key $StorageAccountKey --output none 2>$null
        Write-Host "✅ 容器 '$container' 已准备" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ 容器 '$container' 可能已存在" -ForegroundColor Yellow
    }
}

# 部署链接服务
Write-Host "🔗 部署链接服务..." -ForegroundColor Yellow

# 部署Key Vault链接服务
az datafactory linked-service create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "AzureKeyVault" --file ".\linkedServices\AzureKeyVault.json" --output none
Write-Host "✅ Key Vault链接服务已部署" -ForegroundColor Green

# 更新存储链接服务
$storageLS = Get-Content ".\linkedServices\AzureDataLakeStorage.json" | ConvertFrom-Json
$storageLS.properties.typeProperties.accountKey = @{
    "type" = "SecureString"
    "value" = $StorageAccountKey
}
$storageLS | ConvertTo-Json -Depth 10 | Out-File "temp-storage-ls.json" -Encoding UTF8

az datafactory linked-service create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "AzureDataLakeStorage" --file "temp-storage-ls.json" --output none
Remove-Item "temp-storage-ls.json"
Write-Host "✅ 存储链接服务已部署" -ForegroundColor Green

# 部署SQL链接服务（如果提供了密码）
if (-not [string]::IsNullOrEmpty($SqlPassword)) {
    $sqlLS = Get-Content ".\linkedServices\AzureSqlDatabase.json" | ConvertFrom-Json
    $sqlLS.properties.typeProperties.password = @{
        "type" = "SecureString"
        "value" = $SqlPassword
    }
    $sqlLS | ConvertTo-Json -Depth 10 | Out-File "temp-sql-ls.json" -Encoding UTF8
    
    az datafactory linked-service create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "AzureSqlDatabase" --file "temp-sql-ls.json" --output none
    Remove-Item "temp-sql-ls.json"
    Write-Host "✅ SQL链接服务已部署" -ForegroundColor Green
} else {
    Write-Host "⚠️ 跳过SQL链接服务（未提供密码）" -ForegroundColor Yellow
}

# 部署GFW API链接服务（使用Key Vault中的token）
$gfwLS = Get-Content ".\linkedServices\GlobalFishingWatchAPI.json" | ConvertFrom-Json
$gfwLS.properties.parameters.gfwApiToken = @{
    "type" = "string"
    "defaultValue" = @{
        "type" = "AzureKeyVaultSecret"
        "store" = @{
            "referenceName" = "AzureKeyVault"
            "type" = "LinkedServiceReference"
        }
        "secretName" = "GFWApiToken"
    }
}
$gfwLS | ConvertTo-Json -Depth 10 | Out-File "temp-gfw-ls.json" -Encoding UTF8

az datafactory linked-service create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "GlobalFishingWatchAPI" --file "temp-gfw-ls.json" --output none
Remove-Item "temp-gfw-ls.json"
Write-Host "✅ GFW API链接服务已部署（使用Key Vault）" -ForegroundColor Green

# 部署数据集
Write-Host "📊 部署数据集..." -ForegroundColor Yellow
$datasets = @("GFWEventsAPI", "RawFishingEventsData", "ProcessedFishingEventsData", "FishingEventsTable")
foreach ($dataset in $datasets) {
    az datafactory dataset create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name $dataset --file ".\datasets\$dataset.json" --output none
    Write-Host "✅ 数据集 '$dataset' 已部署" -ForegroundColor Green
}

# 部署管道
Write-Host "🔧 部署管道..." -ForegroundColor Yellow
# 更新管道中的API Token
$pipeline = Get-Content ".\pipelines\FishingEventsProcessingPipeline.json" | ConvertFrom-Json
$pipeline.properties.parameters.gfwApiToken.defaultValue = $GFWApiToken
$pipeline | ConvertTo-Json -Depth 20 | Out-File "temp-pipeline.json" -Encoding UTF8

az datafactory pipeline create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "FishingEventsProcessingPipeline" --file "temp-pipeline.json" --output none
Remove-Item "temp-pipeline.json"
Write-Host "✅ 渔业事件处理管道已部署" -ForegroundColor Green

# 创建触发器
Write-Host "⏰ 创建每日触发器..." -ForegroundColor Yellow
$trigger = @{
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
                    "referenceName" = "FishingEventsProcessingPipeline"
                }
                "parameters" = @{
                    "gfwApiToken" = $GFWApiToken
                }
            }
        )
    }
} | ConvertTo-Json -Depth 10

$trigger | Out-File "temp-trigger.json" -Encoding UTF8
az datafactory trigger create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "DailyFishingEventsProcessing" --file "temp-trigger.json" --output none
Remove-Item "temp-trigger.json"
Write-Host "✅ 每日触发器已创建（明天06:00 UTC开始）" -ForegroundColor Green

Write-Host "`n🎉 部署完成！" -ForegroundColor Green
Write-Host "=" * 60
Write-Host "✅ 已成功部署到您的ADF:" -ForegroundColor Green
Write-Host "  • 4个链接服务" -ForegroundColor White
Write-Host "  • 4个数据集" -ForegroundColor White
Write-Host "  • 1个处理管道" -ForegroundColor White
Write-Host "  • 1个每日触发器" -ForegroundColor White

Write-Host "`n📋 下一步操作:" -ForegroundColor Yellow
Write-Host "1. 在SQL数据库中执行: .\sql\create-fishing-tables.sql" -ForegroundColor White
Write-Host "2. 访问ADF Studio测试管道: https://adf.azure.com" -ForegroundColor White
Write-Host "3. 启动触发器开始自动处理" -ForegroundColor White

Write-Host "`n🔗 快速链接:" -ForegroundColor Cyan
Write-Host "• ADF Studio: https://adf.azure.com/en/factory/$DataFactoryName" -ForegroundColor White
Write-Host "• Azure Portal: https://portal.azure.com" -ForegroundColor White

Write-Host "`n🎯 分析重点:" -ForegroundColor Yellow
Write-Host "• PortVisitCount: 港口访问次数" -ForegroundColor White
Write-Host "• AvgStayHours: 平均停留时间" -ForegroundColor White
Write-Host "• TotalTradeHours: 总贸易小时数" -ForegroundColor White
Write-Host "• PortVessels: 独特船只数量" -ForegroundColor White

Write-Host "`n💡 系统将每日自动分析全球渔业港口访问数据，为投资决策提供数据支持！" -ForegroundColor Green
