-- 为seafood-analysis-db数据库创建渔业分析表结构
-- 连接到: seafood-sql-server.database.windows.net
-- 数据库: seafood-analysis-db

USE [seafood-analysis-db]
GO

-- 创建主要的渔业事件表
CREATE TABLE [dbo].[FishingEvents] (
    [Id] [int] IDENTITY(1,1) NOT NULL,
    [EventId] [nvarchar](100) NOT NULL,
    [EventType] [nvarchar](50) NOT NULL,
    [VesselId] [nvarchar](100) NOT NULL,
    [VesselName] [nvarchar](200) NULL,
    [VesselFlag] [nvarchar](10) NULL,
    [VesselClass] [nvarchar](100) NULL,
    [PortId] [nvarchar](100) NULL,
    [PortName] [nvarchar](200) NULL,
    [PortCountry] [nvarchar](100) NULL,
    [PortLatitude] [decimal](18,6) NULL,
    [PortLongitude] [decimal](18,6) NULL,
    [StartTime] [datetime2](7) NOT NULL,
    [EndTime] [datetime2](7) NULL,
    [DurationHours] [decimal](18,2) NULL,
    [ProcessingDate] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    [CreatedDate] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT [PK_FishingEvents] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [UQ_FishingEvents_EventId] UNIQUE ([EventId])
);

-- 创建港口访问分析表（核心分析表）
CREATE TABLE [dbo].[PortVisitAnalysis] (
    [Id] [int] IDENTITY(1,1) NOT NULL,
    [PortId] [nvarchar](100) NOT NULL,
    [PortName] [nvarchar](200) NOT NULL,
    [PortCountry] [nvarchar](100) NOT NULL,
    [PortVisitCount] [int] NOT NULL,                    -- 港口访问次数
    [AvgStayHours] [decimal](18,2) NOT NULL,           -- 平均停留时间
    [TotalTradeHours] [decimal](18,2) NOT NULL,        -- 总贸易小时数
    [PortVessels] [int] NOT NULL,                      -- 独特船只数量
    [AnalysisPeriodStart] [datetime2](7) NOT NULL,
    [AnalysisPeriodEnd] [datetime2](7) NOT NULL,
    [ProcessingDate] [datetime2](7) NOT NULL,
    [CreatedDate] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT [PK_PortVisitAnalysis] PRIMARY KEY CLUSTERED ([Id] ASC)
);

-- 创建投资洞察表
CREATE TABLE [dbo].[InvestmentInsights] (
    [Id] [int] IDENTITY(1,1) NOT NULL,
    [PortId] [nvarchar](100) NOT NULL,
    [PortName] [nvarchar](200) NOT NULL,
    [PortCountry] [nvarchar](100) NOT NULL,
    [InvestmentPriority] [nvarchar](20) NOT NULL,      -- HIGH, MEDIUM, LOW
    [TradeVolumeScore] [decimal](5,2) NOT NULL,        -- 0-100 贸易量评分
    [EfficiencyScore] [decimal](5,2) NOT NULL,         -- 0-100 效率评分
    [GrowthPotentialScore] [decimal](5,2) NOT NULL,    -- 0-100 增长潜力评分
    [OverallScore] [decimal](5,2) NOT NULL,            -- 0-100 综合评分
    [RecommendedInvestment] [nvarchar](500) NULL,      -- 投资建议
    [ExpectedROI] [decimal](5,2) NULL,                 -- 预期投资回报率
    [ProcessingDate] [datetime2](7) NOT NULL,
    [CreatedDate] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT [PK_InvestmentInsights] PRIMARY KEY CLUSTERED ([Id] ASC)
);

-- 创建索引以提高查询性能
CREATE NONCLUSTERED INDEX [IX_FishingEvents_EventType] ON [dbo].[FishingEvents] ([EventType]);
CREATE NONCLUSTERED INDEX [IX_FishingEvents_PortId] ON [dbo].[FishingEvents] ([PortId]);
CREATE NONCLUSTERED INDEX [IX_FishingEvents_VesselId] ON [dbo].[FishingEvents] ([VesselId]);
CREATE NONCLUSTERED INDEX [IX_FishingEvents_StartTime] ON [dbo].[FishingEvents] ([StartTime]);
CREATE NONCLUSTERED INDEX [IX_FishingEvents_PortCountry] ON [dbo].[FishingEvents] ([PortCountry]);

CREATE NONCLUSTERED INDEX [IX_PortVisitAnalysis_TotalTradeHours] ON [dbo].[PortVisitAnalysis] ([TotalTradeHours] DESC);
CREATE NONCLUSTERED INDEX [IX_InvestmentInsights_OverallScore] ON [dbo].[InvestmentInsights] ([OverallScore] DESC);

