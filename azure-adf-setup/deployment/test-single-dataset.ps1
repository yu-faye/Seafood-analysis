# 简单测试：添加单个Dataset到现有ADF
# 用于验证集成是否成功

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$DataFactoryName
)

Write-Host "🧪 测试：添加单个Dataset到现有ADF" -ForegroundColor Green
Write-Host "=" * 50

# 检查是否登录Azure
Write-Host "🔍 检查Azure CLI登录状态..." -ForegroundColor Yellow
try {
    $azAccount = az account show 2>$null | ConvertFrom-Json
    if (-not $azAccount) {
        Write-Error "请先登录Azure: az login"
        exit 1
    }
    Write-Host "✅ 已登录: $($azAccount.user.name)" -ForegroundColor Green
} catch {
    Write-Error "请安装Azure CLI并登录: az login"
    exit 1
}

# 验证Data Factory是否存在
Write-Host "🔍 验证Data Factory是否存在..." -ForegroundColor Yellow
try {
    $adf = az datafactory show --resource-group $ResourceGroupName --name $DataFactoryName --output json | ConvertFrom-Json
    Write-Host "✅ 找到Data Factory: $($adf.name)" -ForegroundColor Green
} catch {
    Write-Error "❌ 未找到Data Factory '$DataFactoryName' 在资源组 '$ResourceGroupName'"
    exit 1
}

# 创建一个简单的测试Dataset
Write-Host "📋 创建测试Dataset..." -ForegroundColor Yellow

$testDataset = @{
    "name" = "TestFishingDataset"
    "properties" = @{
        "type" = "Json"
        "description" = "测试用的渔业数据集"
        "typeProperties" = @{
            "location" = @{
                "type" = "HttpServerLocation"
                "relativeUrl" = "test.json"
            }
        }
        "linkedServiceName" = @{
            "referenceName" = "HttpServer1"  # 使用一个通用的HTTP连接
            "type" = "LinkedServiceReference"
        }
    }
} | ConvertTo-Json -Depth 10

# 保存到临时文件
$testDataset | Out-File -FilePath ".\temp-test-dataset.json" -Encoding UTF8

# 部署Dataset
try {
    Write-Host "🚀 正在部署测试Dataset..." -ForegroundColor Yellow
    az datafactory dataset create --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "TestFishingDataset" --file ".\temp-test-dataset.json"
    Write-Host "✅ 测试Dataset部署成功！" -ForegroundColor Green
} catch {
    Write-Host "❌ Dataset部署失败" -ForegroundColor Red
    Write-Host "错误信息: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    # 清理临时文件
    Remove-Item ".\temp-test-dataset.json" -ErrorAction SilentlyContinue
}

# 验证Dataset是否创建成功
Write-Host "🔍 验证Dataset是否创建成功..." -ForegroundColor Yellow
try {
    $dataset = az datafactory dataset show --resource-group $ResourceGroupName --factory-name $DataFactoryName --name "TestFishingDataset" --output json | ConvertFrom-Json
    Write-Host "✅ 验证成功！Dataset已创建: $($dataset.name)" -ForegroundColor Green
    Write-Host "📋 Dataset类型: $($dataset.properties.type)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Dataset验证失败" -ForegroundColor Red
}

Write-Host "`n🎉 测试完成！" -ForegroundColor Green
Write-Host "📋 结果总结:" -ForegroundColor Yellow
Write-Host "  - Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "  - Data Factory: $DataFactoryName" -ForegroundColor White
Write-Host "  - Test Dataset: TestFishingDataset" -ForegroundColor White

Write-Host "`n💡 如果测试成功，说明您的ADF可以接受新的Dataset！" -ForegroundColor Green
Write-Host "💡 您可以继续添加更多的渔业分析组件。" -ForegroundColor Green

Write-Host "`n🗑️  清理测试Dataset（可选）:" -ForegroundColor Yellow
Write-Host "az datafactory dataset delete --resource-group $ResourceGroupName --factory-name $DataFactoryName --name TestFishingDataset" -ForegroundColor White
