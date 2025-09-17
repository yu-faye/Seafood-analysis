# Azure Data Factory 部署指南

## 安全配置

### 1. 在Azure Key Vault中存储密钥

在部署之前，您需要在Azure Key Vault中存储以下密钥：

#### 创建Key Vault密钥：
```bash
# 存储GFW API Token
az keyvault secret set --vault-name "seafood-analysis-kv" --name "GfwApiToken" --value "YOUR_ACTUAL_GFW_API_TOKEN"

# 存储SQL密码
az keyvault secret set --vault-name "seafood-analysis-kv" --name "SqlPassword" --value "YOUR_ACTUAL_SQL_PASSWORD"

# 存储存储账户密钥
az keyvault secret set --vault-name "seafood-analysis-kv" --name "StorageAccountKey" --value "YOUR_ACTUAL_STORAGE_ACCOUNT_KEY"
```

#### 或者通过Azure门户：
1. 进入Azure Key Vault
2. 点击 "密钥" 或 "机密"
3. 添加以下机密：
   - `GfwApiToken`: 您的GFW API token
   - `SqlPassword`: 您的SQL数据库密码
   - `StorageAccountKey`: 您的存储账户密钥

### 2. 配置Data Factory访问权限

确保Data Factory的托管身份有权限访问Key Vault：

```bash
# 获取Data Factory的托管身份ID
az datafactory show --name "your-data-factory-name" --resource-group "your-resource-group" --query "identity.principalId" -o tsv

# 授予Key Vault访问权限
az keyvault set-policy --name "seafood-analysis-kv" --object-id "DATA_FACTORY_PRINCIPAL_ID" --secret-permissions get list
```

### 3. 部署配置

1. 将代码推送到GitHub（现在不包含敏感信息）
2. 在Azure Data Factory中导入配置
3. 在运行时提供参数值

### 4. 运行时参数

在运行管道时，您需要提供以下参数：
- `gfwApiToken`: 从Key Vault获取的GFW API token

## 文件说明

- `config-template.json`: 配置文件模板
- `config.json`: 本地配置文件（已添加到.gitignore）
- `.gitignore`: 防止敏感文件被提交到Git

## 安全最佳实践

1. ✅ 敏感信息存储在Azure Key Vault中
2. ✅ 代码仓库不包含真实密钥
3. ✅ 使用托管身份进行身份验证
4. ✅ 配置文件模板化
