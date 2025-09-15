# 🏗️ Azure Account Setup Guide for Norwegian Seafood Analysis

## Prerequisites
- Azure subscription (free trial or paid)
- Admin access to the subscription
- Azure CLI installed on your machine

## Step 1: Login to Azure

```bash
# Install Azure CLI if not already installed
# Windows: https://aka.ms/installazurecliwindows
# Mac: brew install azure-cli
# Linux: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login to Azure
az login

# List your subscriptions
az account list --output table

# Set your active subscription
az account set --subscription "Your-Subscription-Name"
```

## Step 2: Create Resource Group

```bash
# Create a resource group
az group create --name "seafood-analysis-rg" --location "West Europe"

# Verify the resource group was created
az group show --name "seafood-analysis-rg"
```

## Step 3: Create Azure Data Factory

```bash
# Create Azure Data Factory
az datafactory create --resource-group "seafood-analysis-rg" --name "seafood-adf" --location "West Europe"

# Verify ADF was created
az datafactory show --resource-group "seafood-analysis-rg" --name "seafood-adf"
```

## Step 4: Create Storage Account (Data Lake Gen2)

```bash
# Create storage account
az storage account create --name "seafooddatalake" --resource-group "seafood-analysis-rg" --location "West Europe" --sku Standard_LRS --kind StorageV2 --enable-hierarchical-namespace true

# Get storage account key
az storage account keys list --resource-group "seafood-analysis-rg" --account-name "seafooddatalake"

# Create containers
az storage container create --name "raw-data" --account-name "seafooddatalake"
az storage container create --name "processed-data" --account-name "seafooddatalake"
az storage container create --name "insights" --account-name "seafooddatalake"
```

## Step 5: Create SQL Database

```bash
# Create SQL Server
az sql server create --resource-group "seafood-analysis-rg" --name "seafood-sql-server" --location "West Europe" --admin-user "seafoodadmin" --admin-password "YourSecurePassword123!"

# Create SQL Database
az sql db create --resource-group "seafood-analysis-rg" --server "seafood-sql-server" --name "seafood-analysis-db" --service-objective Basic

# Configure firewall to allow Azure services
az sql server firewall-rule create --resource-group "seafood-analysis-rg" --server "seafood-sql-server" --name "AllowAzureServices" --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0
```

## Step 6: Create Databricks Workspace (Optional but Recommended)

```bash
# Create Databricks workspace
az databricks workspace create --resource-group "seafood-analysis-rg" --name "seafood-databricks" --location "West Europe" --sku standard
```

## Step 7: Verify All Resources

```bash
# List all resources in your resource group
az resource list --resource-group "seafood-analysis-rg" --output table

# Check specific resources
az datafactory show --resource-group "seafood-analysis-rg" --name "seafood-adf"
az storage account show --resource-group "seafood-analysis-rg" --name "seafooddatalake"
az sql server show --resource-group "seafood-analysis-rg" --name "seafood-sql-server"
```

## Step 8: Get Connection Information

```bash
# Get storage account connection string
az storage account show-connection-string --resource-group "seafood-analysis-rg" --name "seafooddatalake"

# Get SQL Server connection string
echo "Server=tcp:seafood-sql-server.database.windows.net,1433;Initial Catalog=seafood-analysis-db;Persist Security Info=False;User ID=seafoodadmin;Password=YourSecurePassword123!;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
```

## Step 9: Access Azure Data Factory Studio

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to your Data Factory: `seafood-adf`
3. Click "Open Azure Data Factory Studio"
4. You should see the ADF interface

## Step 10: Next Steps

After setting up the basic Azure resources, you can:

1. **Deploy the ADF Pipeline**: Use the deployment script
2. **Create Database Tables**: Run the SQL script
3. **Upload Databricks Notebook**: For advanced processing
4. **Configure Power BI**: Connect to your SQL database

## Cost Estimation

### Free Tier (First 12 months)
- **Azure Data Factory**: 5 pipelines free
- **Storage Account**: 5GB free
- **SQL Database**: 1 database free (Basic tier)
- **Databricks**: 14-day free trial

### Pay-as-you-go (After free tier)
- **Data Factory**: ~$1-5/month for small workloads
- **Storage**: ~$0.02/GB/month
- **SQL Database**: ~$5-15/month (Basic tier)
- **Databricks**: ~$10-50/month (Standard tier)

## Troubleshooting

### Common Issues:

1. **"Resource name not available"**: Try adding random numbers to make names unique
2. **"Insufficient permissions"**: Ensure you have Contributor access
3. **"Location not available"**: Try a different Azure region

### Getting Help:

```bash
# Check your Azure CLI version
az --version

# Check your login status
az account show

# Get help with specific commands
az datafactory create --help
```

## Security Best Practices

1. **Use Key Vault**: Store passwords in Azure Key Vault
2. **Enable MFA**: Enable multi-factor authentication
3. **Use Managed Identity**: For service-to-service authentication
4. **Network Security**: Configure VNets and NSGs
5. **Audit Logging**: Enable activity logs

## Ready for Deployment!

Once you've completed these steps, you're ready to deploy the Norwegian Seafood analysis pipeline using the deployment script:

```powershell
.\deployment\deploy.ps1 -ResourceGroupName "seafood-analysis-rg" -DataFactoryName "seafood-adf" -StorageAccountName "seafooddatalake" -SqlServerName "seafood-sql-server" -SqlDatabaseName "seafood-analysis-db" -SqlUsername "seafoodadmin" -SqlPassword "YourSecurePassword123!"
```

---

**🎉 Congratulations!** Your Azure environment is now ready for the Norwegian Seafood analysis solution!

