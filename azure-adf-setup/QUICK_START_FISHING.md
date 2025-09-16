# 🚀 Global Fishing Watch Analysis - 快速开始

## ⚡ 5分钟快速部署

### 前提条件检查

- [ ] Azure订阅（具有贡献者权限）
- [ ] PowerShell 5.1+
- [ ] Global Fishing Watch API Token
- [ ] Azure CLI 或 Azure PowerShell

### 1. 获取API Token

1. 访问 [Global Fishing Watch](https://globalfishingwatch.org/)
2. 注册账户并申请API访问权限
3. 获取Bearer Token（格式：`eyJhbGciOiJSUzI1NiIs...`）

### 2. 一键部署

```powershell
# 克隆或下载项目
git clone <your-repo>
cd azure-seafood/azure-adf-setup

# 设置变量（请修改为您的值）
$ResourceGroupName = "fishing-analysis-rg"
$GFWApiToken = "your-gfw-api-token-here"
$SqlPassword = "YourSecurePassword123!"

# 执行一键部署
.\deployment\deploy-fishing-analysis.ps1 `
    -ResourceGroupName $ResourceGroupName `
    -Location "West Europe" `
    -DataFactoryName "fishing-adf-$(Get-Random)" `
    -StorageAccountName "fishingdata$(Get-Random)" `
    -SqlServerName "fishing-sql-$(Get-Random)" `
    -SqlDatabaseName "fishing-analysis-db" `
    -SqlUsername "fishingadmin" `
    -SqlPassword $SqlPassword `
    -GFWApiToken $GFWApiToken
```

### 3. 上传处理脚本

1. 打开Azure Databricks工作区
2. 创建笔记本：`/fishing-analysis/process-fishing-events`
3. 复制`scripts/databricks-fishing-events-processor.py`内容
4. 保存并运行测试

### 4. 验证部署

```powershell
# 测试管道
az datafactory pipeline create-run `
    --factory-name "your-data-factory-name" `
    --resource-group $ResourceGroupName `
    --name "FishingEventsDataProcessingPipeline"
```

## 📊 预期结果

部署成功后，您将获得：

- ✅ **每日自动数据获取**：从GFW API获取最新渔业数据
- ✅ **港口访问分析**：自动计算港口贸易指标
- ✅ **投资洞察报告**：基于数据的投资优先级排序
- ✅ **Power BI仪表板**：可视化投资机会

## 🎯 核心投资指标

### 港口分析指标

| 指标 | 描述 | 投资价值 |
|------|------|----------|
| **PortVisitCount** | 港口访问次数 | 反映贸易活跃度 |
| **AvgStayHours** | 平均停留时间 | 评估港口效率 |
| **TotalTradeHours** | 总贸易小时数 | 估算贸易量规模 |
| **PortVessels** | 独特船只数量 | 反映市场覆盖度 |

### 投资优先级

- 🔴 **HIGH**：TotalTradeHours > 80分，优先投资港口基础设施
- 🟡 **MEDIUM**：60-79分，考虑专业设施投资
- 🟢 **LOW**：< 60分，监控未来机会

## 📈 使用场景

### 1. 港口投资决策
```sql
-- 查询高价值投资港口
SELECT TOP 10 
    PortName, PortCountry, 
    TotalTradeHours, InvestmentPriority, 
    ExpectedROI
FROM InvestmentInsights 
WHERE InvestmentPriority = 'HIGH'
ORDER BY OverallScore DESC
```

### 2. 区域贸易分析
```sql
-- 分析各国港口贸易潜力
SELECT 
    Country, 
    COUNT(*) as TotalPorts,
    SUM(TotalTradeHours) as RegionTradeVolume,
    AVG(AvgPortEfficiency) as RegionEfficiency
FROM CountryTradeSummary 
GROUP BY Country
ORDER BY RegionTradeVolume DESC
```

### 3. 船只活动监控
```sql
-- 识别最活跃的渔业船只
SELECT TOP 20
    VesselName, VesselFlag,
    TotalPortVisits, UniquePortsVisited,
    MostFrequentPort
FROM VesselActivitySummary
ORDER BY TotalPortVisits DESC
```

## 🔄 日常操作

### 监控管道状态
1. 打开Azure Data Factory Studio
2. 检查"监控"选项卡
3. 查看管道运行历史

### 查看数据质量
1. 打开SQL数据库
2. 查询处理报告：`SELECT * FROM ProcessingReport`
3. 检查数据完整性

### 更新分析参数
```sql
-- 调整分析时间窗口
EXEC sp_GeneratePortAnalysisInsights 
    @ProcessingDate = '2025-01-15',
    @AnalysisPeriodDays = 60  -- 分析过去60天
```

## 🚨 故障排除

### 常见问题快速修复

#### 1. API调用失败
```powershell
# 检查API Token有效性
$headers = @{"Authorization" = "Bearer $GFWApiToken"}
Invoke-RestMethod -Uri "https://gateway.api.globalfishingwatch.org/v3/vessels" -Headers $headers
```

#### 2. 数据库连接问题
```powershell
# 测试SQL连接
$connectionString = "Server=tcp:your-server.database.windows.net,1433;Database=fishing-analysis-db;User ID=fishingadmin;Password=YourPassword;Encrypt=true;"
Test-NetConnection -ComputerName "your-server.database.windows.net" -Port 1433
```

#### 3. Databricks处理失败
- 检查集群状态
- 验证存储账户权限
- 查看笔记本执行日志

## 📞 获取帮助

### 即时支持
- **Azure支持**：Azure门户中的支持请求
- **文档**：查看`FISHING_ANALYSIS_GUIDE.md`
- **社区**：Azure Data Factory论坛

### 高级配置
- **自定义分析**：修改SQL存储过程
- **扩展数据源**：添加更多GFW API端点
- **集成其他系统**：使用REST API导出数据

---

**🎉 恭喜！** 您的Global Fishing Watch投资分析系统已就绪！

**⏰ 下一步**：系统将在明天06:00 UTC开始自动运行，24小时后即可查看首批投资洞察报告。
