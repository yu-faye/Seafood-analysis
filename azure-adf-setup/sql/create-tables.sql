-- Norwegian Seafood Analysis Database Schema
-- Azure SQL Database / Synapse Analytics

-- Create main analysis table
CREATE TABLE [dbo].[SeafoodExportAnalysis] (
    [Id] [int] IDENTITY(1,1) NOT NULL,
    [Week] [int] NOT NULL,
    [Category] [nvarchar](100) NOT NULL,
    [Market] [nvarchar](100) NOT NULL,
    [Current_Week_Volume] [decimal](18,2) NULL,
    [Current_Week_Price] [decimal](18,2) NULL,
    [Previous_Year_Volume] [decimal](18,2) NULL,
    [Previous_Year_Price] [decimal](18,2) NULL,
    [YTD_Current_Volume] [decimal](18,2) NULL,
    [YTD_Current_Price] [decimal](18,2) NULL,
    [YTD_Previous_Volume] [decimal](18,2) NULL,
    [YTD_Previous_Price] [decimal](18,2) NULL,
    [Volume_Growth_Percent] [decimal](18,2) NULL,
    [Price_Change_Percent] [decimal](18,2) NULL,
    [Processing_Date] [datetime2](7) NOT NULL,
    [Created_Date] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT [PK_SeafoodExportAnalysis] PRIMARY KEY CLUSTERED ([Id] ASC)
);

-- Create market summary table
CREATE TABLE [dbo].[MarketSummary] (
    [Id] [int] IDENTITY(1,1) NOT NULL,
    [Market] [nvarchar](100) NOT NULL,
    [Total_Volume] [decimal](18,2) NULL,
    [Average_Price] [decimal](18,2) NULL,
    [Volume_Share_Percent] [decimal](18,2) NULL,
    [Growth_Rate_Percent] [decimal](18,2) NULL,
    [Last_Updated] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT [PK_MarketSummary] PRIMARY KEY CLUSTERED ([Id] ASC)
);

-- Create category summary table
CREATE TABLE [dbo].[CategorySummary] (
    [Id] [int] IDENTITY(1,1) NOT NULL,
    [Category] [nvarchar](100) NOT NULL,
    [Total_Volume] [decimal](18,2) NULL,
    [Average_Price] [decimal](18,2) NULL,
    [Volume_Share_Percent] [decimal](18,2) NULL,
    [Last_Updated] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT [PK_CategorySummary] PRIMARY KEY CLUSTERED ([Id] ASC)
);

-- Create weekly summary table
CREATE TABLE [dbo].[WeeklySummary] (
    [Id] [int] IDENTITY(1,1) NOT NULL,
    [Week] [int] NOT NULL,
    [Total_Volume] [decimal](18,2) NULL,
    [Previous_Year_Volume] [decimal](18,2) NULL,
    [Volume_Growth_Percent] [decimal](18,2) NULL,
    [Average_Price] [decimal](18,2) NULL,
    [Previous_Year_Price] [decimal](18,2) NULL,
    [Price_Change_Percent] [decimal](18,2) NULL,
    [Last_Updated] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT [PK_WeeklySummary] PRIMARY KEY CLUSTERED ([Id] ASC)
);

-- Create insights table
CREATE TABLE [dbo].[SeafoodInsights] (
    [Id] [int] IDENTITY(1,1) NOT NULL,
    [Processing_Date] [datetime2](7) NOT NULL,
    [Total_Volume] [decimal](18,2) NULL,
    [Total_Previous_Volume] [decimal](18,2) NULL,
    [Volume_Growth_Percent] [decimal](18,2) NULL,
    [Average_Price] [decimal](18,2) NULL,
    [Average_Previous_Price] [decimal](18,2) NULL,
    [Price_Change_Percent] [decimal](18,2) NULL,
    [Top_Market] [nvarchar](100) NULL,
    [Top_Market_Volume] [decimal](18,2) NULL,
    [Highest_Price_Market] [nvarchar](100) NULL,
    [Highest_Price] [decimal](18,2) NULL,
    [Total_Records] [int] NULL,
    [Categories_Count] [int] NULL,
    [Markets_Count] [int] NULL,
    [Weeks_Count] [int] NULL,
    [Created_Date] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT [PK_SeafoodInsights] PRIMARY KEY CLUSTERED ([Id] ASC)
);

-- Create indexes for better performance
CREATE NONCLUSTERED INDEX [IX_SeafoodExportAnalysis_Week] ON [dbo].[SeafoodExportAnalysis] ([Week]);
CREATE NONCLUSTERED INDEX [IX_SeafoodExportAnalysis_Category] ON [dbo].[SeafoodExportAnalysis] ([Category]);
CREATE NONCLUSTERED INDEX [IX_SeafoodExportAnalysis_Market] ON [dbo].[SeafoodExportAnalysis] ([Market]);
CREATE NONCLUSTERED INDEX [IX_SeafoodExportAnalysis_ProcessingDate] ON [dbo].[SeafoodExportAnalysis] ([Processing_Date]);

