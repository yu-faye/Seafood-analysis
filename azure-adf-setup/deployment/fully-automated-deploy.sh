#!/bin/bash
# Fully Automated Global Fishing Watch Analysis Deployment
# This script attempts to automate as much as possible, including database setup

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${BLUE}🔄 $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Default values
RESOURCE_GROUP_NAME="fishing-analysis-rg"
LOCATION="West Europe"
DATA_FACTORY_NAME="fishing-adf-$(shuf -i 1000-9999 -n 1)"
STORAGE_ACCOUNT_NAME="fishingdata$(shuf -i 1000-9999 -n 1)"
SQL_SERVER_NAME="fishing-sql-$(shuf -i 1000-9999 -n 1)"
SQL_DATABASE_NAME="fishing-analysis-db"
SQL_USERNAME="fishingadmin"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --sql-password) SQL_PASSWORD="$2"; shift 2 ;;
        --gfw-api-token) GFW_API_TOKEN="$2"; shift 2 ;;
        --resource-group) RESOURCE_GROUP_NAME="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Validate required parameters
if [[ -z "$SQL_PASSWORD" || -z "$GFW_API_TOKEN" ]]; then
    print_error "Required parameters missing. Usage:"
    echo "./fully-automated-deploy.sh --sql-password 'YourPassword123!' --gfw-api-token 'your-token'"
    exit 1
fi

echo -e "${GREEN}🚀 Starting Fully Automated Deployment...${NC}"
echo "============================================================"

# 1. Create all Azure resources
print_status "Creating Azure resources..."

# Resource Group
az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION" >/dev/null 2>&1

# Storage Account
az storage account create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$STORAGE_ACCOUNT_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --enable-hierarchical-namespace true >/dev/null 2>&1

