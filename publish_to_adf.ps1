# =============================================
# 发布Azure Data Factory资源到云端
# =============================================

Write-Host "🚀 开始发布Azure Data Factory资源..." -ForegroundColor Green

# 设置变量
$ResourceGroupName = "seafood-analysis-rg"
$DataFactoryName = "seafood-adf"
$Location = "East US"

Write-Host "📋 发布配置:" -ForegroundColor Yellow
Write-Host "   资源组: $ResourceGroupName"
Write-Host "   数据工厂: $DataFactoryName"
Write-Host "   位置: $Location"
Write-Host ""

# 检查Azure CLI是否已安装
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Host "✅ Azure CLI 版本: $($azVersion.'azure-cli')" -ForegroundColor Green
} catch {
    Write-Host "❌ 未找到Azure CLI，请先安装: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" -ForegroundColor Red
    exit 1
}

# 登录Azure
Write-Host "🔐 登录Azure..." -ForegroundColor Yellow
az login

# 设置订阅
Write-Host "📝 设置Azure订阅..." -ForegroundColor Yellow
$subscriptions = az account list --output table
Write-Host $subscriptions
$subscriptionId = Read-Host "请输入订阅ID"

az account set --subscription $subscriptionId

# 创建资源组（如果不存在）
Write-Host "📦 创建资源组..." -ForegroundColor Yellow
az group create --name $ResourceGroupName --location $Location

# 创建数据工厂（如果不存在）
Write-Host "🏭 创建数据工厂..." -ForegroundColor Yellow
az datafactory create --resource-group $ResourceGroupName --name $DataFactoryName --location $Location

# 发布链接服务
Write-Host "🔗 发布链接服务..." -ForegroundColor Yellow
az datafactory linked-service create --resource-group $ResourceGroupName --factory-name $DataFactoryName --linked-service-name "AzureKeyVault" --properties @linkedService/AzureKeyVault.json
az datafactory linked-service create --resource-group $ResourceGroupName --factory-name $DataFactoryName --linked-service-name "GlobalFishingWatchAPI" --properties @linkedService/GlobalFishingWatchAPI.json
az datafactory linked-service create --resource-group $ResourceGroupName --factory-name $DataFactoryName --linked-service-name "AzureSqlDatabase" --properties @linkedService/AzureSqlDatabase.json

# 发布数据集
Write-Host "📊 发布数据集..." -ForegroundColor Yellow
az datafactory dataset create --resource-group $ResourceGroupName --factory-name $DataFactoryName --dataset-name "GFWEventsAPI" --properties @dataset/GFWEventsAPI.json
az datafactory dataset create --resource-group $ResourceGroupName --factory-name $DataFactoryName --dataset-name "FishingEventsTable" --properties @dataset/FishingEventsTable.json

# 发布管道
Write-Host "🔧 发布管道..." -ForegroundColor Yellow
az datafactory pipeline create --resource-group $ResourceGroupName --factory-name $DataFactoryName --pipeline-name "FishingEventsProcessingPipeline" --properties @pipeline/FishingEventsProcessingPipeline.json

Write-Host "✅ 发布完成!" -ForegroundColor Green
Write-Host ""
Write-Host "🌐 访问Azure门户查看: https://portal.azure.com" -ForegroundColor Cyan
Write-Host "🔍 搜索数据工厂: $DataFactoryName" -ForegroundColor Cyan
