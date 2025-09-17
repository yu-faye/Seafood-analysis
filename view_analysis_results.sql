-- =============================================
-- Global Fishing Watch Port Visit Events Analysis Queries
-- =============================================

-- 1. Data Overview
SELECT 
    COUNT(*) as TotalEvents,
    COUNT(DISTINCT VesselId) as UniqueVessels,
    COUNT(DISTINCT PortId) as UniquePorts,
    MIN(StartTime) as EarliestEventTime,
    MAX(StartTime) as LatestEventTime
FROM [dbo].[FishingEvents];

-- 2. Port Visit Statistics
SELECT 
    PortName,
    PortId,
    COUNT(*) as VisitCount,
    COUNT(DISTINCT VesselId) as UniqueVessels,
    AVG(DurationHours) as AvgDurationHours
FROM [dbo].[FishingEvents]
GROUP BY PortName, PortId
ORDER BY VisitCount DESC;

-- 3. Vessel Activity Statistics
SELECT 
    VesselId,
    COUNT(*) as PortVisits,
    COUNT(DISTINCT PortId) as UniquePortsVisited,
    SUM(DurationHours) as TotalDurationHours
FROM [dbo].[FishingEvents]
GROUP BY VesselId
ORDER BY PortVisits DESC;

-- 4. Daily Trend Analysis
SELECT 
    CAST(StartTime as DATE) as EventDate,
    COUNT(*) as DailyEvents,
    COUNT(DISTINCT VesselId) as DailyActiveVessels,
    COUNT(DISTINCT PortId) as DailyActivePorts
FROM [dbo].[FishingEvents]
GROUP BY CAST(StartTime as DATE)
ORDER BY EventDate DESC;

-- 5. Port Duration Analysis
SELECT 
    PortName,
    AVG(DurationHours) as AvgDuration,
    MIN(DurationHours) as MinDuration,
    MAX(DurationHours) as MaxDuration,
    STDEV(DurationHours) as DurationStdDev
FROM [dbo].[FishingEvents]
WHERE DurationHours IS NOT NULL
GROUP BY PortName
ORDER BY AvgDuration DESC;

-- 6. Top 10 Busiest Ports (Last 7 Days)
SELECT TOP 10
    PortName,
    COUNT(*) as VisitCount,
    COUNT(DISTINCT VesselId) as UniqueVessels
FROM [dbo].[FishingEvents]
WHERE StartTime >= DATEADD(day, -7, GETDATE())
GROUP BY PortName
ORDER BY VisitCount DESC;

-- 7. Vessel Activity Frequency Analysis
SELECT 
    CASE 
        WHEN VisitCount = 1 THEN 'Single Visit'
        WHEN VisitCount BETWEEN 2 AND 5 THEN 'Low Frequency (2-5 visits)'
        WHEN VisitCount BETWEEN 6 AND 20 THEN 'Medium Frequency (6-20 visits)'
        ELSE 'High Frequency (20+ visits)'
    END as FrequencyCategory,
    COUNT(*) as VesselCount
FROM (
    SELECT VesselId, COUNT(*) as VisitCount
    FROM [dbo].[FishingEvents]
    GROUP BY VesselId
) as VesselStats
GROUP BY 
    CASE 
        WHEN VisitCount = 1 THEN 'Single Visit'
        WHEN VisitCount BETWEEN 2 AND 5 THEN 'Low Frequency (2-5 visits)'
        WHEN VisitCount BETWEEN 6 AND 20 THEN 'Medium Frequency (6-20 visits)'
        ELSE 'High Frequency (20+ visits)'
    END
ORDER BY VesselCount DESC;
