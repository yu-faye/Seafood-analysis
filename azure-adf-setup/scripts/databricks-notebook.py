# Databricks notebook source
# MAGIC %md
# MAGIC # Norwegian Seafood Data Processing
# MAGIC 
# MAGIC This notebook processes Norwegian Seafood Council export data in Azure Databricks.

# COMMAND ----------

# MAGIC %md
# MAGIC ## Setup and Configuration

# COMMAND ----------

# Import required libraries
import pandas as pd
import numpy as np
import requests
from bs4 import BeautifulSoup
import os
from pathlib import Path
import re
from datetime import datetime
import json

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Download Function

# COMMAND ----------

def download_seafood_data():
    """Download Norwegian Seafood Council data."""
    
    base_url = "https://en.seafood.no/market-insight/statistics-archive/"
    
    # Setup session
    session = requests.Session()
    session.headers.update({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    })
    
    try:
        # Get the main page
        response = session.get(base_url, timeout=30)
        response.raise_for_status()
        
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Find Excel file links
        excel_links = []
        for link in soup.find_all('a', href=True):
            href = link['href']
            if href.lower().endswith(('.xlsx', '.xls')):
                full_url = f"https://en.seafood.no{href}" if href.startswith('/') else href
                excel_links.append(full_url)
        
        print(f"Found {len(excel_links)} Excel files")
        return excel_links
        
    except Exception as e:
        print(f"Error downloading data: {e}")
        return []

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Processing Function

# COMMAND ----------

def process_seafood_data(excel_links):
    """Process the downloaded seafood data."""
    
    all_data = []
    
    for url in excel_links:
        try:
            # Download file
            response = requests.get(url, timeout=60)
            response.raise_for_status()
            
            # Parse filename to extract week and category
            filename = url.split('/')[-1]
            week_match = re.search(r'uke-(\d+)', filename)
            category_match = re.search(r'(laks-og-orret|hvitfiskprodukter|sild-og-makrell|konvensjonelle-produkter)', filename)
            
            if week_match and category_match:
                week_num = int(week_match.group(1))
                category = category_match.group(1).replace('-', '_')
                
                # Load Excel file
                df = pd.read_excel(io=response.content, header=None)
                
                # Parse the data
                parsed_data = parse_weekly_data(df, week_num, category)
                if parsed_data is not None and not parsed_data.empty:
                    all_data.append(parsed_data)
                    print(f"Processed {filename}: {len(parsed_data)} records")
                    
        except Exception as e:
            print(f"Error processing {url}: {e}")
            continue
    
    if all_data:
        combined_df = pd.concat(all_data, ignore_index=True)
        
        # Calculate additional metrics
        combined_df['Volume_Growth_Percent'] = (
            (combined_df['Current_Week_Volume'] - combined_df['Previous_Year_Volume']) / 
            combined_df['Previous_Year_Volume'] * 100
        ).round(2)
        
        combined_df['Price_Change_Percent'] = (
            (combined_df['Current_Week_Price'] - combined_df['Previous_Year_Price']) / 
            combined_df['Previous_Year_Price'] * 100
        ).round(2)
        
        combined_df['Processing_Date'] = datetime.now()
        
        return combined_df
    else:
        return pd.DataFrame()

# COMMAND ----------

def parse_weekly_data(df, week_num, category):
    """Parse weekly data from a single file."""
    
    # Find the data section
    data_start = None
    for i, row in df.iterrows():
        if pd.notna(row.iloc[2]) and 'TOTALT' in str(row.iloc[2]):
            data_start = i
            break
    
    if data_start is None:
        return None
    
    # Extract data rows
    data_rows = []
    for i in range(data_start, len(df)):
        row = df.iloc[i]
        if pd.notna(row.iloc[2]) and row.iloc[2] != 'TOTALT':
            market = str(row.iloc[2]).strip()
            if market and market != 'nan':
                data_rows.append({
                    'Week': week_num,
                    'Category': category,
                    'Market': market,
                    'Current_Week_Volume': row.iloc[3] if pd.notna(row.iloc[3]) else 0,
                    'Current_Week_Price': row.iloc[4] if pd.notna(row.iloc[4]) else 0,
                    'Previous_Year_Volume': row.iloc[5] if pd.notna(row.iloc[5]) else 0,
                    'Previous_Year_Price': row.iloc[6] if pd.notna(row.iloc[6]) else 0,
                    'YTD_Current_Volume': row.iloc[7] if pd.notna(row.iloc[7]) else 0,
                    'YTD_Current_Price': row.iloc[8] if pd.notna(row.iloc[8]) else 0,
                    'YTD_Previous_Volume': row.iloc[9] if pd.notna(row.iloc[9]) else 0,
                    'YTD_Previous_Price': row.iloc[10] if pd.notna(row.iloc[10]) else 0,
                })
    
    if data_rows:
        df_parsed = pd.DataFrame(data_rows)
        # Convert numeric columns
        numeric_cols = [col for col in df_parsed.columns if col not in ['Week', 'Category', 'Market']]
        for col in numeric_cols:
            df_parsed[col] = pd.to_numeric(df_parsed[col], errors='coerce').fillna(0)
        return df_parsed
    
    return None

