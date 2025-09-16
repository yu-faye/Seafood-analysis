-- Global Fishing Watch Events Analysis Database Schema
-- Azure SQL Database / Synapse Analytics
-- Updated for Port Visit Analysis and Investment Insights

-- Create main fishing events table
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
    [ProcessingDate] [datetime2](7) NOT NULL,
    [CreatedDate] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT [PK_FishingEvents] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [UQ_FishingEvents_EventId] UNIQUE ([EventId])
);

-- Create port visit analysis table (Task 1: Port Visit Analysis)
CREATE TABLE [dbo].[PortVisitAnalysis] (
    [Id] [int] IDENTITY(1,1) NOT NULL,
    [PortId] [nvarchar](100) NOT NULL,
    [PortName] [nvarchar](200) NOT NULL,
    [PortCountry] [nvarchar](100) NOT NULL,
    [PortVisitCount] [int] NOT NULL,                    -- 港口访问次数
    [AvgStayHours] [decimal](18,2) NOT NULL,           -- 平均停留时间
    [TotalTradeHours] [decimal](18,2) NOT NULL,        -- 总贸易小时数 (访问次数 × 停留时间)
    [PortVessels] [int] NOT NULL,                      -- 独特船只数量
    [AnalysisPeriodStart] [datetime2](7) NOT NULL,
    [AnalysisPeriodEnd] [datetime2](7) NOT NULL,
    [ProcessingDate] [datetime2](7) NOT NULL,
    [CreatedDate] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT [PK_PortVisitAnalysis] PRIMARY KEY CLUSTERED ([Id] ASC)
);

-- Create investment insights table
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

-- Create vessel activity summary table
CREATE TABLE [dbo].[VesselActivitySummary] (
    [Id] [int] IDENTITY(1,1) NOT NULL,
    [VesselId] [nvarchar](100) NOT NULL,
    [VesselName] [nvarchar](200) NULL,
    [VesselFlag] [nvarchar](10) NULL,
    [VesselClass] [nvarchar](100) NULL,
    [TotalPortVisits] [int] NOT NULL,
    [UniquePortsVisited] [int] NOT NULL,
    [TotalFishingEvents] [int] NOT NULL,
    [AvgPortStayHours] [decimal](18,2) NULL,
    [TotalActivityHours] [decimal](18,2) NULL,
    [MostFrequentPort] [nvarchar](200) NULL,
    [ProcessingDate] [datetime2](7) NOT NULL,
    [CreatedDate] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT [PK_VesselActivitySummary] PRIMARY KEY CLUSTERED ([Id] ASC)
);

-- Create country trade summary table
CREATE TABLE [dbo].[CountryTradeSummary] (
    [Id] [int] IDENTITY(1,1) NOT NULL,
    [Country] [nvarchar](100) NOT NULL,
    [TotalPorts] [int] NOT NULL,
    [TotalPortVisits] [int] NOT NULL,
    [TotalVessels] [int] NOT NULL,
    [TotalTradeHours] [decimal](18,2) NOT NULL,
    [AvgPortEfficiency] [decimal](18,2) NOT NULL,
    [TradeVolumeRank] [int] NOT NULL,
    [ProcessingDate] [datetime2](7) NOT NULL,
    [CreatedDate] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT [PK_CountryTradeSummary] PRIMARY KEY CLUSTERED ([Id] ASC)
);

-- Create indexes for better performance
CREATE NONCLUSTERED INDEX [IX_FishingEvents_EventType] ON [dbo].[FishingEvents] ([EventType]);
CREATE NONCLUSTERED INDEX [IX_FishingEvents_PortId] ON [dbo].[FishingEvents] ([PortId]);
CREATE NONCLUSTERED INDEX [IX_FishingEvents_VesselId] ON [dbo].[FishingEvents] ([VesselId]);
CREATE NONCLUSTERED INDEX [IX_FishingEvents_StartTime] ON [dbo].[FishingEvents] ([StartTime]);
CREATE NONCLUSTERED INDEX [IX_FishingEvents_ProcessingDate] ON [dbo].[FishingEvents] ([ProcessingDate]);
CREATE NONCLUSTERED INDEX [IX_FishingEvents_PortCountry] ON [dbo].[FishingEvents] ([PortCountry]);

CREATE NONCLUSTERED INDEX [IX_PortVisitAnalysis_PortId] ON [dbo].[PortVisitAnalysis] ([PortId]);
CREATE NONCLUSTERED INDEX [IX_PortVisitAnalysis_TotalTradeHours] ON [dbo].[PortVisitAnalysis] ([TotalTradeHours] DESC);
CREATE NONCLUSTERED INDEX [IX_PortVisitAnalysis_PortVessels] ON [dbo].[PortVisitAnalysis] ([PortVessels] DESC);

