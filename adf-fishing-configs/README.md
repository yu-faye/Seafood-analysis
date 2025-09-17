# 🐟 Global Fishing Watch Analysis - ADF配置文件

## 📋 专为您的Azure资源定制

此配置文件夹专门为您的Azure环境生成：

- **Resource Group**: `seafood-analysis-rg`
- **Data Factory**: `seafood-adf`
- **Storage Account**: `seafoodddatalake`
- **SQL Server**: `seafood-sql-server`
- **SQL Database**: `seafood-analysis-db`

## 🚀 快速部署

### 1. 一键部署（推荐）
```powershell
# 在adf-fishing-configs文件夹中运行
.\deploy.ps1 -GFWApiToken "your-gfw-api-token-here"

# 如果需要同时配置SQL连接
.\deploy.ps1 -GFWApiToken "your-token" -SqlPassword "your-sql-password"
```

### 2. 手动部署步骤

#### 步骤1：部署链接服务
```bash
az datafactory linked-service create --resource-group seafood-analysis-rg --factory-name seafood-adf --name "AzureDataLakeStorage" --file "./linkedServices/AzureDataLakeStorage.json"
az datafactory linked-service create --resource-group seafood-analysis-rg --factory-name seafood-adf --name "AzureSqlDatabase" --file "./linkedServices/AzureSqlDatabase.json"
az datafactory linked-service create --resource-group seafood-analysis-rg --factory-name seafood-adf --name "GlobalFishingWatchAPI" --file "./linkedServices/GlobalFishingWatchAPI.json"
```

#### 步骤2：部署数据集
```bash
az datafactory dataset create --resource-group seafood-analysis-rg --factory-name seafood-adf --name "GFWEventsAPI" --file "./datasets/GFWEventsAPI.json"
az datafactory dataset create --resource-group seafood-analysis-rg --factory-name seafood-adf --name "RawFishingEventsData" --file "./datasets/RawFishingEventsData.json"
az datafactory dataset create --resource-group seafood-analysis-rg --factory-name seafood-adf --name "ProcessedFishingEventsData" --file "./datasets/ProcessedFishingEventsData.json"
az datafactory dataset create --resource-group seafood-analysis-rg --factory-name seafood-adf --name "FishingEventsTable" --file "./datasets/FishingEventsTable.json"
```

#### 步骤3：部署管道
```bash
az datafactory pipeline create --resource-group seafood-analysis-rg --factory-name seafood-adf --name "FishingEventsProcessingPipeline" --file "./pipelines/FishingEventsProcessingPipeline.json"
```

#### 步骤4：创建数据库表
在SQL Server Management Studio或Azure Portal中连接到 `seafood-sql-server.database.windows.net`，执行：
```sql
-- 运行 sql/create-fishing-tables.sql 中的脚本
```

## 📊 配置文件说明

### 链接服务 (linkedServices/)
- **AzureDataLakeStorage.json**: 连接到您的 `seafoodddatalake` 存储账户
- **AzureSqlDatabase.json**: 连接到您的 `seafood-analysis-db` 数据库
- **GlobalFishingWatchAPI.json**: Global Fishing Watch API v3连接
- **AzureKeyVault.json**: Key Vault用于存储密钥（可选）

### 数据集 (datasets/)
- **GFWEventsAPI.json**: GFW API数据源
- **RawFishingEventsData.json**: 原始数据存储在Data Lake
- **ProcessedFishingEventsData.json**: 处理后的CSV数据
- **FishingEventsTable.json**: SQL数据库表映射

### 管道 (pipelines/)
- **FishingEventsProcessingPipeline.json**: 主要处理管道
  - 从GFW API获取数据
  - 存储原始数据到Data Lake
  - 处理数据并加载到SQL数据库
  - 生成港口访问分析

### SQL脚本 (sql/)
- **create-fishing-tables.sql**: 创建所有必要的数据库表和存储过程

## 🎯 核心分析指标

管道将自动生成以下港口投资分析指标：

1. **PortVisitCount**: 港口访问次数 → 反映贸易活跃度
2. **AvgStayHours**: 平均停留时间 → 评估港口效率  
3. **TotalTradeHours**: 总贸易小时数 → 估算贸易量
4. **PortVessels**: 独特船只数量 → 反映市场覆盖度

## 📈 投资洞察算法

系统将自动计算投资优先级：
- **HIGH (≥80分)**: 优先投资港口基础设施
- **MEDIUM (60-79分)**: 考虑专业设施投资  
- **LOW (<60分)**: 监控未来机会

## 🔄 自动化调度

部署完成后，系统将：
- ✅ 每日06:00 UTC自动运行
- ✅ 获取过去30天的最新数据
- ✅ 更新港口访问分析
- ✅ 生成投资洞察报告

## 🛠️ 故障排除

### 常见问题
1. **API Token无效**: 检查GFW API token是否有效
2. **存储权限**: 确保ADF有访问存储账户的权限
3. **SQL连接**: 验证防火墙规则允许Azure服务访问

### 验证部署
```bash
# 检查链接服务
az datafactory linked-service show --resource-group seafood-analysis-rg --factory-name seafood-adf --name "AzureDataLakeStorage"

# 检查数据集
az datafactory dataset show --resource-group seafood-analysis-rg --factory-name seafood-adf --name "GFWEventsAPI"

# 检查管道
az datafactory pipeline show --resource-group seafood-analysis-rg --factory-name seafood-adf --name "FishingEventsProcessingPipeline"
```

## 📞 支持

如果遇到问题：
1. 检查Azure CLI登录状态
2. 验证资源名称是否正确
3. 确认API token有效性
4. 查看ADF监控日志

---

**🎉 准备就绪！** 您的Global Fishing Watch投资分析系统现在可以部署到现有的ADF中！