-- 创建存储过程：港口访问分析
CREATE PROCEDURE [dbo].[sp_GeneratePortAnalysisInsights]
    @ProcessingDate DATETIME2(7),
    @AnalysisPeriodDays INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PeriodStart DATETIME2(7) = DATEADD(DAY, -@AnalysisPeriodDays, @ProcessingDate);
    
    -- 清除现有分析结果
    DELETE FROM [dbo].[PortVisitAnalysis] 
    WHERE [ProcessingDate] = @ProcessingDate;
    
    -- 生成港口访问分析（核心分析指标）
    INSERT INTO [dbo].[PortVisitAnalysis] (
        [PortId], [PortName], [PortCountry], [PortVisitCount], [AvgStayHours], 
        [TotalTradeHours], [PortVessels], [AnalysisPeriodStart], [AnalysisPeriodEnd], [ProcessingDate]
    )
    SELECT 
        [PortId],
        MAX([PortName]) as [PortName],
        MAX([PortCountry]) as [PortCountry],
        COUNT(*) as [PortVisitCount],                                    -- 港口访问次数
        AVG([DurationHours]) as [AvgStayHours],                         -- 平均停留时间
        SUM([DurationHours]) as [TotalTradeHours],                      -- 总贸易小时数
        COUNT(DISTINCT [VesselId]) as [PortVessels],                    -- 独特船只数量
        @PeriodStart as [AnalysisPeriodStart],
        @ProcessingDate as [AnalysisPeriodEnd],
        @ProcessingDate as [ProcessingDate]
    FROM [dbo].[FishingEvents]
    WHERE [EventType] = 'port_visit'
        AND [StartTime] >= @PeriodStart
        AND [StartTime] <= @ProcessingDate
        AND [PortId] IS NOT NULL
        AND [DurationHours] IS NOT NULL
        AND [DurationHours] > 0
    GROUP BY [PortId];
    
    -- 生成投资洞察
    DELETE FROM [dbo].[InvestmentInsights] 
    WHERE [ProcessingDate] = @ProcessingDate;
    
    INSERT INTO [dbo].[InvestmentInsights] (
        [PortId], [PortName], [PortCountry], [InvestmentPriority], 
        [TradeVolumeScore], [EfficiencyScore], [GrowthPotentialScore], [OverallScore],
        [RecommendedInvestment], [ExpectedROI], [ProcessingDate]
    )
    SELECT 
        pva.[PortId],
        pva.[PortName],
        pva.[PortCountry],
        CASE 
            WHEN overall_score >= 80 THEN 'HIGH'
            WHEN overall_score >= 60 THEN 'MEDIUM'
            ELSE 'LOW'
        END as [InvestmentPriority],
        trade_volume_score as [TradeVolumeScore],
        efficiency_score as [EfficiencyScore],
        growth_potential_score as [GrowthPotentialScore],
        overall_score as [OverallScore],
        CASE 
            WHEN overall_score >= 80 THEN 'Priority investment in port infrastructure and cold chain facilities'
            WHEN overall_score >= 60 THEN 'Consider investment in specialized facilities and operational improvements'
            ELSE 'Monitor for future opportunities, focus on cost-effective improvements'
        END as [RecommendedInvestment],
        CASE 
            WHEN overall_score >= 80 THEN 15.0 + (overall_score - 80) * 0.5
            WHEN overall_score >= 60 THEN 8.0 + (overall_score - 60) * 0.35
            ELSE 3.0 + overall_score * 0.08
        END as [ExpectedROI],
        @ProcessingDate as [ProcessingDate]
    FROM (
        SELECT 
            pva.[PortId],
            pva.[PortName],
            pva.[PortCountry],
            -- 贸易量评分 (40%权重)
            CASE 
                WHEN pva.[TotalTradeHours] >= max_trade_hours * 0.8 THEN 100
                WHEN pva.[TotalTradeHours] >= max_trade_hours * 0.6 THEN 80
                WHEN pva.[TotalTradeHours] >= max_trade_hours * 0.4 THEN 60
                WHEN pva.[TotalTradeHours] >= max_trade_hours * 0.2 THEN 40
                ELSE 20
            END as trade_volume_score,
            -- 效率评分 (30%权重) - 停留时间越短效率越高
            CASE 
                WHEN pva.[AvgStayHours] <= min_avg_stay * 1.2 THEN 100
                WHEN pva.[AvgStayHours] <= min_avg_stay * 1.5 THEN 80
                WHEN pva.[AvgStayHours] <= min_avg_stay * 2.0 THEN 60
                WHEN pva.[AvgStayHours] <= min_avg_stay * 3.0 THEN 40
                ELSE 20
            END as efficiency_score,
            -- 增长潜力评分 (30%权重)
            CASE 
                WHEN pva.[PortVessels] >= max_vessels * 0.8 THEN 100
                WHEN pva.[PortVessels] >= max_vessels * 0.6 THEN 80
                WHEN pva.[PortVessels] >= max_vessels * 0.4 THEN 60
                WHEN pva.[PortVessels] >= max_vessels * 0.2 THEN 40
                ELSE 20
            END as growth_potential_score
        FROM [dbo].[PortVisitAnalysis] pva
        CROSS JOIN (
            SELECT 
                MAX([TotalTradeHours]) as max_trade_hours,
                MIN([AvgStayHours]) as min_avg_stay,
                MAX([PortVessels]) as max_vessels
            FROM [dbo].[PortVisitAnalysis]
            WHERE [ProcessingDate] = @ProcessingDate
        ) stats
        WHERE pva.[ProcessingDate] = @ProcessingDate
    ) scored
    CROSS APPLY (
        SELECT (trade_volume_score * 0.4 + efficiency_score * 0.3 + growth_potential_score * 0.3) as overall_score
    ) final_score;
    
END;
GO

PRINT '✅ 数据库表结构创建完成！'
PRINT '📊 已创建表：FishingEvents, PortVisitAnalysis, InvestmentInsights'
PRINT '🔧 已创建存储过程：sp_GeneratePortAnalysisInsights'
PRINT '📈 系统准备就绪，可以开始港口访问分析！'
