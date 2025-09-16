#!/bin/bash
# Step-by-Step Global Fishing Watch Analysis Deployment
# This script breaks down deployment into manageable steps with error checking

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() { echo -e "${BLUE}📋 Step $1: $2${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_info() { echo -e "${CYAN}💡 $1${NC}"; }

# Function to check if command succeeded
check_result() {
    if [ $? -eq 0 ]; then
        print_success "$1 completed successfully"
    else
        print_error "$1 failed"
        print_info "You can continue with the next step or fix this issue manually"
        read -p "Press Enter to continue or Ctrl+C to exit..."
    fi
}

# Default values (you can modify these)
RESOURCE_GROUP_NAME="fishing-analysis-rg"
LOCATION="West Europe"
DATA_FACTORY_NAME="fishing-adf-$(shuf -i 1000-9999 -n 1)"
STORAGE_ACCOUNT_NAME="fishingdata$(shuf -i 1000-9999 -n 1)"
SQL_SERVER_NAME="fishing-sql-$(shuf -i 1000-9999 -n 1)"
SQL_DATABASE_NAME="fishing-analysis-db"
SQL_USERNAME="fishingadmin"

echo -e "${GREEN}🚀 Step-by-Step Azure Deployment for Global Fishing Watch Analysis${NC}"
echo "=================================================================="
echo ""

# Get required parameters
if [[ -z "$SQL_PASSWORD" ]]; then
    echo -n "Enter SQL Server password (must be complex): "
    read -s SQL_PASSWORD
    echo ""
fi

if [[ -z "$GFW_API_TOKEN" ]]; then
    echo -n "Enter your Global Fishing Watch API token: "
    read -s GFW_API_TOKEN
    echo ""
fi

echo ""
print_info "Configuration:"
echo "  Resource Group: $RESOURCE_GROUP_NAME"
echo "  Location: $LOCATION"
echo "  Data Factory: $DATA_FACTORY_NAME"
echo "  Storage Account: $STORAGE_ACCOUNT_NAME"
echo "  SQL Server: $SQL_SERVER_NAME"
echo ""

read -p "Press Enter to start deployment or Ctrl+C to cancel..."
echo ""

# Step 1: Check Azure CLI login
print_step "1" "Checking Azure CLI authentication"
if az account show >/dev/null 2>&1; then
    SUBSCRIPTION=$(az account show --query name -o tsv)
    print_success "Logged in to Azure subscription: $SUBSCRIPTION"
else
    print_error "Not logged in to Azure"
    print_info "Please run: az login"
    exit 1
fi
echo ""

# Step 2: Create Resource Group
print_step "2" "Creating Resource Group"
az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION" >/dev/null 2>&1
check_result "Resource Group creation"
echo ""

# Step 3: Create Storage Account
print_step "3" "Creating Storage Account (Data Lake Gen2)"
echo "This may take 2-3 minutes..."
az storage account create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$STORAGE_ACCOUNT_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --enable-hierarchical-namespace true >/dev/null 2>&1
check_result "Storage Account creation"

# Create containers
print_info "Creating storage containers..."
STORAGE_KEY=$(az storage account keys list --resource-group "$RESOURCE_GROUP_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --query "[0].value" -o tsv 2>/dev/null)
if [[ -n "$STORAGE_KEY" ]]; then
    az storage container create --name "raw-data" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_KEY" >/dev/null 2>&1
    az storage container create --name "processed-data" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_KEY" >/dev/null 2>&1
    az storage container create --name "insights" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_KEY" >/dev/null 2>&1
    print_success "Storage containers created"
else
    print_warning "Could not get storage key. Containers may need to be created manually"
fi
echo ""

# Step 4: Create SQL Server
print_step "4" "Creating SQL Server"
az sql server create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$SQL_SERVER_NAME" \
    --location "$LOCATION" \
    --admin-user "$SQL_USERNAME" \
    --admin-password "$SQL_PASSWORD" >/dev/null 2>&1
check_result "SQL Server creation"

# Configure firewall
print_info "Configuring SQL Server firewall..."
az sql server firewall-rule create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --server "$SQL_SERVER_NAME" \
    --name "AllowAzureServices" \
    --start-ip-address 0.0.0.0 \
    --end-ip-address 0.0.0.0 >/dev/null 2>&1
check_result "SQL Server firewall configuration"
echo ""

# Step 5: Create SQL Database
print_step "5" "Creating SQL Database"
az sql db create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --server "$SQL_SERVER_NAME" \
    --name "$SQL_DATABASE_NAME" \
    --edition Basic >/dev/null 2>&1
check_result "SQL Database creation"
echo ""

# Step 6: Create Data Factory
print_step "6" "Creating Azure Data Factory"
az datafactory create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$DATA_FACTORY_NAME" \
    --location "$LOCATION" >/dev/null 2>&1
check_result "Data Factory creation"
echo ""

# Step 7: Create Databricks (Optional)
print_step "7" "Creating Databricks Workspace (Optional)"
echo "This step is optional and may take 5-10 minutes..."
read -p "Do you want to create Databricks workspace? (y/n): " create_databricks

if [[ $create_databricks == "y" || $create_databricks == "Y" ]]; then
    az databricks workspace create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$RESOURCE_GROUP_NAME-databricks" \
        --location "$LOCATION" \
        --sku standard >/dev/null 2>&1
    check_result "Databricks workspace creation"
else
    print_info "Skipping Databricks workspace creation"
fi
echo ""

# Step 8: Basic Data Factory Configuration
print_step "8" "Configuring Data Factory Linked Services"

# Create connection string
CONNECTION_STRING="Server=tcp:$SQL_SERVER_NAME.database.windows.net,1433;Initial Catalog=$SQL_DATABASE_NAME;Persist Security Info=False;User ID=$SQL_USERNAME;Password=$SQL_PASSWORD;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

# Create temporary linked service files
cat > /tmp/storage_linked_service.json << EOF
{
  "type": "AzureBlobFS",
  "typeProperties": {
    "url": "https://$STORAGE_ACCOUNT_NAME.dfs.core.windows.net",
    "accountKey": "$STORAGE_KEY"
  }
}
EOF

cat > /tmp/sql_linked_service.json << EOF
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
    --properties @/tmp/storage_linked_service.json >/dev/null 2>&1
check_result "Storage linked service creation"

az datafactory linked-service create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --factory-name "$DATA_FACTORY_NAME" \
    --name "AzureSqlDatabase" \
    --properties @/tmp/sql_linked_service.json >/dev/null 2>&1
check_result "SQL linked service creation"
echo ""

# Step 9: Database Schema Setup
print_step "9" "Database Schema Setup"
print_warning "Database tables need to be created manually"
print_info "Please follow these steps:"
echo "  1. Go to Azure Portal > SQL Database > Query Editor"
echo "  2. Login with username: $SQL_USERNAME"
echo "  3. Copy and run the SQL script: azure-adf-setup/sql/create-fishing-events-tables.sql"
echo "  4. Or use SQL Server Management Studio with connection string above"
echo ""
read -p "Press Enter after you've set up the database schema..."
echo ""

# Step 10: Summary and Next Steps
print_step "10" "Deployment Summary"
echo ""
print_success "🎉 Basic Azure Infrastructure Deployed Successfully!"
echo ""
echo "📋 Created Resources:"
echo "  ✅ Resource Group: $RESOURCE_GROUP_NAME"
echo "  ✅ Storage Account: $STORAGE_ACCOUNT_NAME"
echo "  ✅ SQL Server: $SQL_SERVER_NAME"
echo "  ✅ SQL Database: $SQL_DATABASE_NAME"
echo "  ✅ Data Factory: $DATA_FACTORY_NAME"
if [[ $create_databricks == "y" || $create_databricks == "Y" ]]; then
    echo "  ✅ Databricks: $RESOURCE_GROUP_NAME-databricks"
fi
echo ""

echo "🔗 Access URLs:"
echo "  • Data Factory: https://adf.azure.com"
echo "  • Azure Portal: https://portal.azure.com"
echo ""

echo "📝 Next Manual Steps:"
echo "  1. ✅ Azure infrastructure (completed by this script)"
echo "  2. 🔲 Create database tables (manual - see step 9 above)"
echo "  3. 🔲 Upload Databricks notebook: scripts/databricks-fishing-events-processor.py"
echo "  4. 🔲 Deploy fishing events pipeline: pipelines/fishing-events-pipeline.json"
echo "  5. 🔲 Configure Power BI dashboard"
echo ""

# Save deployment info
cat > deployment_info.txt << EOF
Azure Deployment Information
===========================
Date: $(date)
Resource Group: $RESOURCE_GROUP_NAME
Data Factory: $DATA_FACTORY_NAME
Storage Account: $STORAGE_ACCOUNT_NAME
SQL Server: $SQL_SERVER_NAME
SQL Database: $SQL_DATABASE_NAME
SQL Username: $SQL_USERNAME

Connection String:
$CONNECTION_STRING

GFW API Token: $GFW_API_TOKEN

Next Steps:
1. Create database tables using: azure-adf-setup/sql/create-fishing-events-tables.sql
2. Upload Databricks notebook
3. Deploy ADF pipelines
4. Test the system
EOF

print_success "Deployment information saved to: deployment_info.txt"

# Clean up temporary files
rm -f /tmp/storage_linked_service.json /tmp/sql_linked_service.json

echo ""
print_success "🎊 Deployment completed! Check deployment_info.txt for details."
