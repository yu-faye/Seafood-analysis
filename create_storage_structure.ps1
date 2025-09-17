# 创建Azure存储容器和目录结构
# 确保必要的文件夹存在

param(
    [string]$ResourceGroupName = "seafood-analysis-rg",
    [string]$StorageAccountName = "seafoodddatalake"
)

Write-Host "🔧 创建Azure存储容器和目录结构..." -ForegroundColor Yellow

# 获取存储账户密钥
Write-Host "🔑 获取存储账户密钥..." -ForegroundColor Yellow
$storageKey = az storage account keys list --resource-group $ResourceGroupName --account-name $StorageAccountName --query "[0].value" -o tsv

if ([string]::IsNullOrEmpty($storageKey)) {
    Write-Error "❌ 无法获取存储账户密钥"
    exit 1
}

# 创建容器
$containers = @("raw-data", "processed-data", "insights")

foreach ($container in $containers) {
    Write-Host "📁 创建容器: $container" -ForegroundColor Green
    az storage container create --name $container --account-name $StorageAccountName --account-key $storageKey --output none 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ 容器 $container 创建成功" -ForegroundColor Green
    } else {
        Write-Host "⚠️ 容器 $container 可能已存在" -ForegroundColor Yellow
    }
}

# 创建目录结构
Write-Host "📂 创建目录结构..." -ForegroundColor Yellow

# 在processed-data容器中创建fishing-events目录
Write-Host "📁 创建 fishing-events 目录..." -ForegroundColor Green
az storage blob directory create --container-name "processed-data" --directory-path "fishing-events" --account-name $StorageAccountName --account-key $storageKey --output none 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ fishing-events 目录创建成功" -ForegroundColor Green
} else {
    Write-Host "⚠️ fishing-events 目录可能已存在" -ForegroundColor Yellow
}

# 在raw-data容器中创建fishing-events目录
Write-Host "📁 创建 raw-data/fishing-events 目录..." -ForegroundColor Green
az storage blob directory create --container-name "raw-data" --directory-path "fishing-events" --account-name $StorageAccountName --account-key $storageKey --output none 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ raw-data/fishing-events 目录创建成功" -ForegroundColor Green
} else {
    Write-Host "⚠️ raw-data/fishing-events 目录可能已存在" -ForegroundColor Yellow
}

# 在insights容器中创建fishing-events目录
Write-Host "📁 创建 insights/fishing-events 目录..." -ForegroundColor Green
az storage blob directory create --container-name "insights" --directory-path "fishing-events" --account-name $StorageAccountName --account-key $storageKey --output none 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ insights/fishing-events 目录创建成功" -ForegroundColor Green
} else {
    Write-Host "⚠️ insights/fishing-events 目录可能已存在" -ForegroundColor Yellow
}

Write-Host "🎉 存储结构创建完成！" -ForegroundColor Green
Write-Host "📋 创建的容器和目录:" -ForegroundColor Cyan
Write-Host "  - raw-data/fishing-events/" -ForegroundColor White
Write-Host "  - processed-data/fishing-events/" -ForegroundColor White
Write-Host "  - insights/fishing-events/" -ForegroundColor White