-- Create stored procedure for generating insights
CREATE PROCEDURE [dbo].[sp_GenerateSeafoodInsights]
    @ProcessingDate DATETIME2(7)
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Clear existing insights for this processing date
    DELETE FROM [dbo].[SeafoodInsights] 
    WHERE [Processing_Date] = @ProcessingDate;
    
    -- Calculate and insert insights
    INSERT INTO [dbo].[SeafoodInsights] (
        [Processing_Date],
        [Total_Volume],
        [Total_Previous_Volume],
        [Volume_Growth_Percent],
        [Average_Price],
        [Average_Previous_Price],
        [Price_Change_Percent],
        [Top_Market],
        [Top_Market_Volume],
        [Highest_Price_Market],
        [Highest_Price],
        [Total_Records],
        [Categories_Count],
        [Markets_Count],
        [Weeks_Count]
    )
    SELECT 
        @ProcessingDate,
        SUM([Current_Week_Volume]) as Total_Volume,
        SUM([Previous_Year_Volume]) as Total_Previous_Volume,
        CASE 
            WHEN SUM([Previous_Year_Volume]) > 0 
            THEN ((SUM([Current_Week_Volume]) - SUM([Previous_Year_Volume])) / SUM([Previous_Year_Volume]) * 100)
            ELSE 0 
        END as Volume_Growth_Percent,
        AVG([Current_Week_Price]) as Average_Price,
        AVG([Previous_Year_Price]) as Average_Previous_Price,
        CASE 
            WHEN AVG([Previous_Year_Price]) > 0 
            THEN ((AVG([Current_Week_Price]) - AVG([Previous_Year_Price])) / AVG([Previous_Year_Price]) * 100)
            ELSE 0 
        END as Price_Change_Percent,
        (SELECT TOP 1 [Market] 
         FROM [dbo].[SeafoodExportAnalysis] 
         WHERE [Processing_Date] = @ProcessingDate
         GROUP BY [Market] 
         ORDER BY SUM([Current_Week_Volume]) DESC) as Top_Market,
        (SELECT TOP 1 SUM([Current_Week_Volume]) 
         FROM [dbo].[SeafoodExportAnalysis] 
         WHERE [Processing_Date] = @ProcessingDate
         GROUP BY [Market] 
         ORDER BY SUM([Current_Week_Volume]) DESC) as Top_Market_Volume,
        (SELECT TOP 1 [Market] 
         FROM [dbo].[SeafoodExportAnalysis] 
         WHERE [Processing_Date] = @ProcessingDate
         GROUP BY [Market] 
         ORDER BY AVG([Current_Week_Price]) DESC) as Highest_Price_Market,
        (SELECT TOP 1 AVG([Current_Week_Price]) 
         FROM [dbo].[SeafoodExportAnalysis] 
         WHERE [Processing_Date] = @ProcessingDate
         GROUP BY [Market] 
         ORDER BY AVG([Current_Week_Price]) DESC) as Highest_Price,
        COUNT(*) as Total_Records,
        COUNT(DISTINCT [Category]) as Categories_Count,
        COUNT(DISTINCT [Market]) as Markets_Count,
        COUNT(DISTINCT [Week]) as Weeks_Count
    FROM [dbo].[SeafoodExportAnalysis]
    WHERE [Processing_Date] = @ProcessingDate;
    
    -- Update market summary
    DELETE FROM [dbo].[MarketSummary];
    
    INSERT INTO [dbo].[MarketSummary] (
        [Market],
        [Total_Volume],
        [Average_Price],
        [Volume_Share_Percent],
        [Growth_Rate_Percent]
    )
    SELECT 
        [Market],
        SUM([Current_Week_Volume]) as Total_Volume,
        AVG([Current_Week_Price]) as Average_Price,
        (SUM([Current_Week_Volume]) / (SELECT SUM([Current_Week_Volume]) FROM [dbo].[SeafoodExportAnalysis] WHERE [Processing_Date] = @ProcessingDate) * 100) as Volume_Share_Percent,
        AVG([Volume_Growth_Percent]) as Growth_Rate_Percent
    FROM [dbo].[SeafoodExportAnalysis]
    WHERE [Processing_Date] = @ProcessingDate
    GROUP BY [Market];
    
    -- Update category summary
    DELETE FROM [dbo].[CategorySummary];
    
    INSERT INTO [dbo].[CategorySummary] (
        [Category],
        [Total_Volume],
        [Average_Price],
        [Volume_Share_Percent]
    )
    SELECT 
        [Category],
        SUM([Current_Week_Volume]) as Total_Volume,
        AVG([Current_Week_Price]) as Average_Price,
        (SUM([Current_Week_Volume]) / (SELECT SUM([Current_Week_Volume]) FROM [dbo].[SeafoodExportAnalysis] WHERE [Processing_Date] = @ProcessingDate) * 100) as Volume_Share_Percent
    FROM [dbo].[SeafoodExportAnalysis]
    WHERE [Processing_Date] = @ProcessingDate
    GROUP BY [Category];
    
    -- Update weekly summary
    DELETE FROM [dbo].[WeeklySummary];
    
    INSERT INTO [dbo].[WeeklySummary] (
        [Week],
        [Total_Volume],
        [Previous_Year_Volume],
        [Volume_Growth_Percent],
        [Average_Price],
        [Previous_Year_Price],
        [Price_Change_Percent]
    )
    SELECT 
        [Week],
        SUM([Current_Week_Volume]) as Total_Volume,
        SUM([Previous_Year_Volume]) as Previous_Year_Volume,
        CASE 
            WHEN SUM([Previous_Year_Volume]) > 0 
            THEN ((SUM([Current_Week_Volume]) - SUM([Previous_Year_Volume])) / SUM([Previous_Year_Volume]) * 100)
            ELSE 0 
        END as Volume_Growth_Percent,
        AVG([Current_Week_Price]) as Average_Price,
        AVG([Previous_Year_Price]) as Previous_Year_Price,
        CASE 
            WHEN AVG([Previous_Year_Price]) > 0 
            THEN ((AVG([Current_Week_Price]) - AVG([Previous_Year_Price])) / AVG([Previous_Year_Price]) * 100)
            ELSE 0 
        END as Price_Change_Percent
    FROM [dbo].[SeafoodExportAnalysis]
    WHERE [Processing_Date] = @ProcessingDate
    GROUP BY [Week];
    
END;

