# 🐟 Global Fishing Watch Analysis on Azure Data Factory

## 🎯 项目目标

本项目基于Global Fishing Watch API v3的`/v3/events`端点，专注于**港口访问分析**和**投资价值洞察**，为投资者提供经济价值分析，支持港口基础设施、渔业资产和供应链优化的投资决策。

## 📊 核心分析任务

### 任务1：港口访问分析（Port Visit Analysis）

**目标**：评估港口的贸易流量和物流潜力，识别高价值港口用于投资

**关键指标**：
- **PortVisitCount**：港口访问次数，反映贸易活跃度
- **AvgStayHours**：平均停留时间，评估港口效率
- **TotalTradeHours**：总贸易小时数（访问次数 × 停留时间），估算贸易量
- **PortVessels**：独特船只数量，反映港口的市场覆盖

**投资价值**：高TotalTradeHours的港口是物流投资的优先选择，表明高吞吐量和经济潜力

## 🏗️ 架构概览

```
Global Fishing Watch API → ADF Pipeline → Data Lake → SQL Database → Power BI
        ↓                      ↓           ↓           ↓             ↓
    渔业事件数据            数据获取与处理    原始数据存储   分析数据库    投资洞察仪表板
```

## 🚀 快速部署

### 前提条件

- Azure订阅（具有贡献者权限）
- PowerShell 5.1 或更高版本
- Azure PowerShell模块
- Global Fishing Watch API Token

### 1. 登录Azure

```powershell
# 安装Azure PowerShell（如果尚未安装）
Install-Module -Name Az -AllowClobber -Scope CurrentUser

# 登录Azure
Connect-AzAccount
Set-AzContext -Subscription "Your-Subscription-Name"
```

### 2. 设置参数并部署

```powershell
# 设置部署参数
$ResourceGroupName = "fishing-analysis-rg"
$Location = "West Europe"
$DataFactoryName = "fishing-adf-$(Get-Random)"
$StorageAccountName = "fishingdata$(Get-Random)"
$SqlServerName = "fishing-sql-$(Get-Random)"
$SqlDatabaseName = "fishing-analysis-db"
$SqlUsername = "fishingadmin"
$SqlPassword = "YourSecurePassword123!"
$GFWApiToken = "your-gfw-api-token-here"

# 执行部署
.\deployment\deploy-fishing-analysis.ps1 `
    -ResourceGroupName $ResourceGroupName `
    -Location $Location `
    -DataFactoryName $DataFactoryName `
    -StorageAccountName $StorageAccountName `
    -SqlServerName $SqlServerName `
    -SqlDatabaseName $SqlDatabaseName `
    -SqlUsername $SqlUsername `
    -SqlPassword $SqlPassword `
    -GFWApiToken $GFWApiToken
