# =============================================
# 连接到Azure SQL Database并查看分析结果
# =============================================

Write-Host "🔍 连接到Azure SQL Database查看分析结果..." -ForegroundColor Green

# 数据库连接信息
$ServerName = "seafood-sql-server.database.windows.net"
$DatabaseName = "seafood-analysis-db"
$Username = "yufei"

Write-Host "📊 数据库信息:" -ForegroundColor Yellow
Write-Host "   服务器: $ServerName"
Write-Host "   数据库: $DatabaseName"
Write-Host "   用户: $Username"
Write-Host ""

# 提示用户输入密码
$Password = Read-Host "请输入数据库密码" -AsSecureString
$PlainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))

# 构建连接字符串
$ConnectionString = "Server=$ServerName;Database=$DatabaseName;User Id=$Username;Password=$PlainPassword;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

try {
    # 加载SQL Server模块
    Write-Host "📦 加载SQL Server模块..." -ForegroundColor Yellow
    Import-Module SqlServer -ErrorAction SilentlyContinue
    
    if (-not (Get-Module SqlServer)) {
        Write-Host "❌ 未找到SqlServer模块，请安装: Install-Module SqlServer" -ForegroundColor Red
        Write-Host "💡 或者使用Azure门户的查询编辑器" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "🌐 Azure门户查询步骤:" -ForegroundColor Cyan
        Write-Host "1. 访问 https://portal.azure.com"
        Write-Host "2. 搜索 'seafood-sql-server'"
        Write-Host "3. 点击 '查询编辑器'"
        Write-Host "4. 使用用户名: yufei 和密码登录"
        Write-Host "5. 运行 view_analysis_results.sql 中的查询"
        exit
    }
    
    Write-Host "✅ 成功连接到数据库!" -ForegroundColor Green
    Write-Host ""
    
    # 运行基本统计查询
    Write-Host "📊 运行数据分析查询..." -ForegroundColor Yellow
    
    $Query1 = @"
SELECT 
    COUNT(*) as TotalEvents,
    COUNT(DISTINCT VesselId) as UniqueVessels,
    COUNT(DISTINCT PortId) as UniquePorts,
    MIN(StartTime) as EarliestEventTime,
    MAX(StartTime) as LatestEventTime
FROM [dbo].[FishingEvents]
"@

    Write-Host "🔍 Data Overview:" -ForegroundColor Cyan
    Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $Query1 | Format-Table -AutoSize
    
    $Query2 = @"
SELECT TOP 10
    PortName,
    COUNT(*) as VisitCount,
    COUNT(DISTINCT VesselId) as UniqueVessels
FROM [dbo].[FishingEvents]
GROUP BY PortName
ORDER BY VisitCount DESC
"@

    Write-Host "🏆 Top 10 Busiest Ports:" -ForegroundColor Cyan
    Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $Query2 | Format-Table -AutoSize
    
    Write-Host ""
    Write-Host "✅ 查询完成! 更多分析请查看 view_analysis_results.sql 文件" -ForegroundColor Green
    
} catch {
    Write-Host "❌ 连接失败: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 替代方案:" -ForegroundColor Yellow
    Write-Host "1. 使用Azure门户的查询编辑器"
    Write-Host "2. 使用SQL Server Management Studio"
    Write-Host "3. 使用Azure Data Studio"
}