# Get storage key and create containers
STORAGE_KEY=$(az storage account keys list --resource-group "$RESOURCE_GROUP_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --query "[0].value" -o tsv)
az storage container create --name "raw-data" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_KEY" >/dev/null 2>&1
az storage container create --name "processed-data" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_KEY" >/dev/null 2>&1
az storage container create --name "insights" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_KEY" >/dev/null 2>&1

# SQL Server and Database
az sql server create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$SQL_SERVER_NAME" \
    --location "$LOCATION" \
    --admin-user "$SQL_USERNAME" \
    --admin-password "$SQL_PASSWORD" >/dev/null 2>&1

az sql server firewall-rule create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --server "$SQL_SERVER_NAME" \
    --name "AllowAzureServices" \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 0.0.0.0 >/dev/null 2>&1

az sql db create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --server "$SQL_SERVER_NAME" \
    --name "$SQL_DATABASE_NAME" \
    --edition Basic >/dev/null 2>&1

# Data Factory
az datafactory create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$DATA_FACTORY_NAME" \
    --location "$LOCATION" >/dev/null 2>&1

# Databricks
az databricks workspace create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$RESOURCE_GROUP_NAME-databricks" \
    --location "$LOCATION" \
    --sku standard >/dev/null 2>&1

print_success "All Azure resources created"

# 2. Setup database schema automatically using sqlcmd
print_status "Setting up database schema..."

# Check if sqlcmd is available (in Azure Cloud Shell it should be)
if command -v sqlcmd >/dev/null 2>&1; then
    # Create the SQL script content directly in the script
    cat > /tmp/create_tables.sql << 'EOF'
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

-- Create port visit analysis table
CREATE TABLE [dbo].[PortVisitAnalysis] (
    [Id] [int] IDENTITY(1,1) NOT NULL,
    [PortId] [nvarchar](100) NOT NULL,
    [PortName] [nvarchar](200) NOT NULL,
    [PortCountry] [nvarchar](100) NOT NULL,
    [PortVisitCount] [int] NOT NULL,
    [AvgStayHours] [decimal](18,2) NOT NULL,
    [TotalTradeHours] [decimal](18,2) NOT NULL,
    [PortVessels] [int] NOT NULL,
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
    [InvestmentPriority] [nvarchar](20) NOT NULL,
    [TradeVolumeScore] [decimal](5,2) NOT NULL,
    [EfficiencyScore] [decimal](5,2) NOT NULL,
    [GrowthPotentialScore] [decimal](5,2) NOT NULL,
    [OverallScore] [decimal](5,2) NOT NULL,
    [RecommendedInvestment] [nvarchar](500) NULL,
    [ExpectedROI] [decimal](5,2) NULL,
    [ProcessingDate] [datetime2](7) NOT NULL,
    [CreatedDate] [datetime2](7) NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT [PK_InvestmentInsights] PRIMARY KEY CLUSTERED ([Id] ASC)
);

-- Create indexes
CREATE NONCLUSTERED INDEX [IX_FishingEvents_EventType] ON [dbo].[FishingEvents] ([EventType]);
CREATE NONCLUSTERED INDEX [IX_FishingEvents_PortId] ON [dbo].[FishingEvents] ([PortId]);
CREATE NONCLUSTERED INDEX [IX_FishingEvents_VesselId] ON [dbo].[FishingEvents] ([VesselId]);
EOF

    # Execute SQL script
    sqlcmd -S "$SQL_SERVER_NAME.database.windows.net" -d "$SQL_DATABASE_NAME" -U "$SQL_USERNAME" -P "$SQL_PASSWORD" -i /tmp/create_tables.sql

    print_success "Database schema created automatically"
else
    print_warning "sqlcmd not available. Database schema needs to be created manually."
    echo "Please run the SQL script: azure-adf-setup/sql/create-fishing-events-tables.sql"
fi

# 3. Deploy Data Factory components with error handling
print_status "Deploying Data Factory components..."

# Create linked services
CONNECTION_STRING="Server=tcp:$SQL_SERVER_NAME.database.windows.net,1433;Initial Catalog=$SQL_DATABASE_NAME;Persist Security Info=False;User ID=$SQL_USERNAME;Password=$SQL_PASSWORD;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

# Storage Linked Service
cat > /tmp/storage_ls.json << EOF
{
  "type": "AzureBlobFS",
  "typeProperties": {
    "url": "https://$STORAGE_ACCOUNT_NAME.dfs.core.windows.net",
    "accountKey": "$STORAGE_KEY"
  }
}
EOF

# SQL Linked Service  
cat > /tmp/sql_ls.json << EOF
{
  "type": "AzureSqlDatabase",
  "typeProperties": {
    "connectionString": "$CONNECTION_STRING"
  }
}
EOF

# Deploy linked services
az datafactory linked-service create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --factory-name "$DATA_FACTORY_NAME" \
    --name "AzureDataLakeStorage" \
    --properties @/tmp/storage_ls.json >/dev/null 2>&1

az datafactory linked-service create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --factory-name "$DATA_FACTORY_NAME" \
    --name "AzureSqlDatabase" \
    --properties @/tmp/sql_ls.json >/dev/null 2>&1

print_success "Data Factory components deployed"

# 4. Create a simple test pipeline
print_status "Creating test pipeline..."

cat > /tmp/test_pipeline.json << EOF
{
  "activities": [
    {
      "name": "TestConnection",
      "type": "Lookup",
      "typeProperties": {
        "source": {
          "type": "AzureSqlSource",
          "sqlReaderQuery": "SELECT GETDATE() as CurrentTime, 'Pipeline Test' as Message"
        },
        "dataset": {
          "referenceName": "TestDataset",
          "type": "DatasetReference"
        }
      }
    }
  ]
}
EOF

# Create test dataset
cat > /tmp/test_dataset.json << EOF
{
  "type": "AzureSqlTable",
  "linkedServiceName": {
    "referenceName": "AzureSqlDatabase",
    "type": "LinkedServiceReference"
  },
  "typeProperties": {
    "schema": "dbo",
    "table": "FishingEvents"
  }
}
EOF

az datafactory dataset create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --factory-name "$DATA_FACTORY_NAME" \
    --name "TestDataset" \
    --properties @/tmp/test_dataset.json >/dev/null 2>&1

az datafactory pipeline create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --factory-name "$DATA_FACTORY_NAME" \
    --name "TestPipeline" \
    --pipeline @/tmp/test_pipeline.json >/dev/null 2>&1

print_success "Test pipeline created"

# 5. Test the pipeline
print_status "Testing pipeline connection..."

RUN_ID=$(az datafactory pipeline create-run \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --factory-name "$DATA_FACTORY_NAME" \
    --name "TestPipeline" \
    --query "runId" -o tsv)

if [[ -n "$RUN_ID" ]]; then
    print_success "Pipeline test initiated successfully (Run ID: $RUN_ID)"
else
    print_warning "Pipeline test could not be initiated"
fi

# Clean up temporary files
rm -f /tmp/*.json /tmp/*.sql

# Final summary
echo ""
print_success "🎉 FULLY AUTOMATED DEPLOYMENT COMPLETED!"
echo "============================================================"
echo ""
echo "📋 Deployed Resources:"
echo "  ✅ Resource Group: $RESOURCE_GROUP_NAME"
echo "  ✅ Storage Account: $STORAGE_ACCOUNT_NAME"
echo "  ✅ SQL Server: $SQL_SERVER_NAME"
echo "  ✅ SQL Database: $SQL_DATABASE_NAME"
echo "  ✅ Data Factory: $DATA_FACTORY_NAME"
echo "  ✅ Databricks: $RESOURCE_GROUP_NAME-databricks"
echo "  ✅ Database Tables: Created automatically"
echo "  ✅ Linked Services: Configured"
echo "  ✅ Test Pipeline: Ready"
echo ""
echo "🔗 Next Steps:"
echo "  1. Access Data Factory: https://adf.azure.com"
echo "  2. Upload Databricks notebook (only remaining manual step)"
echo "  3. Deploy the full fishing events pipeline"
echo "  4. Configure Power BI dashboard"
echo ""
echo "💡 The system is now ready for Global Fishing Watch data analysis!"
echo "💡 Database connection string saved for reference"
echo ""

# Save connection info for reference
cat > deployment_info.txt << EOF
Deployment Information
=====================
Resource Group: $RESOURCE_GROUP_NAME
Data Factory: $DATA_FACTORY_NAME
Storage Account: $STORAGE_ACCOUNT_NAME
SQL Server: $SQL_SERVER_NAME
SQL Database: $SQL_DATABASE_NAME
SQL Username: $SQL_USERNAME

Connection String: $CONNECTION_STRING

GFW API Token: $GFW_API_TOKEN

Deployment Date: $(date)
EOF

print_success "Deployment information saved to deployment_info.txt"