```

### 3. 上传Databricks笔记本

1. 打开Azure Databricks工作区
2. 创建新笔记本：`/fishing-analysis/process-fishing-events`
3. 复制`scripts/databricks-fishing-events-processor.py`的内容
4. 保存笔记本

### 4. 测试管道

1. 打开Azure Data Factory Studio
2. 导航到管道：`FishingEventsDataProcessingPipeline`
3. 点击"调试"测试管道
4. 监控执行状态

## 📊 数据流程

### 1. 数据获取
- **Web Activity**：从Global Fishing Watch API获取渔业事件数据
- **数据类型**：港口访问事件（port_visit）和捕捞事件（fishing）
- **时间范围**：过去30天的数据

### 2. 数据处理
- **Databricks处理**：解析JSON数据，清洗和转换
- **数据验证**：确保数据质量和完整性
- **增强处理**：计算停留时间、访问频率等指标

### 3. 数据存储
- **原始数据**：JSON格式存储在Data Lake
- **处理数据**：CSV格式用于分析
- **分析数据库**：结构化数据用于报告和洞察

### 4. 分析生成
- **港口分析**：执行`sp_GeneratePortAnalysisInsights`存储过程
- **投资洞察**：执行`sp_GenerateInvestmentInsights`存储过程
- **自动化报告**：生成投资优先级和ROI预测

## 🗄️ 数据库结构

### 核心表结构

#### FishingEvents（渔业事件表）
- 存储所有从GFW API获取的事件数据
- 包含船只、港口、时间等详细信息

#### PortVisitAnalysis（港口访问分析表）
- **PortVisitCount**：港口访问次数
- **AvgStayHours**：平均停留时间
- **TotalTradeHours**：总贸易小时数
- **PortVessels**：独特船只数量

#### InvestmentInsights（投资洞察表）
- **InvestmentPriority**：投资优先级（HIGH/MEDIUM/LOW）
- **TradeVolumeScore**：贸易量评分（0-100）
- **EfficiencyScore**：效率评分（0-100）
- **OverallScore**：综合评分（0-100）
- **ExpectedROI**：预期投资回报率

## 📈 投资洞察算法

### 评分体系（0-100分）

1. **贸易量评分（40%权重）**
   - 基于TotalTradeHours
   - 高贸易量 = 高投资潜力

2. **效率评分（30%权重）**
   - 基于AvgStayHours（越低越好）
   - 高效率 = 更好的投资回报

3. **增长潜力评分（30%权重）**
   - 基于PortVessels和PortVisitCount
   - 多样化船只 = 稳定增长

### 投资优先级分类

- **HIGH（≥80分）**：优先投资港口基础设施、冷链设施
- **MEDIUM（60-79分）**：考虑专业设施和运营改进投资
- **LOW（<60分）**：监控未来机会，专注成本效益改进

### ROI预测公式

```
ROI = Base Rate + Score Multiplier
- HIGH级别：15% + (分数-80) × 0.5%
- MEDIUM级别：8% + (分数-60) × 0.35%
- LOW级别：3% + 分数 × 0.08%
```

## 🔄 自动化调度

- **执行频率**：每日06:00 UTC自动运行
- **数据更新**：获取过去30天的最新数据
- **分析刷新**：重新计算所有投资指标
- **报告生成**：更新Power BI仪表板

## 📊 Power BI仪表板

### 主要视图

1. **港口投资地图**：显示全球港口投资优先级
2. **贸易流量分析**：展示港口访问趋势
3. **投资ROI预测**：各港口预期回报率
4. **船只活动监控**：船只访问模式分析

## 🔍 监控和警报

### 数据质量监控
- **数据量检查**：监控每日数据获取量
- **数据完整性**：检查关键字段缺失情况
- **处理时间**：监控管道执行时间

### 业务警报
- **高价值港口变化**：投资优先级变动提醒
- **异常活动检测**：港口访问模式异常
- **新投资机会**：新兴高潜力港口识别

## 🔒 安全和合规

### 数据保护
- **API密钥管理**：使用Azure Key Vault存储
- **数据加密**：传输和静态数据加密
- **访问控制**：基于角色的访问控制

### 合规性
- **数据保留**：实施数据生命周期策略
- **审计日志**：完整的操作审计跟踪
- **隐私保护**：符合数据保护法规

## 💰 成本优化

### 资源管理
- **自动缩放**：根据需求调整资源
- **调度优化**：非高峰时段运行
- **数据分层**：旧数据归档到低成本存储

### 预估成本（月度）
- **Data Factory**：$10-30（基于管道运行次数）
- **存储账户**：$5-15（基于数据量）
- **SQL数据库**：$15-50（基本层）
- **Databricks**：$20-100（标准层）
- **总计**：约$50-200/月

## 🆘 故障排除

### 常见问题

1. **API限制**：GFW API有速率限制
   - 解决方案：增加重试逻辑和延迟

2. **数据质量问题**：部分事件缺少港口信息
   - 解决方案：数据验证和清洗逻辑

3. **处理性能**：大数据量处理缓慢
   - 解决方案：优化Databricks集群配置

### 获取帮助

- **技术问题**：检查Azure Data Factory监控日志
- **数据问题**：查看Databricks笔记本执行结果
- **性能问题**：使用Azure Monitor分析资源使用

## 📞 支持联系

- **技术支持**：在repository中创建issue
- **功能请求**：提交功能请求
- **文档贡献**：欢迎改进文档

---

**🎯 投资洞察目标**：通过数据驱动的港口分析，识别最具投资价值的港口基础设施机会，支持智能投资决策。
