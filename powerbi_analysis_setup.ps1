# =============================================
# Power BI分析设置脚本
# =============================================

Write-Host "📊 设置Power BI分析方案..." -ForegroundColor Green

# 数据库连接信息
$ServerName = "seafood-sql-server.database.windows.net"
$DatabaseName = "seafood-analysis-db"
$Username = "yufei"

Write-Host "🔗 数据库连接信息:" -ForegroundColor Yellow
Write-Host "   服务器: $ServerName"
Write-Host "   数据库: $DatabaseName"
Write-Host "   用户: $Username"
Write-Host ""

# 提示用户输入密码
$Password = Read-Host "请输入数据库密码" -AsSecureString
$PlainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))

# 构建连接字符串
$ConnectionString = "Server=$ServerName;Database=$DatabaseName;User Id=$Username;Password=$PlainPassword;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

Write-Host "📋 Power BI设置步骤:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1️⃣ 打开Power BI Desktop" -ForegroundColor Yellow
Write-Host "2️⃣ 点击 '获取数据' -> '数据库' -> 'SQL Server数据库'" -ForegroundColor Yellow
Write-Host "3️⃣ 输入服务器信息:" -ForegroundColor Yellow
Write-Host "   服务器: $ServerName" -ForegroundColor White
Write-Host "   数据库: $DatabaseName" -ForegroundColor White
Write-Host "4️⃣ 选择 '数据库' 认证方式" -ForegroundColor Yellow
Write-Host "   用户名: $Username" -ForegroundColor White
Write-Host "   密码: [你刚才输入的密码]" -ForegroundColor White
Write-Host "5️⃣ 选择表: FishingEvents" -ForegroundColor Yellow
Write-Host "6️⃣ 点击 '加载' 开始分析" -ForegroundColor Yellow
Write-Host ""

# 创建Power BI查询模板
Write-Host "📝 创建Power BI查询模板..." -ForegroundColor Yellow

$PowerBIQuery = @"
-- Power BI 推荐查询
-- 用于创建交互式仪表板

-- 1. 基础数据视图
SELECT 
    EventId,
    EventType,
    VesselId,
    PortId,
    PortName,
    StartTime,
    DurationHours,
    CAST(StartTime as DATE) as EventDate,
    DATEPART(HOUR, StartTime) as EventHour,
    DATEPART(WEEKDAY, StartTime) as DayOfWeek
FROM [dbo].[FishingEvents]
WHERE StartTime >= DATEADD(day, -30, GETDATE())
ORDER BY StartTime DESC;

-- 2. 港口统计视图
SELECT 
    PortName,
    PortId,
    COUNT(*) as VisitCount,
    COUNT(DISTINCT VesselId) as UniqueVessels,
    AVG(DurationHours) as AvgDuration,
    MIN(StartTime) as FirstVisit,
    MAX(StartTime) as LastVisit
FROM [dbo].[FishingEvents]
GROUP BY PortName, PortId;

-- 3. 船只活动视图
SELECT 
    VesselId,
    COUNT(*) as TotalVisits,
    COUNT(DISTINCT PortId) as PortsVisited,
    SUM(DurationHours) as TotalDuration,
    MIN(StartTime) as FirstActivity,
    MAX(StartTime) as LastActivity
FROM [dbo].[FishingEvents]
GROUP BY VesselId;

-- 4. 时间趋势视图
SELECT 
    CAST(StartTime as DATE) as EventDate,
    COUNT(*) as DailyEvents,
    COUNT(DISTINCT VesselId) as DailyVessels,
    COUNT(DISTINCT PortId) as DailyPorts,
    AVG(DurationHours) as AvgDuration
FROM [dbo].[FishingEvents]
GROUP BY CAST(StartTime as DATE)
ORDER BY EventDate DESC;
"@

$PowerBIQuery | Out-File -FilePath "powerbi_queries.sql" -Encoding UTF8

Write-Host "✅ Power BI查询模板已创建: powerbi_queries.sql" -ForegroundColor Green
Write-Host ""

# 创建Power BI仪表板建议
Write-Host "📊 推荐的Power BI仪表板组件:" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎯 关键指标卡片:" -ForegroundColor Yellow
Write-Host "   • 总事件数"
Write-Host "   • 活跃船只数"
Write-Host "   • 活跃港口数"
Write-Host "   • 平均停留时间"
Write-Host ""
Write-Host "📈 图表组件:" -ForegroundColor Yellow
Write-Host "   • 港口访问次数柱状图"
Write-Host "   • 船只活动频率饼图"
Write-Host "   • 时间趋势折线图"
Write-Host "   • 停留时间分布直方图"
Write-Host ""
Write-Host "🗺️ 地图组件:" -ForegroundColor Yellow
Write-Host "   • 港口位置地图"
Write-Host "   • 船只轨迹地图"
Write-Host "   • 热力图"
Write-Host ""
Write-Host "📋 表格组件:" -ForegroundColor Yellow
Write-Host "   • 热门港口排行"
Write-Host "   • 活跃船只排行"
Write-Host "   • 详细事件列表"
Write-Host ""

Write-Host "🚀 开始Power BI分析吧!" -ForegroundColor Green
