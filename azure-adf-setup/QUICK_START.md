# 🚀 Quick Start Guide - Norwegian Seafood Analysis on Azure Data Factory

## Prerequisites Checklist

- [ ] Azure subscription with admin access
- [ ] Azure CLI installed (`az --version`)
- [ ] PowerShell 5.1 or later
- [ ] Git installed

## Step 1: Login to Azure

```bash
az login
az account set --subscription "Your-Subscription-Name"
```

## Step 2: Clone and Navigate

```bash
git clone <your-repo>
cd azure-seafood/azure-adf-setup
```

## Step 3: Deploy Everything

```powershell
# Set your parameters
$ResourceGroupName = "seafood-analysis-rg"
$Location = "West Europe"
$DataFactoryName = "seafood-adf-$(Get-Random)"
$StorageAccountName = "seafooddatalake$(Get-Random)"
$SqlServerName = "seafood-sql-$(Get-Random)"
$SqlDatabaseName = "seafood-analysis-db"
$SqlUsername = "seafoodadmin"
$SqlPassword = "YourSecurePassword123!"

# Run deployment
.\deployment\deploy.ps1 -ResourceGroupName $ResourceGroupName -Location $Location -DataFactoryName $DataFactoryName -StorageAccountName $StorageAccountName -SqlServerName $SqlServerName -SqlDatabaseName $SqlDatabaseName -SqlUsername $SqlUsername -SqlPassword $SqlPassword
```

## Step 4: Create Database Tables

1. Open Azure Portal
2. Navigate to your SQL Database
3. Open Query Editor
4. Copy and paste the contents of `sql/create-tables.sql`
5. Execute the script

## Step 5: Upload Databricks Notebook

1. Open Azure Databricks workspace
2. Create a new notebook
3. Copy the contents of `scripts/databricks-notebook.py`
4. Save the notebook as `/seafood-analysis/parse-seafood-data`

## Step 6: Test the Pipeline

1. Open Azure Data Factory Studio
2. Navigate to your pipeline
3. Click "Debug" to test the pipeline
4. Monitor the execution

## Step 7: Configure Power BI

1. Open Power BI Desktop
2. Connect to your Azure SQL Database
3. Use the configuration from `power-bi/seafood-dashboard.pbix`
4. Publish to Power BI Service

## Expected Results

After successful deployment, you should have:

- ✅ **Data Factory Pipeline** running daily at 6:00 AM UTC
- ✅ **Data Lake Storage** with raw and processed data
- ✅ **SQL Database** with analysis tables
- ✅ **Power BI Dashboard** with visualizations
- ✅ **Monitoring & Alerts** configured

## Troubleshooting

### Common Issues:

1. **Permission Errors**: Ensure you have Contributor access to the resource group
2. **Storage Account Name**: Must be globally unique
3. **SQL Server Name**: Must be globally unique
4. **Password Requirements**: SQL password must meet complexity requirements

### Getting Help:

- Check the main README.md for detailed documentation
- Review Azure Data Factory logs in the portal
- Use Azure Monitor for performance insights

## Next Steps

1. **Customize**: Modify the pipeline for your specific needs
2. **Scale**: Add more data sources or processing steps
3. **Monitor**: Set up additional alerts and dashboards
4. **Optimize**: Tune performance based on usage patterns

---

**🎉 Congratulations!** Your Norwegian Seafood analysis is now running on Azure Data Factory!