CREATE NONCLUSTERED INDEX [IX_InvestmentInsights_InvestmentPriority] ON [dbo].[InvestmentInsights] ([InvestmentPriority]);
CREATE NONCLUSTERED INDEX [IX_InvestmentInsights_OverallScore] ON [dbo].[InvestmentInsights] ([OverallScore] DESC);

-- Create table type for bulk insert
CREATE TYPE [dbo].[FishingEventsTableType] AS TABLE(
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
    [ProcessingDate] [datetime2](7) NOT NULL
);

-- Create stored procedure for upserting fishing events
CREATE PROCEDURE [dbo].[sp_UpsertFishingEvents]
    @FishingEvents FishingEventsTableType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    
    MERGE [dbo].[FishingEvents] AS target
    USING @FishingEvents AS source
    ON target.[EventId] = source.[EventId]
    WHEN MATCHED THEN
        UPDATE SET
            [EventType] = source.[EventType],
            [VesselId] = source.[VesselId],
            [VesselName] = source.[VesselName],
            [VesselFlag] = source.[VesselFlag],
            [VesselClass] = source.[VesselClass],
            [PortId] = source.[PortId],
            [PortName] = source.[PortName],
            [PortCountry] = source.[PortCountry],
            [PortLatitude] = source.[PortLatitude],
            [PortLongitude] = source.[PortLongitude],
            [StartTime] = source.[StartTime],
            [EndTime] = source.[EndTime],
            [DurationHours] = source.[DurationHours],
            [ProcessingDate] = source.[ProcessingDate]
    WHEN NOT MATCHED THEN
        INSERT ([EventId], [EventType], [VesselId], [VesselName], [VesselFlag], [VesselClass],
                [PortId], [PortName], [PortCountry], [PortLatitude], [PortLongitude],
                [StartTime], [EndTime], [DurationHours], [ProcessingDate])
        VALUES (source.[EventId], source.[EventType], source.[VesselId], source.[VesselName],
                source.[VesselFlag], source.[VesselClass], source.[PortId], source.[PortName],
                source.[PortCountry], source.[PortLatitude], source.[PortLongitude],
                source.[StartTime], source.[EndTime], source.[DurationHours], source.[ProcessingDate]);
END;

-- Create stored procedure for port visit analysis (Task 1)
CREATE PROCEDURE [dbo].[sp_GeneratePortAnalysisInsights]
    @ProcessingDate DATETIME2(7),
    @AnalysisPeriodDays INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @PeriodStart DATETIME2(7) = DATEADD(DAY, -@AnalysisPeriodDays, @ProcessingDate);
    
    -- Clear existing analysis for this processing date
    DELETE FROM [dbo].[PortVisitAnalysis] 
    WHERE [ProcessingDate] = @ProcessingDate;
    
    -- Generate port visit analysis
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
    
    -- Update vessel activity summary
    DELETE FROM [dbo].[VesselActivitySummary] 
    WHERE [ProcessingDate] = @ProcessingDate;
    
    INSERT INTO [dbo].[VesselActivitySummary] (
        [VesselId], [VesselName], [VesselFlag], [VesselClass], [TotalPortVisits],
        [UniquePortsVisited], [TotalFishingEvents], [AvgPortStayHours], [TotalActivityHours],
        [MostFrequentPort], [ProcessingDate]
    )
    SELECT 
        v.[VesselId],
        MAX(v.[VesselName]) as [VesselName],
        MAX(v.[VesselFlag]) as [VesselFlag],
        MAX(v.[VesselClass]) as [VesselClass],
        SUM(CASE WHEN v.[EventType] = 'port_visit' THEN 1 ELSE 0 END) as [TotalPortVisits],
        COUNT(DISTINCT CASE WHEN v.[EventType] = 'port_visit' THEN v.[PortId] END) as [UniquePortsVisited],
        SUM(CASE WHEN v.[EventType] = 'fishing' THEN 1 ELSE 0 END) as [TotalFishingEvents],
        AVG(CASE WHEN v.[EventType] = 'port_visit' THEN v.[DurationHours] END) as [AvgPortStayHours],
        SUM(v.[DurationHours]) as [TotalActivityHours],
        (SELECT TOP 1 [PortName] 
         FROM [dbo].[FishingEvents] pv 
         WHERE pv.[VesselId] = v.[VesselId] 
           AND pv.[EventType] = 'port_visit'
           AND pv.[StartTime] >= @PeriodStart
           AND pv.[StartTime] <= @ProcessingDate
         GROUP BY [PortName] 
         ORDER BY COUNT(*) DESC) as [MostFrequentPort],
        @ProcessingDate as [ProcessingDate]
    FROM [dbo].[FishingEvents] v
    WHERE v.[StartTime] >= @PeriodStart
        AND v.[StartTime] <= @ProcessingDate
    GROUP BY v.[VesselId];
    
    -- Update country trade summary
    DELETE FROM [dbo].[CountryTradeSummary] 
    WHERE [ProcessingDate] = @ProcessingDate;
    
    INSERT INTO [dbo].[CountryTradeSummary] (
        [Country], [TotalPorts], [TotalPortVisits], [TotalVessels], 
        [TotalTradeHours], [AvgPortEfficiency], [TradeVolumeRank], [ProcessingDate]
    )
    SELECT 
        [PortCountry] as [Country],
        COUNT(DISTINCT [PortId]) as [TotalPorts],
        COUNT(*) as [TotalPortVisits],
        COUNT(DISTINCT [VesselId]) as [TotalVessels],
        SUM([DurationHours]) as [TotalTradeHours],
        AVG([DurationHours]) as [AvgPortEfficiency],
        ROW_NUMBER() OVER (ORDER BY SUM([DurationHours]) DESC) as [TradeVolumeRank],
        @ProcessingDate as [ProcessingDate]
    FROM [dbo].[FishingEvents]
    WHERE [EventType] = 'port_visit'
        AND [StartTime] >= @PeriodStart
        AND [StartTime] <= @ProcessingDate
        AND [PortCountry] IS NOT NULL
        AND [DurationHours] IS NOT NULL
        AND [DurationHours] > 0
    GROUP BY [PortCountry];
    
