# 超简单测试：添加一个基础Dataset到现有ADF

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$DataFactoryName,
    
    [Parameter(Mandatory=$false)]
    [string]$StorageAccountName = ""
)

Write-Host "🧪 超简单测试：添加Dataset到现有ADF" -ForegroundColor Green
Write-Host "=" * 40

# 检查登录
if (-not (az account show 2>$null)) {
    Write-Host "❌ 请先登录: az login" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Azure CLI已登录" -ForegroundColor Green

# 如果没有提供存储账户名，尝试获取现有的
if ([string]::IsNullOrEmpty($StorageAccountName)) {
    Write-Host "🔍 查找现有的存储账户..." -ForegroundColor Yellow
    try {
        $storageAccounts = az storage account list --resource-group $ResourceGroupName --output json | ConvertFrom-Json
        if ($storageAccounts.Count -gt 0) {
            $StorageAccountName = $storageAccounts[0].name
            Write-Host "✅ 找到存储账户: $StorageAccountName" -ForegroundColor Green
        }
    } catch {
        Write-Host "⚠️ 未找到存储账户，将创建一个简单的HTTP Dataset" -ForegroundColor Yellow
    }
}

# 创建最简单的Dataset
Write-Host "📋 创建简单测试Dataset..." -ForegroundColor Yellow

if ([string]::IsNullOrEmpty($StorageAccountName)) {
    # 创建HTTP类型的Dataset（不需要存储账户）
    $simpleDataset = @"
{
  "properties": {
    "type": "Json",
    "description": "简单测试Dataset - 渔业数据",
    "typeProperties": {
      "location": {
        "type": "HttpServerLocation",
        "relativeUrl": "test-fishing-data.json"
      }
    }
  }
}
"@
} else {
    # 创建Blob类型的Dataset
    $simpleDataset = @"
{
  "properties": {
    "type": "Json",
    "description": "简单测试Dataset - 渔业数据存储",
    "typeProperties": {
      "location": {
        "type": "AzureBlobStorageLocation",
        "container": "test-container",
        "fileName": "test-fishing-data.json"
      }
    }
  }
}
"@
}

# 保存到文件
$simpleDataset | Out-File -FilePath "test-dataset.json" -Encoding UTF8

# 部署Dataset
Write-Host "🚀 部署测试Dataset..." -ForegroundColor Yellow
try {
    az datafactory dataset create `
        --resource-group $ResourceGroupName `
        --factory-name $DataFactoryName `
        --name "SimpleFishingTestDataset" `
        --file "test-dataset.json"
    
    Write-Host "✅ 成功！Dataset已添加到ADF" -ForegroundColor Green
    
    # 验证
    Write-Host "🔍 验证Dataset..." -ForegroundColor Yellow
    $result = az datafactory dataset show `
        --resource-group $ResourceGroupName `
        --factory-name $DataFactoryName `
        --name "SimpleFishingTestDataset" `
        --output json | ConvertFrom-Json
    
    Write-Host "✅ 验证成功！" -ForegroundColor Green
    Write-Host "📋 Dataset名称: $($result.name)" -ForegroundColor Cyan
    Write-Host "📋 Dataset类型: $($result.properties.type)" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ 部署失败: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    # 清理临时文件
    Remove-Item "test-dataset.json" -ErrorAction SilentlyContinue
}

Write-Host "`n🎉 测试完成！" -ForegroundColor Green
Write-Host "`n📋 如果看到'验证成功'，说明您的ADF可以添加新组件！" -ForegroundColor Yellow

Write-Host "`n🗑️ 删除测试Dataset（可选）:" -ForegroundColor Yellow
Write-Host "az datafactory dataset delete --resource-group $ResourceGroupName --factory-name $DataFactoryName --name SimpleFishingTestDataset" -ForegroundColor Gray
