#!/bin/bash
# Global Fishing Watch Analysis - Azure CLI Deployment Script
# Can be run in Azure Cloud Shell (Bash) or local bash with Azure CLI

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}🔄 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${CYAN}📋 $1${NC}"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --resource-group)
            RESOURCE_GROUP_NAME="$2"
            shift 2
            ;;
        --location)
            LOCATION="$2"
            shift 2
            ;;
        --data-factory)
            DATA_FACTORY_NAME="$2"
            shift 2
            ;;
        --storage-account)
            STORAGE_ACCOUNT_NAME="$2"
            shift 2
            ;;
        --sql-server)
            SQL_SERVER_NAME="$2"
            shift 2
            ;;
        --sql-database)
            SQL_DATABASE_NAME="$2"
            shift 2
            ;;
        --sql-username)
            SQL_USERNAME="$2"
            shift 2
            ;;
        --sql-password)
            SQL_PASSWORD="$2"
            shift 2
            ;;
        --gfw-api-token)
            GFW_API_TOKEN="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --resource-group      Azure Resource Group name"
            echo "  --location           Azure region (default: West Europe)"
            echo "  --data-factory       Data Factory name"
            echo "  --storage-account    Storage Account name"
            echo "  --sql-server         SQL Server name"
            echo "  --sql-database       SQL Database name"
            echo "  --sql-username       SQL admin username"
            echo "  --sql-password       SQL admin password"
            echo "  --gfw-api-token      Global Fishing Watch API token"
            exit 0
            ;;
        *)
            print_error "Unknown option $1"
            exit 1
            ;;
    esac
done

# Set default values if not provided
LOCATION=${LOCATION:-"West Europe"}
RESOURCE_GROUP_NAME=${RESOURCE_GROUP_NAME:-"fishing-analysis-rg"}
DATA_FACTORY_NAME=${DATA_FACTORY_NAME:-"fishing-adf-$RANDOM"}
STORAGE_ACCOUNT_NAME=${STORAGE_ACCOUNT_NAME:-"fishingdata$RANDOM"}
SQL_SERVER_NAME=${SQL_SERVER_NAME:-"fishing-sql-$RANDOM"}
SQL_DATABASE_NAME=${SQL_DATABASE_NAME:-"fishing-analysis-db"}
SQL_USERNAME=${SQL_USERNAME:-"fishingadmin"}
DATABRICKS_WORKSPACE_NAME=${DATABRICKS_WORKSPACE_NAME:-"$RESOURCE_GROUP_NAME-databricks"}
KEY_VAULT_NAME=${KEY_VAULT_NAME:-"$RESOURCE_GROUP_NAME-kv"}

# Validate required parameters
if [[ -z "$SQL_PASSWORD" ]]; then
    print_error "SQL password is required. Use --sql-password option."
    exit 1
fi

if [[ -z "$GFW_API_TOKEN" ]]; then
    print_error "GFW API token is required. Use --gfw-api-token option."
    exit 1
fi

echo -e "${GREEN}🚀 Starting Global Fishing Watch Analysis Deployment...${NC}"
echo "============================================================"

print_info "Deployment Configuration:"
echo "  Resource Group: $RESOURCE_GROUP_NAME"
echo "  Location: $LOCATION"
echo "  Data Factory: $DATA_FACTORY_NAME"
echo "  Storage Account: $STORAGE_ACCOUNT_NAME"
echo "  SQL Server: $SQL_SERVER_NAME"
echo "  SQL Database: $SQL_DATABASE_NAME"
echo "  Databricks Workspace: $DATABRICKS_WORKSPACE_NAME"
echo "  Key Vault: $KEY_VAULT_NAME"
echo ""

# Check if logged in to Azure
print_status "Checking Azure CLI login status..."
if ! az account show &>/dev/null; then
    print_error "Please login to Azure first using 'az login'"
    exit 1
fi

print_success "Azure CLI authentication verified"

