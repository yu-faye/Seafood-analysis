"""
Norwegian Seafood Council Export Statistics Analysis

This script performs a comprehensive analysis of Norwegian seafood export data,
including data cleaning, statistical analysis, and visualization.
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import requests
import os
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

# Set up plotting style
plt.style.use('seaborn-v0_8')
sns.set_palette("husl")

class NorwegianSeafoodAnalysis:
    """Main class for Norwegian Seafood export data analysis."""
    
    def __init__(self, data_url=None, data_file=None):
        """
        Initialize the analysis class.
        
        Args:
            data_url (str): URL to download the Excel file
            data_file (str): Path to local Excel file
        """
        self.data_url = data_url or "https://en.seafood.no/market-insight/norwegian-trade/"
        self.data_file = data_file
        self.df = None
        self.cleaned_df = None
        
    def download_data(self, filename="norwegian_seafood_export.xlsx"):
        """
        Download the Norwegian Seafood Council export data.
        
        Args:
            filename (str): Name for the downloaded file
        """
        print("Downloading Norwegian Seafood Council export data...")
        try:
            # Note: This is a placeholder URL - the actual download URL needs to be determined
            # from the website structure
            response = requests.get(self.data_url)
            response.raise_for_status()
            
            with open(filename, 'wb') as f:
                f.write(response.content)
            
            self.data_file = filename
            print(f"Data downloaded successfully as {filename}")
            
        except Exception as e:
            print(f"Error downloading data: {e}")
            print("Please manually download the Excel file from https://en.seafood.no/market-insight/norwegian-trade/")
            print("and place it in the current directory as 'norwegian_seafood_export.xlsx'")
    
    def load_data(self, sheet_name=None):
        """
        Load data from Excel file into pandas DataFrame.
        
        Args:
            sheet_name (str): Name of the Excel sheet to load
        """
        if not self.data_file or not os.path.exists(self.data_file):
            print("Data file not found. Please ensure the Excel file is available.")
            return
        
        print("Loading data from Excel file...")
        try:
            # Try to load the Excel file
            if sheet_name:
                self.df = pd.read_excel(self.data_file, sheet_name=sheet_name)
            else:
                # Try to load the first sheet
                excel_file = pd.ExcelFile(self.data_file)
                self.df = pd.read_excel(self.data_file, sheet_name=excel_file.sheet_names[0])
            
            print(f"Data loaded successfully. Shape: {self.df.shape}")
            print(f"Columns: {list(self.df.columns)}")
            
        except Exception as e:
            print(f"Error loading data: {e}")
    
    def clean_data(self):
        """
        Clean the dataset by handling missing values and converting data types.
        """
        if self.df is None:
            print("No data loaded. Please load data first.")
            return
        
        print("Cleaning data...")
        self.cleaned_df = self.df.copy()
        
        # Display basic info about the dataset
        print("\nDataset Info:")
        print(f"Shape: {self.cleaned_df.shape}")
        print(f"Missing values per column:")
        print(self.cleaned_df.isnull().sum())
        
        # Handle missing values
        # For numeric columns, fill with 0 or median
        numeric_columns = self.cleaned_df.select_dtypes(include=[np.number]).columns
        for col in numeric_columns:
            if self.cleaned_df[col].isnull().any():
                median_val = self.cleaned_df[col].median()
                self.cleaned_df[col].fillna(median_val, inplace=True)
        
        # For categorical columns, fill with 'Unknown'
        categorical_columns = self.cleaned_df.select_dtypes(include=['object']).columns
        for col in categorical_columns:
            if self.cleaned_df[col].isnull().any():
                self.cleaned_df[col].fillna('Unknown', inplace=True)
        
        # Convert data types
        # Ensure Volume and Value are numeric
        if 'Volume (tons)' in self.cleaned_df.columns:
            self.cleaned_df['Volume (tons)'] = pd.to_numeric(
                self.cleaned_df['Volume (tons)'], errors='coerce'
            )
        
        if 'Value (NOK)' in self.cleaned_df.columns:
            self.cleaned_df['Value (NOK)'] = pd.to_numeric(
                self.cleaned_df['Value (NOK)'], errors='coerce'
            )
        
        # Convert Year to datetime if it exists
        if 'Year' in self.cleaned_df.columns:
            self.cleaned_df['Year'] = pd.to_numeric(self.cleaned_df['Year'], errors='coerce')
        
        print("Data cleaning completed.")
        print(f"Cleaned dataset shape: {self.cleaned_df.shape}")
    
    def calculate_summary_statistics(self):
        """
        Calculate summary statistics by year.
        """
        if self.cleaned_df is None:
            print("No cleaned data available. Please clean data first.")
            return
        
        print("\n=== SUMMARY STATISTICS BY YEAR ===")
        
        # Group by year and calculate totals
        yearly_stats = self.cleaned_df.groupby('Year').agg({
            'Volume (tons)': 'sum',
            'Value (NOK)': 'sum'
        }).round(2)
        
        print(yearly_stats)
        
        # Calculate overall totals
        total_volume = self.cleaned_df['Volume (tons)'].sum()
        total_value = self.cleaned_df['Value (NOK)'].sum()
        
        print(f"\nTotal Export Volume: {total_volume:,.2f} tons")
        print(f"Total Export Value: {total_value:,.2f} NOK")
        print(f"Total Export Value: {total_value/1e9:.2f} billion NOK")
        
        return yearly_stats
    
    def calculate_growth_rates(self):
        """
        Calculate year-over-year growth rates.
        """
        if self.cleaned_df is None:
            print("No cleaned data available. Please clean data first.")
            return
        
        print("\n=== YEAR-OVER-YEAR GROWTH RATES ===")
        
        # Calculate yearly totals
        yearly_totals = self.cleaned_df.groupby('Year').agg({
            'Volume (tons)': 'sum',
            'Value (NOK)': 'sum'
        })
        
        # Calculate growth rates
        volume_growth = yearly_totals['Volume (tons)'].pct_change() * 100
        value_growth = yearly_totals['Value (NOK)'].pct_change() * 100
        
        growth_df = pd.DataFrame({
            'Volume Growth (%)': volume_growth.round(2),
            'Value Growth (%)': value_growth.round(2)
        })
        
        print(growth_df)
        
        return growth_df
    
    def analyze_market_shares(self):
        """
        Analyze market shares by grouping by Market.
        """
        if self.cleaned_df is None:
            print("No cleaned data available. Please clean data first.")
            return
        
        print("\n=== MARKET SHARE ANALYSIS ===")
        
        # Calculate market shares
        market_analysis = self.cleaned_df.groupby('Market').agg({
            'Volume (tons)': 'sum',
            'Value (NOK)': 'sum'
        }).round(2)
        
        # Calculate percentages
        market_analysis['Volume Share (%)'] = (
            market_analysis['Volume (tons)'] / market_analysis['Volume (tons)'].sum() * 100
        ).round(2)
        
        market_analysis['Value Share (%)'] = (
            market_analysis['Value (NOK)'] / market_analysis['Value (NOK)'].sum() * 100
        ).round(2)
        
        # Sort by value share
        market_analysis = market_analysis.sort_values('Value Share (%)', ascending=False)
        
        print(market_analysis)
        
        return market_analysis
    
    def analyze_species_comparison(self):
        """
        Analyze species and product form comparisons.
        """
        if self.cleaned_df is None:
            print("No cleaned data available. Please clean data first.")
            return
        
        print("\n=== SPECIES COMPARISON ANALYSIS ===")
        
        # Group by Species and Product Form
        species_analysis = self.cleaned_df.groupby(['Species', 'Product Form']).agg({
            'Volume (tons)': 'sum',
            'Value (NOK)': 'sum'
        }).round(2)
        
        # Sort by value
        species_analysis = species_analysis.sort_values('Value (NOK)', ascending=False)
        
        print(species_analysis.head(20))  # Show top 20 combinations
        
        return species_analysis
    
    def create_visualizations(self):
        """
        Create various visualizations for the analysis.
        """
        if self.cleaned_df is None:
            print("No cleaned data available. Please clean data first.")
            return
        
        print("\n=== CREATING VISUALIZATIONS ===")
        
        # Create output directory for visualizations
        output_dir = Path("visualizations")
        output_dir.mkdir(exist_ok=True)
        
        # 1. Annual total exports line plot
        self._create_annual_exports_plot(output_dir)
        
        # 2. Top markets pie chart
        self._create_market_pie_chart(output_dir)
        
        # 3. Species contributions stacked bar chart
        self._create_species_stacked_bar(output_dir)
        
        # 4. Growth rates visualization
        self._create_growth_rates_plot(output_dir)
        
        print(f"Visualizations saved in {output_dir} directory")
    
    def _create_annual_exports_plot(self, output_dir):
        """Create line plot for annual total exports."""
        yearly_totals = self.cleaned_df.groupby('Year').agg({
            'Volume (tons)': 'sum',
            'Value (NOK)': 'sum'
        })
        
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 10))
        
        # Volume plot
        ax1.plot(yearly_totals.index, yearly_totals['Volume (tons)'], 
                marker='o', linewidth=2, markersize=6)
        ax1.set_title('Norwegian Seafood Export Volume by Year', fontsize=14, fontweight='bold')
        ax1.set_xlabel('Year')
        ax1.set_ylabel('Volume (tons)')
        ax1.grid(True, alpha=0.3)
        
        # Value plot
        ax2.plot(yearly_totals.index, yearly_totals['Value (NOK)']/1e9, 
                marker='s', linewidth=2, markersize=6, color='orange')
        ax2.set_title('Norwegian Seafood Export Value by Year', fontsize=14, fontweight='bold')
        ax2.set_xlabel('Year')
        ax2.set_ylabel('Value (billion NOK)')
        ax2.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(output_dir / 'annual_exports_trends.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def _create_market_pie_chart(self, output_dir):
        """Create pie chart for top markets."""
        market_shares = self.cleaned_df.groupby('Market')['Value (NOK)'].sum().sort_values(ascending=False)
        
        # Take top 10 markets
        top_markets = market_shares.head(10)
        others = market_shares.iloc[10:].sum()
        
        if others > 0:
            top_markets['Others'] = others
        
        plt.figure(figsize=(12, 8))
        colors = plt.cm.Set3(np.linspace(0, 1, len(top_markets)))
        
        wedges, texts, autotexts = plt.pie(top_markets.values, 
                                          labels=top_markets.index,
                                          autopct='%1.1f%%',
                                          colors=colors,
                                          startangle=90)
        
        plt.title('Top Markets by Export Value', fontsize=16, fontweight='bold')
        plt.axis('equal')
        
        # Improve text readability
        for autotext in autotexts:
            autotext.set_color('white')
            autotext.set_fontweight('bold')
        
        plt.tight_layout()
        plt.savefig(output_dir / 'top_markets_pie_chart.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def _create_species_stacked_bar(self, output_dir):
        """Create stacked bar chart for species contributions."""
        # Get top species by value
        top_species = self.cleaned_df.groupby('Species')['Value (NOK)'].sum().nlargest(10).index
        
        # Filter data for top species
        species_data = self.cleaned_df[self.cleaned_df['Species'].isin(top_species)]
        
        # Create pivot table for stacked bar chart
        pivot_data = species_data.groupby(['Species', 'Product Form'])['Value (NOK)'].sum().unstack(fill_value=0)
        
        # Plot stacked bar chart
        fig, ax = plt.subplots(figsize=(14, 8))
        pivot_data.plot(kind='bar', stacked=True, ax=ax, colormap='tab20')
        
        ax.set_title('Top Species by Export Value (Stacked by Product Form)', 
                    fontsize=14, fontweight='bold')
        ax.set_xlabel('Species')
        ax.set_ylabel('Value (NOK)')
        ax.legend(title='Product Form', bbox_to_anchor=(1.05, 1), loc='upper left')
        ax.tick_params(axis='x', rotation=45)
        
        plt.tight_layout()
        plt.savefig(output_dir / 'species_stacked_bar.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def _create_growth_rates_plot(self, output_dir):
        """Create growth rates visualization."""
        yearly_totals = self.cleaned_df.groupby('Year').agg({
            'Volume (tons)': 'sum',
            'Value (NOK)': 'sum'
        })
        
        volume_growth = yearly_totals['Volume (tons)'].pct_change() * 100
        value_growth = yearly_totals['Value (NOK)'].pct_change() * 100
        
        fig, ax = plt.subplots(figsize=(12, 6))
        
        x = yearly_totals.index[1:]  # Skip first year (no growth rate)
        
        ax.bar(x - 0.2, volume_growth.iloc[1:], width=0.4, label='Volume Growth (%)', alpha=0.8)
        ax.bar(x + 0.2, value_growth.iloc[1:], width=0.4, label='Value Growth (%)', alpha=0.8)
        
        ax.set_title('Year-over-Year Growth Rates', fontsize=14, fontweight='bold')
        ax.set_xlabel('Year')
        ax.set_ylabel('Growth Rate (%)')
        ax.legend()
        ax.grid(True, alpha=0.3)
        ax.axhline(y=0, color='black', linestyle='-', alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(output_dir / 'growth_rates.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def generate_insights(self):
        """
        Generate key insights from the analysis.
        """
        if self.cleaned_df is None:
            print("No cleaned data available. Please clean data first.")
            return
        
        print("\n=== KEY INSIGHTS ===")
        
        # Calculate key metrics
        total_value = self.cleaned_df['Value (NOK)'].sum()
        total_volume = self.cleaned_df['Volume (tons)'].sum()
        
        # Get latest year data
        latest_year = self.cleaned_df['Year'].max()
        latest_year_data = self.cleaned_df[self.cleaned_df['Year'] == latest_year]
        latest_year_value = latest_year_data['Value (NOK)'].sum()
        
        # Top market
        top_market = self.cleaned_df.groupby('Market')['Value (NOK)'].sum().idxmax()
        top_market_value = self.cleaned_df.groupby('Market')['Value (NOK)'].sum().max()
        
        # Top species
        top_species = self.cleaned_df.groupby('Species')['Value (NOK)'].sum().idxmax()
        top_species_value = self.cleaned_df.groupby('Species')['Value (NOK)'].sum().max()
        
        print(f"📊 Total Export Value: {total_value/1e9:.2f} billion NOK")
        print(f"📊 Total Export Volume: {total_volume:,.0f} tons")
        print(f"📈 {latest_year} Total Value: {latest_year_value/1e9:.2f} billion NOK")
        print(f"🌍 Top Market: {top_market} ({top_market_value/1e9:.2f} billion NOK)")
        print(f"🐟 Top Species: {top_species} ({top_species_value/1e9:.2f} billion NOK)")
        
        # Growth analysis
        yearly_totals = self.cleaned_df.groupby('Year')['Value (NOK)'].sum()
        if len(yearly_totals) > 1:
            latest_growth = ((yearly_totals.iloc[-1] - yearly_totals.iloc[-2]) / yearly_totals.iloc[-2] * 100)
            print(f"📈 Latest Year Growth: {latest_growth:.2f}%")
    
    def run_complete_analysis(self):
        """
        Run the complete analysis pipeline.
        """
        print("🚀 Starting Norwegian Seafood Export Analysis...")
        
        # Check for existing data files
        if not self.data_file or not os.path.exists(self.data_file):
            # Look for downloaded data
            if os.path.exists("norwegian_seafood_export.xlsx"):
                self.data_file = "norwegian_seafood_export.xlsx"
                print(f"Using existing data file: {self.data_file}")
            else:
                print("No data file found. Please ensure data is available.")
                return
        
        # Load and clean data
        self.load_data()
        if self.df is not None:
            self.clean_data()
            
            # Run all analyses
            self.calculate_summary_statistics()
            self.calculate_growth_rates()
            self.analyze_market_shares()
            self.analyze_species_comparison()
            self.create_visualizations()
            self.generate_insights()
            
            print("\n✅ Analysis completed successfully!")
        else:
            print("❌ Analysis failed - no data available")


def main():
    """Main function to run the analysis."""
    # Initialize the analysis
    analysis = NorwegianSeafoodAnalysis()
    
    # Run complete analysis
    analysis.run_complete_analysis()


if __name__ == "__main__":
    main()
