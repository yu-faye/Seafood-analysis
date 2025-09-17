# Azure Seafood Fishing Analysis Platform

## Overview

This project implements an automated data pipeline for collecting and analyzing global fishing events data using Azure Data Factory (ADF) and Azure SQL Database. The system fetches port visit events from the Global Fishing Watch API and stores them for investment analysis and business intelligence.

## Architecture

### Components

- **Azure Data Factory (ADF)**: Orchestrates the data pipeline
- **Azure SQL Database**: Stores processed fishing events data
- **Azure Key Vault**: Securely manages API tokens and database credentials
- **Global Fishing Watch API**: External data source for fishing events

### Data Flow

```
Global Fishing Watch API → Azure Data Factory → Azure SQL Database
```

## Features

### Data Collection
- **Automated Data Fetching**: Daily collection of fishing events data
- **Historical Data**: Collects data from 2023-01-01 to 2025-01-01
- **High-Quality Data**: Filters for high-confidence events (confidence levels 3-4)
- **Port Visit Events**: Focuses on vessel port visit activities

### Data Processing
- **Real-time Processing**: Data is processed and stored immediately upon collection
- **Data Validation**: Ensures data integrity and completeness
- **Automatic Table Creation**: Creates database tables if they don't exist
- **Error Handling**: Robust error handling and retry mechanisms

### Data Storage
- **Structured Storage**: Data stored in normalized SQL tables
- **Historical Tracking**: Maintains complete historical record
- **Scalable Design**: Supports large volumes of fishing events data

## Technical Implementation

### Pipeline Components

1. **GetGfwApiToken**: Retrieves API authentication token from Azure Key Vault
2. **FetchFishingEventsFromGFW**: Calls Global Fishing Watch API to fetch events data
3. **LoadFishingEventsToSQL**: Transforms and loads data into Azure SQL Database

### Data Schema

The system stores the following data fields:

| Field | Type | Description |
|-------|------|-------------|
| EventId | NVARCHAR(100) | Unique event identifier |
| EventType | NVARCHAR(50) | Type of fishing event |
| VesselId | NVARCHAR(100) | Unique vessel identifier |
| PortId | NVARCHAR(50) | Port identifier |
| PortName | NVARCHAR(200) | Port name |
| StartTime | DATETIME2 | Event start timestamp |
| DurationHours | DECIMAL(18,4) | Event duration in hours |

### API Configuration

- **Endpoint**: Global Fishing Watch API v3/events/stats
- **Authentication**: Bearer token authentication
- **Data Source**: public-global-port-visits-events:latest
- **Time Range**: 2023-01-01 to 2025-01-01
- **Confidence Levels**: 3-4 (high confidence events)
- **Time Interval**: Daily aggregation

## Setup and Deployment

### Prerequisites

- Azure subscription
- Azure Data Factory instance
- Azure SQL Database
- Azure Key Vault
- Global Fishing Watch API access token

### Configuration Files

- `pipeline/FishingEventsProcessingPipeline.json`: Main ADF pipeline configuration
- `dataset/GFWEventsAPI.json`: API dataset configuration
- `dataset/FishingEventsTable.json`: SQL table dataset configuration
- `linkedService/`: Linked service configurations for various Azure resources

### Deployment Steps

1. **Configure Azure Resources**:
   - Set up Azure Data Factory
   - Create Azure SQL Database
   - Configure Azure Key Vault with required secrets

2. **Deploy Pipeline**:
   - Upload pipeline configuration to ADF
   - Configure linked services
   - Set up datasets

3. **Configure Triggers**:
   - Set up daily trigger for automated execution
   - Configure execution schedule (recommended: daily at 6 AM UTC)

4. **Test and Validate**:
   - Run pipeline manually to verify functionality
   - Check data quality in SQL Database
   - Monitor pipeline execution logs

## Data Analysis

### Available Queries

The system provides comprehensive SQL queries for data analysis:

- **Data Overview**: Total events, unique vessels, unique ports
- **Port Statistics**: Visit counts and duration analysis by port
- **Vessel Activity**: Activity patterns and frequency analysis
- **Trend Analysis**: Daily activity trends and patterns
- **Duration Analysis**: Port stay duration statistics

### Sample Analysis Queries

```sql
-- Data Overview
SELECT 
    COUNT(*) as TotalEvents,
    COUNT(DISTINCT VesselId) as UniqueVessels,
    COUNT(DISTINCT PortId) as UniquePorts
FROM [dbo].[FishingEvents];

-- Top 10 Busiest Ports
SELECT TOP 10
    PortName,
    COUNT(*) as VisitCount,
    COUNT(DISTINCT VesselId) as UniqueVessels
FROM [dbo].[FishingEvents]
GROUP BY PortName
ORDER BY VisitCount DESC;
```

## Monitoring and Maintenance

### Pipeline Monitoring

- **Execution Status**: Monitor pipeline runs in ADF
- **Data Quality**: Regular validation of data completeness
- **Performance Metrics**: Track execution times and resource usage
- **Error Handling**: Automated retry and alert mechanisms

### Data Quality Assurance

- **Data Validation**: Ensures all required fields are populated
- **Duplicate Detection**: Identifies and handles duplicate events
- **Data Freshness**: Monitors data recency and completeness
- **Error Logging**: Comprehensive error tracking and reporting

## Business Value

### Investment Analysis

- **Port Activity Trends**: Identify high-activity ports for investment opportunities
- **Vessel Behavior Patterns**: Understand vessel movement patterns
- **Market Analysis**: Analyze fishing industry trends and patterns
- **Risk Assessment**: Evaluate port and vessel activity risks

### Data Insights

- **Operational Intelligence**: Real-time visibility into fishing activities
- **Historical Analysis**: Long-term trend analysis and forecasting
- **Performance Metrics**: Key performance indicators for fishing operations
- **Compliance Monitoring**: Track and monitor fishing activities

## Security

### Data Protection

- **Encrypted Storage**: All data encrypted at rest and in transit
- **Access Control**: Role-based access control for data access
- **Audit Logging**: Comprehensive audit trails for all operations
- **Secure Authentication**: Azure Key Vault for credential management

### Compliance

- **Data Privacy**: Adherence to data privacy regulations
- **Data Retention**: Configurable data retention policies
- **Access Logging**: Complete audit trail of data access
- **Security Monitoring**: Continuous security monitoring and alerting

## Future Enhancements

### Planned Features

- **Real-time Analytics**: Real-time data processing and analysis
- **Machine Learning**: Predictive analytics and anomaly detection
- **Geographic Analysis**: Spatial analysis and mapping capabilities
- **API Integration**: Additional data source integrations

### Scalability

- **Horizontal Scaling**: Support for increased data volumes
- **Performance Optimization**: Continuous performance improvements
- **Cost Optimization**: Efficient resource utilization
- **Global Deployment**: Multi-region deployment capabilities

## Support and Documentation

### Troubleshooting

- **Common Issues**: Documentation of common problems and solutions
- **Error Codes**: Comprehensive error code reference
- **Performance Tuning**: Guidelines for optimal performance
- **Best Practices**: Recommended practices for system operation

### Contact Information

For technical support and questions, please refer to the Azure Data Factory documentation or contact the development team.

---

**Last Updated**: September 2025  
**Version**: 1.0  
**Status**: Production Ready