# 1. Create Resource Group
print_status "Step 1: Creating Resource Group..."
if az group show --name "$RESOURCE_GROUP_NAME" &>/dev/null; then
    print_success "Resource Group already exists: $RESOURCE_GROUP_NAME"
else
    az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"
    print_success "Resource Group created: $RESOURCE_GROUP_NAME"
fi

# 2. Create Key Vault for storing secrets
print_status "Step 2: Creating Key Vault..."
if az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP_NAME" &>/dev/null; then
    print_success "Key Vault already exists: $KEY_VAULT_NAME"
else
    az keyvault create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$KEY_VAULT_NAME" \
        --location "$LOCATION" \
        --enabled-for-template-deployment true
    
    # Store secrets
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "SqlPassword" --value "$SQL_PASSWORD"
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "GFWApiToken" --value "$GFW_API_TOKEN"
    
    print_success "Key Vault created and secrets stored: $KEY_VAULT_NAME"
fi

# 3. Create Storage Account (Data Lake Gen2)
print_status "Step 3: Creating Storage Account..."
if az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" &>/dev/null; then
    print_success "Storage Account already exists: $STORAGE_ACCOUNT_NAME"
else
    az storage account create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$STORAGE_ACCOUNT_NAME" \
        --location "$LOCATION" \
        --sku Standard_LRS \
        --kind StorageV2 \
        --enable-hierarchical-namespace true
    
    # Get storage account key
    STORAGE_KEY=$(az storage account keys list --resource-group "$RESOURCE_GROUP_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --query "[0].value" -o tsv)
    
    # Create containers
    az storage container create --name "raw-data" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_KEY"
    az storage container create --name "processed-data" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_KEY"
    az storage container create --name "insights" --account-name "$STORAGE_ACCOUNT_NAME" --account-key "$STORAGE_KEY"
    
    print_success "Storage Account and containers created"
fi

# 4. Create SQL Server and Database
print_status "Step 4: Creating SQL Server and Database..."
if az sql server show --name "$SQL_SERVER_NAME" --resource-group "$RESOURCE_GROUP_NAME" &>/dev/null; then
    print_success "SQL Server already exists: $SQL_SERVER_NAME"
else
    az sql server create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$SQL_SERVER_NAME" \
        --location "$LOCATION" \
        --admin-user "$SQL_USERNAME" \
        --admin-password "$SQL_PASSWORD"
    
    # Configure firewall to allow Azure services
    az sql server firewall-rule create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --server "$SQL_SERVER_NAME" \
        --name "AllowAzureServices" \
        --start-ip-address 0.0.0.0 \
        --end-ip-address 0.0.0.0
    
    # Create database
    az sql db create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --server "$SQL_SERVER_NAME" \
        --name "$SQL_DATABASE_NAME" \
        --edition Basic
    
    print_success "SQL Server and Database created"
fi

# 5. Create Databricks Workspace
print_status "Step 5: Creating Databricks Workspace..."
if az databricks workspace show --name "$DATABRICKS_WORKSPACE_NAME" --resource-group "$RESOURCE_GROUP_NAME" &>/dev/null; then
    print_success "Databricks Workspace already exists: $DATABRICKS_WORKSPACE_NAME"
else
    az databricks workspace create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$DATABRICKS_WORKSPACE_NAME" \
        --location "$LOCATION" \
        --sku standard
    
    print_success "Databricks Workspace created"
fi

# 6. Create Data Factory
print_status "Step 6: Creating Data Factory..."
if az datafactory show --name "$DATA_FACTORY_NAME" --resource-group "$RESOURCE_GROUP_NAME" &>/dev/null; then
    print_success "Data Factory already exists: $DATA_FACTORY_NAME"
else
    az datafactory create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$DATA_FACTORY_NAME" \
        --location "$LOCATION"
    
    print_success "Data Factory created: $DATA_FACTORY_NAME"
fi

# 7. Deploy Data Factory Components
print_status "Step 7: Deploying Data Factory Components..."

# Get storage account key for linked services
STORAGE_KEY=$(az storage account keys list --resource-group "$RESOURCE_GROUP_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --query "[0].value" -o tsv)

print_info "  📡 Deploying Linked Services..."

# Create Azure Storage Linked Service JSON
cat > /tmp/storage-linked-service.json << EOF
{
  "name": "AzureDataLakeStorageGen2",
  "properties": {
    "type": "AzureBlobFS",
    "typeProperties": {
      "url": "https://$STORAGE_ACCOUNT_NAME.dfs.core.windows.net",
      "accountKey": {
        "type": "SecureString",
        "value": "$STORAGE_KEY"
      }
    }
  }
}
EOF

# Create SQL Linked Service JSON
CONNECTION_STRING="Server=tcp:$SQL_SERVER_NAME.database.windows.net,1433;Initial Catalog=$SQL_DATABASE_NAME;Persist Security Info=False;User ID=$SQL_USERNAME;Password=$SQL_PASSWORD;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

cat > /tmp/sql-linked-service.json << EOF
{
  "name": "AzureSqlDatabase",
  "properties": {
    "type": "AzureSqlDatabase",
    "typeProperties": {
      "connectionString": "$CONNECTION_STRING"
    }
  }
}
EOF

# Deploy linked services
az datafactory linked-service create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --factory-name "$DATA_FACTORY_NAME" \
    --name "AzureDataLakeStorageGen2" \
    --properties @/tmp/storage-linked-service.json

az datafactory linked-service create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --factory-name "$DATA_FACTORY_NAME" \
    --name "AzureSqlDatabase" \
    --properties @/tmp/sql-linked-service.json

print_success "Linked services deployed"

# 8. Create SQL Database Schema
print_status "Step 8: Setting up Database Schema..."

print_warning "Manual step required: Please run the SQL script 'create-fishing-events-tables.sql' against your database"
print_info "Connection string: Server=tcp:$SQL_SERVER_NAME.database.windows.net,1433;Database=$SQL_DATABASE_NAME;User ID=$SQL_USERNAME"

# 9. Final Summary
echo ""
print_success "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!"
echo "============================================================"
echo ""
print_info "📋 Deployment Summary:"
echo "  ✅ Resource Group: $RESOURCE_GROUP_NAME"
echo "  ✅ Key Vault: $KEY_VAULT_NAME"
echo "  ✅ Storage Account: $STORAGE_ACCOUNT_NAME"
echo "  ✅ SQL Server: $SQL_SERVER_NAME"
echo "  ✅ SQL Database: $SQL_DATABASE_NAME"
echo "  ✅ Databricks Workspace: $DATABRICKS_WORKSPACE_NAME"
echo "  ✅ Data Factory: $DATA_FACTORY_NAME"
echo ""
print_warning "🔗 Next Steps:"
echo "  1. Open Azure Data Factory Studio: https://adf.azure.com"
echo "  2. Upload Databricks notebook: scripts/databricks-fishing-events-processor.py"
echo "  3. Run SQL script: sql/create-fishing-events-tables.sql"
echo "  4. Deploy remaining pipeline components manually"
echo "  5. Test the pipeline execution"
echo ""
print_info "📊 Access URLs:"
echo "  • Data Factory: https://portal.azure.com/#@/resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.DataFactory/factories/$DATA_FACTORY_NAME"
echo "  • Databricks: https://portal.azure.com/#@/resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Databricks/workspaces/$DATABRICKS_WORKSPACE_NAME"
echo "  • SQL Database: https://portal.azure.com/#@/resource/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Sql/servers/$SQL_SERVER_NAME/databases/$SQL_DATABASE_NAME"
echo ""

# Clean up temporary files
rm -f /tmp/storage-linked-service.json /tmp/sql-linked-service.json

print_success "Deployment script completed! 🎊"
