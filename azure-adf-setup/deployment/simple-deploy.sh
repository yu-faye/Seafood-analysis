#!/bin/bash
# Simple and Safe Azure Deployment
# This script focuses on core resources with minimal error potential

echo "🚀 Simple Azure Deployment for Global Fishing Watch Analysis"
echo "============================================================"

# Check if logged in
if ! az account show >/dev/null 2>&1; then
    echo "❌ Please login first: az login"
    exit 1
fi

# Get user input
read -p "Enter Resource Group name (default: fishing-rg): " RG_NAME
RG_NAME=${RG_NAME:-"fishing-rg"}

read -p "Enter SQL password (must be complex): " -s SQL_PASS
echo ""

read -p "Enter GFW API token: " -s GFW_TOKEN
echo ""

# Generate unique names
RANDOM_ID=$(shuf -i 1000-9999 -n 1)
STORAGE_NAME="fishingdata$RANDOM_ID"
SQL_SERVER_NAME="fishing-sql-$RANDOM_ID"
ADF_NAME="fishing-adf-$RANDOM_ID"

echo ""
echo "Creating resources with names:"
echo "  Resource Group: $RG_NAME"
echo "  Storage: $STORAGE_NAME"
echo "  SQL Server: $SQL_SERVER_NAME"
echo "  Data Factory: $ADF_NAME"
echo ""

# Create resources one by one with error checking
echo "1. Creating Resource Group..."
if az group create --name "$RG_NAME" --location "West Europe" >/dev/null; then
    echo "✅ Resource Group created"
else
    echo "❌ Resource Group creation failed"
    exit 1
fi

echo "2. Creating Storage Account..."
if az storage account create \
    --resource-group "$RG_NAME" \
    --name "$STORAGE_NAME" \
    --location "West Europe" \
    --sku Standard_LRS \
    --kind StorageV2 >/dev/null; then
    echo "✅ Storage Account created"
else
    echo "❌ Storage Account creation failed"
fi

echo "3. Creating SQL Server..."
if az sql server create \
    --resource-group "$RG_NAME" \
    --name "$SQL_SERVER_NAME" \
    --location "West Europe" \
    --admin-user "fishingadmin" \
    --admin-password "$SQL_PASS" >/dev/null; then
    echo "✅ SQL Server created"
    
    # Add firewall rule
    az sql server firewall-rule create \
        --resource-group "$RG_NAME" \
        --server "$SQL_SERVER_NAME" \
        --name "AllowAzure" \
        --start-ip-address 0.0.0.0 \
        --end-ip-address 0.0.0.0 >/dev/null
    
    # Create database
    if az sql db create \
        --resource-group "$RG_NAME" \
        --server "$SQL_SERVER_NAME" \
        --name "fishing-db" \
        --edition Basic >/dev/null; then
        echo "✅ SQL Database created"
    else
        echo "⚠️  SQL Database creation failed"
    fi
else
    echo "❌ SQL Server creation failed"
fi

echo "4. Creating Data Factory..."
if az datafactory create \
    --resource-group "$RG_NAME" \
    --name "$ADF_NAME" \
    --location "West Europe" >/dev/null; then
    echo "✅ Data Factory created"
else
    echo "❌ Data Factory creation failed"
fi

echo ""
echo "🎉 Basic deployment completed!"
echo ""
echo "📋 Your resources:"
echo "  Resource Group: $RG_NAME"
echo "  Storage Account: $STORAGE_NAME"
echo "  SQL Server: $SQL_SERVER_NAME"
echo "  Database: fishing-db"
echo "  Data Factory: $ADF_NAME"
echo ""
echo "🔗 Next steps:"
echo "  1. Go to Azure Portal: https://portal.azure.com"
echo "  2. Find your Data Factory: $ADF_NAME"
echo "  3. Open Data Factory Studio"
echo "  4. Manually import the pipeline files"
echo ""

# Save info
cat > simple_deployment_info.txt << EOF
Simple Deployment Results
========================
Date: $(date)
Resource Group: $RG_NAME
Storage Account: $STORAGE_NAME
SQL Server: $SQL_SERVER_NAME
SQL Database: fishing-db
Data Factory: $ADF_NAME
SQL Username: fishingadmin

Connection String:
Server=tcp:$SQL_SERVER_NAME.database.windows.net,1433;Initial Catalog=fishing-db;User ID=fishingadmin;Password=$SQL_PASS;Encrypt=true;

GFW API Token: $GFW_TOKEN
EOF

echo "💾 Info saved to: simple_deployment_info.txt"