# COMMAND ----------

# MAGIC %md
# MAGIC ## Main Processing Logic

# COMMAND ----------

# Get parameters from ADF
storage_account = dbutils.widgets.get("storage_account")
container_name = dbutils.widgets.get("container_name")
output_path = dbutils.widgets.get("output_path")

print(f"Storage Account: {storage_account}")
print(f"Container: {container_name}")
print(f"Output Path: {output_path}")

# COMMAND ----------

# Download and process data
print("Starting data download...")
excel_links = download_seafood_data()

if excel_links:
    print("Processing data...")
    processed_data = process_seafood_data(excel_links)
    
    if not processed_data.empty:
        print(f"Processed {len(processed_data)} records")
        print(f"Categories: {processed_data['Category'].nunique()}")
        print(f"Markets: {processed_data['Market'].nunique()}")
        print(f"Weeks: {sorted(processed_data['Week'].unique())}")
        
        # Save to Data Lake
        output_path_full = f"/mnt/{storage_account}/{container_name}/{output_path}"
        
        # Ensure directory exists
        os.makedirs(os.path.dirname(output_path_full), exist_ok=True)
        
        # Save as CSV
        processed_data.to_csv(output_path_full, index=False)
        print(f"Data saved to: {output_path_full}")
        
        # Display sample data
        display(processed_data.head(10))
        
    else:
        print("No data processed")
else:
    print("No Excel files found")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Quality Checks

# COMMAND ----------

if not processed_data.empty:
    print("Data Quality Summary:")
    print(f"Total Records: {len(processed_data)}")
    print(f"Missing Values: {processed_data.isnull().sum().sum()}")
    print(f"Duplicate Records: {processed_data.duplicated().sum()}")
    
    # Volume statistics
    print(f"\nVolume Statistics:")
    print(f"Total Current Week Volume: {processed_data['Current_Week_Volume'].sum():,.0f} tons")
    print(f"Total Previous Year Volume: {processed_data['Previous_Year_Volume'].sum():,.0f} tons")
    print(f"Average Price: {processed_data['Current_Week_Price'].mean():.2f} NOK/kg")
    
    # Top markets
    top_markets = processed_data.groupby('Market')['Current_Week_Volume'].sum().nlargest(10)
    print(f"\nTop 10 Markets by Volume:")
    for market, volume in top_markets.items():
        print(f"  {market}: {volume:,.0f} tons")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Generate Insights

# COMMAND ----------

if not processed_data.empty:
    # Calculate key insights
    total_volume = processed_data['Current_Week_Volume'].sum()
    total_previous_volume = processed_data['Previous_Year_Volume'].sum()
    avg_price = processed_data['Current_Week_Price'].mean()
    avg_previous_price = processed_data['Previous_Year_Price'].mean()
    
    volume_growth = ((total_volume - total_previous_volume) / total_previous_volume * 100) if total_previous_volume > 0 else 0
    price_change = ((avg_price - avg_previous_price) / avg_previous_price * 100) if avg_previous_price > 0 else 0
    
    insights = {
        "total_volume": total_volume,
        "total_previous_volume": total_previous_volume,
        "volume_growth_percent": volume_growth,
        "avg_price": avg_price,
        "avg_previous_price": avg_previous_price,
        "price_change_percent": price_change,
        "processing_date": datetime.now().isoformat(),
        "total_records": len(processed_data),
        "categories": processed_data['Category'].nunique(),
        "markets": processed_data['Market'].nunique(),
        "weeks": len(processed_data['Week'].unique())
    }
    
    print("Key Insights:")
    print(json.dumps(insights, indent=2))
    
    # Save insights to Data Lake
    insights_path = f"/mnt/{storage_account}/{container_name}/insights/seafood_insights_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    os.makedirs(os.path.dirname(insights_path), exist_ok=True)
    
    with open(insights_path, 'w') as f:
        json.dump(insights, f, indent=2)
    
    print(f"Insights saved to: {insights_path}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Completion

# COMMAND ----------

print("Norwegian Seafood data processing completed successfully!")
print(f"Processed {len(processed_data) if not processed_data.empty else 0} records")
print(f"Data saved to: /mnt/{storage_account}/{container_name}/{output_path}")