END;

-- Create stored procedure for investment insights generation
CREATE PROCEDURE [dbo].[sp_GenerateInvestmentInsights]
    @ProcessingDate DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Clear existing investment insights
    DELETE FROM [dbo].[InvestmentInsights] 
    WHERE [ProcessingDate] = @ProcessingDate;
    
    -- Generate investment insights based on port visit analysis
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
            WHEN overall_score >= 80 THEN 'Priority investment in port infrastructure, cold chain facilities, and logistics optimization'
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
            -- Trade Volume Score (0-100): Based on TotalTradeHours
            CASE 
                WHEN pva.[TotalTradeHours] >= max_trade_hours * 0.8 THEN 100
                WHEN pva.[TotalTradeHours] >= max_trade_hours * 0.6 THEN 80
                WHEN pva.[TotalTradeHours] >= max_trade_hours * 0.4 THEN 60
                WHEN pva.[TotalTradeHours] >= max_trade_hours * 0.2 THEN 40
                ELSE 20
            END as trade_volume_score,
            -- Efficiency Score (0-100): Based on AvgStayHours (lower is better for efficiency)
            CASE 
                WHEN pva.[AvgStayHours] <= min_avg_stay * 1.2 THEN 100
                WHEN pva.[AvgStayHours] <= min_avg_stay * 1.5 THEN 80
                WHEN pva.[AvgStayHours] <= min_avg_stay * 2.0 THEN 60
                WHEN pva.[AvgStayHours] <= min_avg_stay * 3.0 THEN 40
                ELSE 20
            END as efficiency_score,
            -- Growth Potential Score (0-100): Based on PortVessels and PortVisitCount
            CASE 
                WHEN pva.[PortVessels] >= max_vessels * 0.8 AND pva.[PortVisitCount] >= max_visits * 0.8 THEN 100
                WHEN pva.[PortVessels] >= max_vessels * 0.6 AND pva.[PortVisitCount] >= max_visits * 0.6 THEN 80
                WHEN pva.[PortVessels] >= max_vessels * 0.4 AND pva.[PortVisitCount] >= max_visits * 0.4 THEN 60
                WHEN pva.[PortVessels] >= max_vessels * 0.2 AND pva.[PortVisitCount] >= max_visits * 0.2 THEN 40
                ELSE 20
            END as growth_potential_score
        FROM [dbo].[PortVisitAnalysis] pva
        CROSS JOIN (
            SELECT 
                MAX([TotalTradeHours]) as max_trade_hours,
                MIN([AvgStayHours]) as min_avg_stay,
                MAX([PortVessels]) as max_vessels,
                MAX([PortVisitCount]) as max_visits
            FROM [dbo].[PortVisitAnalysis]
            WHERE [ProcessingDate] = @ProcessingDate
        ) stats
        WHERE pva.[ProcessingDate] = @ProcessingDate
    ) scored
    CROSS APPLY (
        SELECT (trade_volume_score * 0.4 + efficiency_score * 0.3 + growth_potential_score * 0.3) as overall_score
    ) final_score;
    
END;

