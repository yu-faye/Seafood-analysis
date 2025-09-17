# 诊断Azure Data Factory管道问题
# 检查各个组件的状态

param(
    [string]$ResourceGroupName = "seafood-analysis-rg",
    [string]$DataFactoryName = "seafood-adf",
    [string]$KeyVaultName = "seafood-analysis-kv",
    [string]$SqlServerName = "seafood-sql-server",
    [string]$SqlDatabaseName = "seafood-analysis-db",
    [string]$StorageAccountName = "seafoodddatalake"
)

Write-Host "🔍 诊断Azure Data Factory管道问题..." -ForegroundColor Yellow
Write-Host "=" * 60

# 1. 检查Key Vault状态
Write-Host "1️⃣ 检查Key Vault状态..." -ForegroundColor Cyan
try {
    $kv = az keyvault show --name $KeyVaultName --resource-group $ResourceGroupName --query "properties.enabledForTemplateDeployment" -o tsv 2>$null
    if ($kv -eq "true") {
        Write-Host "✅ Key Vault 可访问" -ForegroundColor Green
    } else {
        Write-Host "❌ Key Vault 不可访问" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ 无法访问Key Vault" -ForegroundColor Red
}

# 2. 检查Key Vault中的密钥
Write-Host "2️⃣ 检查Key Vault中的密钥..." -ForegroundColor Cyan
$secrets = @("gfwapitoken", "SqlPassword", "StorageAccountKey")
foreach ($secret in $secrets) {
    try {
        $secretExists = az keyvault secret show --vault-name $KeyVaultName --name $secret --query "name" -o tsv 2>$null
        if ($secretExists) {
            Write-Host "✅ 密钥 $secret 存在" -ForegroundColor Green
        } else {
            Write-Host "❌ 密钥 $secret 不存在" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ 无法检查密钥 $secret" -ForegroundColor Red
    }
}

# 3. 检查SQL数据库状态
Write-Host "3️⃣ 检查SQL数据库状态..." -ForegroundColor Cyan
try {
    $sqlStatus = az sql db show --resource-group $ResourceGroupName --server $SqlServerName --name $SqlDatabaseName --query "status" -o tsv 2>$null
    if ($sqlStatus -eq "Online") {
        Write-Host "✅ SQL数据库在线" -ForegroundColor Green
    } else {
        Write-Host "❌ SQL数据库状态: $sqlStatus" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ 无法访问SQL数据库" -ForegroundColor Red
}

# 4. 检查存储账户状态
Write-Host "4️⃣ 检查存储账户状态..." -ForegroundColor Cyan
try {
    $storageStatus = az storage account show --resource-group $ResourceGroupName --name $StorageAccountName --query "provisioningState" -o tsv 2>$null
    if ($storageStatus -eq "Succeeded") {
        Write-Host "✅ 存储账户正常" -ForegroundColor Green
    } else {
        Write-Host "❌ 存储账户状态: $storageStatus" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ 无法访问存储账户" -ForegroundColor Red
}

# 5. 检查Data Factory状态
Write-Host "5️⃣ 检查Data Factory状态..." -ForegroundColor Cyan
try {
    $adfStatus = az datafactory show --resource-group $ResourceGroupName --name $DataFactoryName --query "provisioningState" -o tsv 2>$null
    if ($adfStatus -eq "Succeeded") {
        Write-Host "✅ Data Factory正常" -ForegroundColor Green
    } else {
        Write-Host "❌ Data Factory状态: $adfStatus" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ 无法访问Data Factory" -ForegroundColor Red
}

# 6. 检查存储容器
Write-Host "6️⃣ 检查存储容器..." -ForegroundColor Cyan
$containers = @("raw-data", "processed-data", "insights")
$storageKey = az storage account keys list --resource-group $ResourceGroupName --account-name $StorageAccountName --query "[0].value" -o tsv 2>$null

if ($storageKey) {
    foreach ($container in $containers) {
        try {
            $containerExists = az storage container show --account-name $StorageAccountName --account-key $storageKey --name $container --query "name" -o tsv 2>$null
            if ($containerExists) {
                Write-Host "✅ 容器 $container 存在" -ForegroundColor Green
            } else {
                Write-Host "❌ 容器 $container 不存在" -ForegroundColor Red
            }
        } catch {
            Write-Host "❌ 无法检查容器 $container" -ForegroundColor Red
        }
    }
} else {
    Write-Host "❌ 无法获取存储账户密钥" -ForegroundColor Red
}

# 7. 检查SQL数据库表
Write-Host "7️⃣ 检查SQL数据库表..." -ForegroundColor Cyan
try {
    $sqlPassword = az keyvault secret show --vault-name $KeyVaultName --name "SqlPassword" --query "value" -o tsv 2>$null
    if ($sqlPassword) {
        Write-Host "✅ 可以获取SQL密码" -ForegroundColor Green
        # 这里可以添加SQL连接测试
    } else {
        Write-Host "❌ 无法获取SQL密码" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ 无法检查SQL密码" -ForegroundColor Red
}

Write-Host "=" * 60
Write-Host "🎯 诊断完成！请检查上述结果。" -ForegroundColor Yellow
Write-Host "💡 如果发现问题，请根据错误信息进行修复。" -ForegroundColor Cyan

