"""
Quick Analysis Script for Norwegian Seafood Export Data

This script provides a streamlined way to run the analysis with minimal setup.
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

def quick_analysis():
    """Run a quick analysis of the seafood export data."""
    
    print("🐟 Quick Norwegian Seafood Export Analysis")
    print("=" * 50)
    
    # Check if sample data exists, if not create it
    sample_file = "sample_norwegian_seafood_export.xlsx"
    if not Path(sample_file).exists():
        print("Creating sample data...")
        from generate_sample_data import generate_sample_data
        generate_sample_data(years=5, output_file=sample_file)
    
    # Load data
    print("Loading data...")
    df = pd.read_excel(sample_file)
    print(f"Data loaded: {df.shape[0]} records, {df.shape[1]} columns")
    
    # Clean data
    print("Cleaning data...")
    df_clean = df.copy()
    
    # Handle missing values
    numeric_cols = df_clean.select_dtypes(include=[np.number]).columns
    for col in numeric_cols:
        df_clean[col].fillna(df_clean[col].median(), inplace=True)
    
    categorical_cols = df_clean.select_dtypes(include=['object']).columns
    for col in categorical_cols:
        df_clean[col].fillna('Unknown', inplace=True)
    
    # Convert to numeric
    df_clean['Volume (tons)'] = pd.to_numeric(df_clean['Volume (tons)'], errors='coerce')
    df_clean['Value (NOK)'] = pd.to_numeric(df_clean['Value (NOK)'], errors='coerce')
    df_clean['Year'] = pd.to_numeric(df_clean['Year'], errors='coerce')
    
    # Basic statistics
    print("\n📊 BASIC STATISTICS")
    print("-" * 30)
    total_volume = df_clean['Volume (tons)'].sum()
    total_value = df_clean['Value (NOK)'].sum()
    
    print(f"Total Export Volume: {total_volume:,.0f} tons")
    print(f"Total Export Value: {total_value:,.0f} NOK")
    print(f"Total Export Value: {total_value/1e9:.2f} billion NOK")
    
    # Yearly analysis
    print("\n📈 YEARLY ANALYSIS")
    print("-" * 30)
    yearly = df_clean.groupby('Year').agg({
        'Volume (tons)': 'sum',
        'Value (NOK)': 'sum'
    }).round(2)
    
    print(yearly)
    
    # Growth rates
    volume_growth = yearly['Volume (tons)'].pct_change() * 100
    value_growth = yearly['Value (NOK)'].pct_change() * 100
    
    print(f"\nGrowth Rates:")
    for year in yearly.index[1:]:
        print(f"{year}: Volume {volume_growth[year]:.1f}%, Value {value_growth[year]:.1f}%")
    
    # Market analysis
    print("\n🌍 TOP MARKETS")
    print("-" * 30)
    market_analysis = df_clean.groupby('Market').agg({
        'Value (NOK)': 'sum'
    }).sort_values('Value (NOK)', ascending=False)
    
    market_analysis['Share (%)'] = (market_analysis['Value (NOK)'] / market_analysis['Value (NOK)'].sum() * 100).round(2)
    
    print(market_analysis.head(10))
    
    # Species analysis
    print("\n🐟 TOP SPECIES")
    print("-" * 30)
    species_analysis = df_clean.groupby('Species').agg({
        'Value (NOK)': 'sum'
    }).sort_values('Value (NOK)', ascending=False)
    
    species_analysis['Share (%)'] = (species_analysis['Value (NOK)'] / species_analysis['Value (NOK)'].sum() * 100).round(2)
    
    print(species_analysis.head(10))
    
    # Create visualizations
    print("\n📊 CREATING VISUALIZATIONS")
    print("-" * 30)
    
    # Create output directory
    output_dir = Path("visualizations")
    output_dir.mkdir(exist_ok=True)
    
    # Set style
    plt.style.use('seaborn-v0_8')
    sns.set_palette("husl")
    
    # 1. Annual trends
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10))
    
    ax1.plot(yearly.index, yearly['Volume (tons)'], marker='o', linewidth=2)
    ax1.set_title('Export Volume by Year', fontsize=14, fontweight='bold')
    ax1.set_ylabel('Volume (tons)')
    ax1.grid(True, alpha=0.3)
    
    ax2.plot(yearly.index, yearly['Value (NOK)']/1e9, marker='s', linewidth=2, color='orange')
    ax2.set_title('Export Value by Year', fontsize=14, fontweight='bold')
    ax2.set_xlabel('Year')
    ax2.set_ylabel('Value (billion NOK)')
    ax2.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(output_dir / 'annual_trends.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # 2. Top markets pie chart
    top_markets = market_analysis.head(8)
    others = market_analysis.iloc[8:].sum()
    if others['Value (NOK)'] > 0:
        top_markets.loc['Others'] = others
    
    plt.figure(figsize=(10, 8))
    colors = plt.cm.Set3(np.linspace(0, 1, len(top_markets)))
    wedges, texts, autotexts = plt.pie(top_markets['Value (NOK)'], 
                                      labels=top_markets.index,
                                      autopct='%1.1f%%',
                                      colors=colors,
                                      startangle=90)
    
    plt.title('Top Markets by Export Value', fontsize=16, fontweight='bold')
    plt.axis('equal')
    
    for autotext in autotexts:
        autotext.set_color('white')
        autotext.set_fontweight('bold')
    
    plt.tight_layout()
    plt.savefig(output_dir / 'markets_pie.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    # 3. Top species bar chart
    top_species = species_analysis.head(10)
    
    plt.figure(figsize=(12, 6))
    bars = plt.bar(range(len(top_species)), top_species['Value (NOK)']/1e6)
    plt.title('Top 10 Species by Export Value', fontsize=14, fontweight='bold')
    plt.xlabel('Species')
    plt.ylabel('Value (Million NOK)')
    plt.xticks(range(len(top_species)), top_species.index, rotation=45, ha='right')
    
    # Add value labels on bars
    for i, bar in enumerate(bars):
        height = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2., height + height*0.01,
                f'{height:.0f}M', ha='center', va='bottom')
    
    plt.tight_layout()
    plt.savefig(output_dir / 'species_bar.png', dpi=300, bbox_inches='tight')
    plt.close()
    
    print(f"Visualizations saved in {output_dir} directory")
    
    # Key insights
    print("\n🔍 KEY INSIGHTS")
    print("-" * 30)
    latest_year = df_clean['Year'].max()
    latest_data = df_clean[df_clean['Year'] == latest_year]
    latest_value = latest_data['Value (NOK)'].sum()
    
    top_market = market_analysis.index[0]
    top_market_value = market_analysis.iloc[0]['Value (NOK)']
    
    top_species_name = species_analysis.index[0]
    top_species_value = species_analysis.iloc[0]['Value (NOK)']
    
    print(f"📊 Total Export Value: {total_value/1e9:.2f} billion NOK")
    print(f"📊 Total Export Volume: {total_volume:,.0f} tons")
    print(f"📈 {latest_year} Total Value: {latest_value/1e9:.2f} billion NOK")
    print(f"🌍 Top Market: {top_market} ({top_market_value/1e9:.2f} billion NOK)")
    print(f"🐟 Top Species: {top_species_name} ({top_species_value/1e9:.2f} billion NOK)")
    
    if len(yearly) > 1:
        latest_growth = value_growth.iloc[-1]
        print(f"📈 Latest Year Growth: {latest_growth:.2f}%")
    
    print("\n✅ Analysis completed successfully!")
    print(f"📁 Check the '{output_dir}' folder for visualizations")

if __name__ == "__main__":
    quick_analysis()
