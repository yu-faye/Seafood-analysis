"""
Real Norwegian Seafood Council Data Analysis

This script analyzes the actual data downloaded from the Norwegian Seafood Council
statistics archive, which contains weekly export statistics.
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

class RealSeafoodAnalysis:
    """Analysis class for real Norwegian Seafood Council data."""
    
    def __init__(self, data_file="norwegian_seafood_export.xlsx"):
        self.data_file = data_file
        self.df = None
        self.cleaned_df = None
        
    def load_and_parse_data(self):
        """Load and parse the real Norwegian Seafood Council data."""
        print("🐟 Loading Real Norwegian Seafood Council Data")
        print("=" * 50)
        
        # Load the raw data
        self.df = pd.read_excel(self.data_file, header=None)
        print(f"Raw data shape: {self.df.shape}")
        
        # Parse the data structure
        self._parse_weekly_statistics()
        
    def _parse_weekly_statistics(self):
        """Parse the weekly statistics format."""
        print("Parsing weekly statistics data...")
        
        # Find the data section (skip headers and metadata)
        data_start = None
        for i, row in self.df.iterrows():
            if pd.notna(row.iloc[2]) and 'TOTALT' in str(row.iloc[2]):
                data_start = i
                break
        
        if data_start is None:
            print("Could not find data section")
            return
        
        # Extract the data rows
        data_rows = []
        for i in range(data_start, len(self.df)):
            row = self.df.iloc[i]
            if pd.notna(row.iloc[2]) and row.iloc[2] != 'TOTALT':
                # This is a market row
                market = str(row.iloc[2]).strip()
                if market and market != 'nan':
                    data_rows.append({
                        'Market': market,
                        'Week_36_2025_Volume': row.iloc[3] if pd.notna(row.iloc[3]) else 0,
                        'Week_36_2025_Price': row.iloc[4] if pd.notna(row.iloc[4]) else 0,
                        'Week_36_2024_Volume': row.iloc[5] if pd.notna(row.iloc[5]) else 0,
                        'Week_36_2024_Price': row.iloc[6] if pd.notna(row.iloc[6]) else 0,
                        'YTD_2025_Volume': row.iloc[7] if pd.notna(row.iloc[7]) else 0,
                        'YTD_2025_Price': row.iloc[8] if pd.notna(row.iloc[8]) else 0,
                        'YTD_2024_Volume': row.iloc[9] if pd.notna(row.iloc[9]) else 0,
                        'YTD_2024_Price': row.iloc[10] if pd.notna(row.iloc[10]) else 0,
                    })
        
        self.cleaned_df = pd.DataFrame(data_rows)
        
        # Convert numeric columns
        numeric_cols = [col for col in self.cleaned_df.columns if col != 'Market']
        for col in numeric_cols:
            self.cleaned_df[col] = pd.to_numeric(self.cleaned_df[col], errors='coerce').fillna(0)
        
        print(f"Parsed data shape: {self.cleaned_df.shape}")
        print(f"Markets: {len(self.cleaned_df)}")
        
    def analyze_weekly_data(self):
        """Analyze the weekly statistics data."""
        if self.cleaned_df is None:
            print("No data available for analysis")
            return
        
        print("\n📊 WEEKLY EXPORT ANALYSIS")
        print("=" * 40)
        
        # Week 36, 2025 vs 2024 comparison
        print("\n🔄 Week 36 Comparison (2025 vs 2024)")
        print("-" * 40)
        
        # Volume comparison
        vol_2025 = self.cleaned_df['Week_36_2025_Volume'].sum()
        vol_2024 = self.cleaned_df['Week_36_2024_Volume'].sum()
        vol_change = ((vol_2025 - vol_2024) / vol_2024 * 100) if vol_2024 > 0 else 0
        
        print(f"Week 36 Volume 2025: {vol_2025:,.0f} tons")
        print(f"Week 36 Volume 2024: {vol_2024:,.0f} tons")
        print(f"Volume Change: {vol_change:+.1f}%")
        
        # Price comparison
        price_2025 = self.cleaned_df['Week_36_2025_Price'].mean()
        price_2024 = self.cleaned_df['Week_36_2024_Price'].mean()
        price_change = ((price_2025 - price_2024) / price_2024 * 100) if price_2024 > 0 else 0
        
        print(f"Week 36 Avg Price 2025: {price_2025:.2f} NOK/kg")
        print(f"Week 36 Avg Price 2024: {price_2024:.2f} NOK/kg")
        print(f"Price Change: {price_change:+.1f}%")
        
        # YTD comparison
        print("\n📈 Year-to-Date Comparison (2025 vs 2024)")
        print("-" * 40)
        
        ytd_vol_2025 = self.cleaned_df['YTD_2025_Volume'].sum()
        ytd_vol_2024 = self.cleaned_df['YTD_2024_Volume'].sum()
        ytd_vol_change = ((ytd_vol_2025 - ytd_vol_2024) / ytd_vol_2024 * 100) if ytd_vol_2024 > 0 else 0
        
        print(f"YTD Volume 2025: {ytd_vol_2025:,.0f} tons")
        print(f"YTD Volume 2024: {ytd_vol_2024:,.0f} tons")
        print(f"YTD Volume Change: {ytd_vol_change:+.1f}%")
        
        ytd_price_2025 = self.cleaned_df['YTD_2025_Price'].mean()
        ytd_price_2024 = self.cleaned_df['YTD_2024_Price'].mean()
        ytd_price_change = ((ytd_price_2025 - ytd_price_2024) / ytd_price_2024 * 100) if ytd_price_2024 > 0 else 0
        
        print(f"YTD Avg Price 2025: {ytd_price_2025:.2f} NOK/kg")
        print(f"YTD Avg Price 2024: {ytd_price_2024:.2f} NOK/kg")
        print(f"YTD Price Change: {ytd_price_change:+.1f}%")
        
    def analyze_market_performance(self):
        """Analyze market performance."""
        if self.cleaned_df is None:
            return
        
        print("\n🌍 MARKET PERFORMANCE ANALYSIS")
        print("=" * 40)
        
        # Top markets by volume (Week 36, 2025)
        print("\n📊 Top Markets by Volume (Week 36, 2025)")
        print("-" * 40)
        top_volume = self.cleaned_df.nlargest(10, 'Week_36_2025_Volume')[
            ['Market', 'Week_36_2025_Volume', 'Week_36_2025_Price']
        ].round(2)
        print(top_volume.to_string(index=False))
        
        # Top markets by price (Week 36, 2025)
        print("\n💰 Top Markets by Price (Week 36, 2025)")
        print("-" * 40)
        top_price = self.cleaned_df.nlargest(10, 'Week_36_2025_Price')[
            ['Market', 'Week_36_2025_Volume', 'Week_36_2025_Price']
        ].round(2)
        print(top_price.to_string(index=False))
        
        # Market growth analysis
        print("\n📈 Market Growth Analysis (Week 36, 2025 vs 2024)")
        print("-" * 40)
        self.cleaned_df['Volume_Growth_%'] = (
            (self.cleaned_df['Week_36_2025_Volume'] - self.cleaned_df['Week_36_2024_Volume']) / 
            self.cleaned_df['Week_36_2024_Volume'] * 100
        ).round(2)
        
        growth_analysis = self.cleaned_df[
            ['Market', 'Week_36_2025_Volume', 'Week_36_2024_Volume', 'Volume_Growth_%']
        ].sort_values('Volume_Growth_%', ascending=False)
        
        print(growth_analysis.head(10).to_string(index=False))
        
    def create_visualizations(self):
        """Create visualizations for the real data."""
        if self.cleaned_df is None:
            return
        
        print("\n📊 CREATING VISUALIZATIONS")
        print("=" * 40)
        
        # Create output directory
        output_dir = Path("visualizations")
        output_dir.mkdir(exist_ok=True)
        
        # Set style
        plt.style.use('seaborn-v0_8')
        sns.set_palette("husl")
        
        # 1. Top markets by volume (Week 36, 2025)
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 8))
        
        top_10_volume = self.cleaned_df.nlargest(10, 'Week_36_2025_Volume')
        
        ax1.barh(range(len(top_10_volume)), top_10_volume['Week_36_2025_Volume'])
        ax1.set_yticks(range(len(top_10_volume)))
        ax1.set_yticklabels(top_10_volume['Market'], fontsize=10)
        ax1.set_xlabel('Volume (tons)')
        ax1.set_title('Top 10 Markets by Volume (Week 36, 2025)', fontsize=14, fontweight='bold')
        ax1.grid(True, alpha=0.3)
        
        # 2. Price comparison
        top_10_price = self.cleaned_df.nlargest(10, 'Week_36_2025_Price')
        
        ax2.barh(range(len(top_10_price)), top_10_price['Week_36_2025_Price'])
        ax2.set_yticks(range(len(top_10_price)))
        ax2.set_yticklabels(top_10_price['Market'], fontsize=10)
        ax2.set_xlabel('Price (NOK/kg)')
        ax2.set_title('Top 10 Markets by Price (Week 36, 2025)', fontsize=14, fontweight='bold')
        ax2.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(output_dir / 'weekly_market_analysis.png', dpi=300, bbox_inches='tight')
        plt.close()
        
        # 3. Volume comparison chart
        plt.figure(figsize=(14, 8))
        
        # Prepare data for comparison
        comparison_data = self.cleaned_df.nlargest(15, 'Week_36_2025_Volume')
        
        x = np.arange(len(comparison_data))
        width = 0.35
        
        plt.bar(x - width/2, comparison_data['Week_36_2024_Volume'], width, 
                label='Week 36, 2024', alpha=0.8)
        plt.bar(x + width/2, comparison_data['Week_36_2025_Volume'], width, 
                label='Week 36, 2025', alpha=0.8)
        
        plt.xlabel('Markets')
        plt.ylabel('Volume (tons)')
        plt.title('Volume Comparison: Week 36, 2024 vs 2025', fontsize=14, fontweight='bold')
        plt.xticks(x, comparison_data['Market'], rotation=45, ha='right')
        plt.legend()
        plt.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(output_dir / 'volume_comparison.png', dpi=300, bbox_inches='tight')
        plt.close()
        
        # 4. Price comparison chart
        plt.figure(figsize=(14, 8))
        
        plt.bar(x - width/2, comparison_data['Week_36_2024_Price'], width, 
                label='Week 36, 2024', alpha=0.8)
        plt.bar(x + width/2, comparison_data['Week_36_2025_Price'], width, 
                label='Week 36, 2025', alpha=0.8)
        
        plt.xlabel('Markets')
        plt.ylabel('Price (NOK/kg)')
        plt.title('Price Comparison: Week 36, 2024 vs 2025', fontsize=14, fontweight='bold')
        plt.xticks(x, comparison_data['Market'], rotation=45, ha='right')
        plt.legend()
        plt.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(output_dir / 'price_comparison.png', dpi=300, bbox_inches='tight')
        plt.close()
        
        print(f"Visualizations saved in {output_dir} directory")
        
    def generate_insights(self):
        """Generate key insights from the real data."""
        if self.cleaned_df is None:
            return
        
        print("\n🔍 KEY INSIGHTS")
        print("=" * 40)
        
        # Calculate key metrics
        total_vol_2025 = self.cleaned_df['Week_36_2025_Volume'].sum()
        total_vol_2024 = self.cleaned_df['Week_36_2024_Volume'].sum()
        avg_price_2025 = self.cleaned_df['Week_36_2025_Price'].mean()
        avg_price_2024 = self.cleaned_df['Week_36_2024_Price'].mean()
        
        # Top market
        top_market = self.cleaned_df.loc[self.cleaned_df['Week_36_2025_Volume'].idxmax()]
        
        # Highest price market
        highest_price_market = self.cleaned_df.loc[self.cleaned_df['Week_36_2025_Price'].idxmax()]
        
        print(f"📊 Week 36, 2025 Total Volume: {total_vol_2025:,.0f} tons")
        print(f"📊 Week 36, 2024 Total Volume: {total_vol_2024:,.0f} tons")
        print(f"📈 Volume Change: {((total_vol_2025 - total_vol_2024) / total_vol_2024 * 100):+.1f}%")
        print(f"💰 Average Price 2025: {avg_price_2025:.2f} NOK/kg")
        print(f"💰 Average Price 2024: {avg_price_2024:.2f} NOK/kg")
        print(f"📈 Price Change: {((avg_price_2025 - avg_price_2024) / avg_price_2024 * 100):+.1f}%")
        print(f"🌍 Top Market by Volume: {top_market['Market']} ({top_market['Week_36_2025_Volume']:,.0f} tons)")
        print(f"💰 Highest Price Market: {highest_price_market['Market']} ({highest_price_market['Week_36_2025_Price']:.2f} NOK/kg)")
        
        # YTD insights
        ytd_vol_2025 = self.cleaned_df['YTD_2025_Volume'].sum()
        ytd_vol_2024 = self.cleaned_df['YTD_2024_Volume'].sum()
        ytd_avg_price_2025 = self.cleaned_df['YTD_2025_Price'].mean()
        ytd_avg_price_2024 = self.cleaned_df['YTD_2024_Price'].mean()
        
        print(f"\n📊 YTD 2025 Total Volume: {ytd_vol_2025:,.0f} tons")
        print(f"📊 YTD 2024 Total Volume: {ytd_vol_2024:,.0f} tons")
        print(f"📈 YTD Volume Change: {((ytd_vol_2025 - ytd_vol_2024) / ytd_vol_2024 * 100):+.1f}%")
        print(f"💰 YTD Average Price 2025: {ytd_avg_price_2025:.2f} NOK/kg")
        print(f"💰 YTD Average Price 2024: {ytd_avg_price_2024:.2f} NOK/kg")
        print(f"📈 YTD Price Change: {((ytd_avg_price_2025 - ytd_avg_price_2024) / ytd_avg_price_2024 * 100):+.1f}%")
        
    def run_complete_analysis(self):
        """Run the complete analysis on real data."""
        print("🚀 Starting Real Norwegian Seafood Council Data Analysis...")
        
        self.load_and_parse_data()
        
        if self.cleaned_df is not None:
            self.analyze_weekly_data()
            self.analyze_market_performance()
            self.create_visualizations()
            self.generate_insights()
            
            print("\n✅ Real data analysis completed successfully!")
        else:
            print("❌ Analysis failed - could not parse data")

def main():
    """Main function."""
    analysis = RealSeafoodAnalysis()
    analysis.run_complete_analysis()

if __name__ == "__main__":
    main()
