"""
Comprehensive Norwegian Seafood Council Data Analysis

This script analyzes the complete multi-week, multi-category dataset
from the Norwegian Seafood Council statistics archive.
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
import warnings
import glob
import re
from datetime import datetime
warnings.filterwarnings('ignore')

class ComprehensiveSeafoodAnalysis:
    """Comprehensive analysis for multi-week, multi-category seafood data."""
    
    def __init__(self, data_dir="data"):
        self.data_dir = Path(data_dir)
        self.all_data = {}
        self.combined_df = None
        self.analysis_results = {}
        
    def load_all_data(self):
        """Load all available weekly data files."""
        print("🐟 Loading Comprehensive Norwegian Seafood Data")
        print("=" * 60)
        
        # Find all Excel files
        excel_files = list(self.data_dir.glob("*.xlsx"))
        print(f"Found {len(excel_files)} Excel files")
        
        # Group files by category
        categories = {
            'laks_og_orret': [],
            'hvitfiskprodukter': [],
            'sild_og_makrell': [],
            'konvensjonelle_produkter': []
        }
        
        for file in excel_files:
            filename = file.name.lower()
            if 'laks-og-orret' in filename:
                categories['laks_og_orret'].append(file)
            elif 'hvitfiskprodukter' in filename:
                categories['hvitfiskprodukter'].append(file)
            elif 'sild-og-makrell' in filename:
                categories['sild_og_makrell'].append(file)
            elif 'konvensjonelle-produkter' in filename:
                categories['konvensjonelle_produkter'].append(file)
        
        # Load data for each category
        for category, files in categories.items():
            if files:
                print(f"\n📊 Loading {category.replace('_', ' ').title()} data...")
                category_data = self._load_category_data(files, category)
                self.all_data[category] = category_data
                print(f"   Loaded {len(category_data)} weeks of data")
        
        # Combine all data
        self._combine_all_data()
        
    def _load_category_data(self, files, category):
        """Load data for a specific category."""
        category_data = []
        
        for file in sorted(files):
            # Extract week number from filename
            week_match = re.search(r'uke-(\d+)', file.name)
            if week_match:
                week_num = int(week_match.group(1))
                
                try:
                    # Load the file
                    df = pd.read_excel(file, header=None)
                    
                    # Parse the data
                    parsed_data = self._parse_weekly_data(df, week_num, category)
                    if parsed_data is not None and not parsed_data.empty:
                        category_data.append(parsed_data)
                        
                except Exception as e:
                    print(f"   Warning: Could not load {file.name}: {e}")
        
        return category_data
    
    def _parse_weekly_data(self, df, week_num, category):
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
    
    def _combine_all_data(self):
        """Combine all category data into a single DataFrame."""
        all_dfs = []
        
        for category, data_list in self.all_data.items():
            for df in data_list:
                all_dfs.append(df)
        
        if all_dfs:
            self.combined_df = pd.concat(all_dfs, ignore_index=True)
            print(f"\n📊 Combined dataset: {len(self.combined_df)} records")
            print(f"   Categories: {self.combined_df['Category'].nunique()}")
            print(f"   Weeks: {sorted(self.combined_df['Week'].unique())}")
            print(f"   Markets: {self.combined_df['Market'].nunique()}")
        else:
            print("❌ No data could be combined")
    
    def analyze_trends(self):
        """Analyze trends across all data."""
        if self.combined_df is None:
            print("No data available for analysis")
            return
        
        print("\n📈 COMPREHENSIVE TREND ANALYSIS")
        print("=" * 50)
        
        # Overall volume trends by week
        weekly_totals = self.combined_df.groupby('Week').agg({
            'Current_Week_Volume': 'sum',
            'Previous_Year_Volume': 'sum'
        }).round(2)
        
        print("\n📊 Weekly Volume Trends")
        print("-" * 30)
        print(weekly_totals)
        
        # Calculate growth rates
        weekly_totals['Volume_Growth_%'] = (
            (weekly_totals['Current_Week_Volume'] - weekly_totals['Previous_Year_Volume']) / 
            weekly_totals['Previous_Year_Volume'] * 100
        ).round(2)
        
        print(f"\nAverage Volume Growth: {weekly_totals['Volume_Growth_%'].mean():.1f}%")
        
        # Category analysis
        print("\n🐟 Category Performance")
        print("-" * 30)
        category_analysis = self.combined_df.groupby('Category').agg({
            'Current_Week_Volume': 'sum',
            'Current_Week_Price': 'mean'
        }).round(2)
        
        category_analysis['Volume_Share_%'] = (
            category_analysis['Current_Week_Volume'] / 
            category_analysis['Current_Week_Volume'].sum() * 100
        ).round(2)
        
        print(category_analysis)
        
        # Market analysis
        print("\n🌍 Top Markets (All Categories)")
        print("-" * 30)
        market_analysis = self.combined_df.groupby('Market').agg({
            'Current_Week_Volume': 'sum',
            'Current_Week_Price': 'mean'
        }).round(2)
        
        market_analysis = market_analysis.sort_values('Current_Week_Volume', ascending=False)
        print(market_analysis.head(15))
        
        self.analysis_results = {
            'weekly_totals': weekly_totals,
            'category_analysis': category_analysis,
            'market_analysis': market_analysis
        }
    
    def create_comprehensive_visualizations(self):
        """Create comprehensive visualizations."""
        if self.combined_df is None:
            return
        
        print("\n📊 CREATING COMPREHENSIVE VISUALIZATIONS")
        print("=" * 50)
        
        output_dir = Path("visualizations")
        output_dir.mkdir(exist_ok=True)
        
        # Set style
        plt.style.use('seaborn-v0_8')
        sns.set_palette("husl")
        
        # 1. Weekly volume trends
        self._create_weekly_trends_chart(output_dir)
        
        # 2. Category performance
        self._create_category_performance_chart(output_dir)
        
        # 3. Top markets analysis
        self._create_top_markets_chart(output_dir)
        
        # 4. Price trends by category
        self._create_price_trends_chart(output_dir)
        
        # 5. Market growth analysis
        self._create_market_growth_chart(output_dir)
        
        print(f"Visualizations saved in {output_dir} directory")
    
    def _create_weekly_trends_chart(self, output_dir):
        """Create weekly volume trends chart."""
        weekly_data = self.combined_df.groupby('Week').agg({
            'Current_Week_Volume': 'sum',
            'Previous_Year_Volume': 'sum'
        })
        
        fig, ax = plt.subplots(figsize=(14, 8))
        
        weeks = weekly_data.index
        ax.plot(weeks, weekly_data['Current_Week_Volume'], 
                marker='o', linewidth=2, label='2025', markersize=6)
        ax.plot(weeks, weekly_data['Previous_Year_Volume'], 
                marker='s', linewidth=2, label='2024', markersize=6)
        
        ax.set_title('Norwegian Seafood Export Volume Trends (Weeks 18-36)', 
                    fontsize=16, fontweight='bold')
        ax.set_xlabel('Week Number')
        ax.set_ylabel('Volume (tons)')
        ax.legend()
        ax.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(output_dir / 'comprehensive_weekly_trends.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def _create_category_performance_chart(self, output_dir):
        """Create category performance chart."""
        category_data = self.combined_df.groupby('Category').agg({
            'Current_Week_Volume': 'sum',
            'Current_Week_Price': 'mean'
        })
        
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 8))
        
        # Volume by category
        categories = category_data.index
        volumes = category_data['Current_Week_Volume']
        
        bars1 = ax1.bar(categories, volumes)
        ax1.set_title('Export Volume by Category', fontsize=14, fontweight='bold')
        ax1.set_ylabel('Volume (tons)')
        ax1.tick_params(axis='x', rotation=45)
        
        # Add value labels on bars
        for bar in bars1:
            height = bar.get_height()
            ax1.text(bar.get_x() + bar.get_width()/2., height + height*0.01,
                    f'{height:,.0f}', ha='center', va='bottom')
        
        # Price by category
        prices = category_data['Current_Week_Price']
        
        bars2 = ax2.bar(categories, prices)
        ax2.set_title('Average Price by Category', fontsize=14, fontweight='bold')
        ax2.set_ylabel('Price (NOK/kg)')
        ax2.tick_params(axis='x', rotation=45)
        
        # Add value labels on bars
        for bar in bars2:
            height = bar.get_height()
            ax2.text(bar.get_x() + bar.get_width()/2., height + height*0.01,
                    f'{height:.1f}', ha='center', va='bottom')
        
        plt.tight_layout()
        plt.savefig(output_dir / 'comprehensive_category_performance.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def _create_top_markets_chart(self, output_dir):
        """Create top markets analysis chart."""
        market_data = self.combined_df.groupby('Market').agg({
            'Current_Week_Volume': 'sum',
            'Current_Week_Price': 'mean'
        }).sort_values('Current_Week_Volume', ascending=False).head(15)
        
        fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(14, 12))
        
        # Top markets by volume
        markets = market_data.index
        volumes = market_data['Current_Week_Volume']
        
        bars1 = ax1.barh(range(len(markets)), volumes)
        ax1.set_yticks(range(len(markets)))
        ax1.set_yticklabels(markets)
        ax1.set_xlabel('Volume (tons)')
        ax1.set_title('Top 15 Markets by Volume (All Categories)', fontsize=14, fontweight='bold')
        ax1.grid(True, alpha=0.3)
        
        # Top markets by price
        prices = market_data['Current_Week_Price']
        
        bars2 = ax2.barh(range(len(markets)), prices)
        ax2.set_yticks(range(len(markets)))
        ax2.set_yticklabels(markets)
        ax2.set_xlabel('Price (NOK/kg)')
        ax2.set_title('Top 15 Markets by Price (All Categories)', fontsize=14, fontweight='bold')
        ax2.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(output_dir / 'comprehensive_top_markets.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def _create_price_trends_chart(self, output_dir):
        """Create price trends by category chart."""
        price_trends = self.combined_df.groupby(['Week', 'Category'])['Current_Week_Price'].mean().unstack()
        
        plt.figure(figsize=(14, 8))
        
        for category in price_trends.columns:
            plt.plot(price_trends.index, price_trends[category], 
                    marker='o', linewidth=2, label=category.replace('_', ' ').title(), markersize=4)
        
        plt.title('Price Trends by Category (Weeks 18-36)', fontsize=16, fontweight='bold')
        plt.xlabel('Week Number')
        plt.ylabel('Price (NOK/kg)')
        plt.legend()
        plt.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(output_dir / 'comprehensive_price_trends.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def _create_market_growth_chart(self, output_dir):
        """Create market growth analysis chart."""
        # Calculate growth rates for each market
        market_growth = self.combined_df.groupby('Market').agg({
            'Current_Week_Volume': 'sum',
            'Previous_Year_Volume': 'sum'
        })
        
        market_growth['Growth_%'] = (
            (market_growth['Current_Week_Volume'] - market_growth['Previous_Year_Volume']) / 
            market_growth['Previous_Year_Volume'] * 100
        ).round(2)
        
        # Filter for markets with significant volume and growth
        significant_markets = market_growth[
            (market_growth['Current_Week_Volume'] > 1000) & 
            (market_growth['Growth_%'].abs() < 1000)  # Remove extreme outliers
        ].sort_values('Growth_%', ascending=False)
        
        plt.figure(figsize=(14, 10))
        
        # Create horizontal bar chart
        colors = ['green' if x > 0 else 'red' for x in significant_markets['Growth_%']]
        bars = plt.barh(range(len(significant_markets)), significant_markets['Growth_%'], color=colors, alpha=0.7)
        
        plt.yticks(range(len(significant_markets)), significant_markets.index)
        plt.xlabel('Growth Rate (%)')
        plt.title('Market Growth Analysis (2025 vs 2024)', fontsize=16, fontweight='bold')
        plt.axvline(x=0, color='black', linestyle='-', alpha=0.3)
        plt.grid(True, alpha=0.3)
        
        # Add value labels
        for i, bar in enumerate(bars):
            width = bar.get_width()
            plt.text(width + (1 if width >= 0 else -1), bar.get_y() + bar.get_height()/2,
                    f'{width:.1f}%', ha='left' if width >= 0 else 'right', va='center')
        
        plt.tight_layout()
        plt.savefig(output_dir / 'comprehensive_market_growth.png', dpi=300, bbox_inches='tight')
        plt.close()
    
    def generate_comprehensive_insights(self):
        """Generate comprehensive insights from all data."""
        if self.combined_df is None:
            return
        
        print("\n🔍 COMPREHENSIVE INSIGHTS")
        print("=" * 50)
        
        # Overall statistics
        total_volume = self.combined_df['Current_Week_Volume'].sum()
        total_previous_volume = self.combined_df['Previous_Year_Volume'].sum()
        avg_price = self.combined_df['Current_Week_Price'].mean()
        avg_previous_price = self.combined_df['Previous_Year_Price'].mean()
        
        volume_growth = ((total_volume - total_previous_volume) / total_previous_volume * 100) if total_previous_volume > 0 else 0
        price_change = ((avg_price - avg_previous_price) / avg_previous_price * 100) if avg_previous_price > 0 else 0
        
        print(f"📊 Total Export Volume: {total_volume:,.0f} tons")
        print(f"📊 Previous Year Volume: {total_previous_volume:,.0f} tons")
        print(f"📈 Volume Growth: {volume_growth:+.1f}%")
        print(f"💰 Average Price: {avg_price:.2f} NOK/kg")
        print(f"💰 Previous Year Price: {avg_previous_price:.2f} NOK/kg")
        print(f"📈 Price Change: {price_change:+.1f}%")
        
        # Top performing markets
        top_market = self.combined_df.groupby('Market')['Current_Week_Volume'].sum().idxmax()
        top_market_volume = self.combined_df.groupby('Market')['Current_Week_Volume'].sum().max()
        
        highest_price_market = self.combined_df.groupby('Market')['Current_Week_Price'].mean().idxmax()
        highest_price = self.combined_df.groupby('Market')['Current_Week_Price'].mean().max()
        
        print(f"\n🌍 Top Market by Volume: {top_market} ({top_market_volume:,.0f} tons)")
        print(f"💰 Highest Price Market: {highest_price_market} ({highest_price:.2f} NOK/kg)")
        
        # Category insights
        category_volumes = self.combined_df.groupby('Category')['Current_Week_Volume'].sum().sort_values(ascending=False)
        print(f"\n🐟 Category Performance:")
        for category, volume in category_volumes.items():
            share = (volume / total_volume * 100)
            print(f"   {category.replace('_', ' ').title()}: {volume:,.0f} tons ({share:.1f}%)")
        
        # Growth insights
        market_growth = self.combined_df.groupby('Market').agg({
            'Current_Week_Volume': 'sum',
            'Previous_Year_Volume': 'sum'
        })
        market_growth['Growth_%'] = (
            (market_growth['Current_Week_Volume'] - market_growth['Previous_Year_Volume']) / 
            market_growth['Previous_Year_Volume'] * 100
        )
        
        fastest_growing = market_growth[market_growth['Current_Week_Volume'] > 1000].nlargest(3, 'Growth_%')
        print(f"\n📈 Fastest Growing Markets:")
        for market, data in fastest_growing.iterrows():
            print(f"   {market}: {data['Growth_%']:+.1f}%")
    
    def run_comprehensive_analysis(self):
        """Run the complete comprehensive analysis."""
        print("🚀 Starting Comprehensive Norwegian Seafood Analysis...")
        print("=" * 60)
        
        self.load_all_data()
        
        if self.combined_df is not None:
            self.analyze_trends()
            self.create_comprehensive_visualizations()
            self.generate_comprehensive_insights()
            
            print("\n✅ Comprehensive analysis completed successfully!")
            print("📁 Check the 'visualizations' folder for all charts")
        else:
            print("❌ Analysis failed - no data could be loaded")

def main():
    """Main function."""
    analysis = ComprehensiveSeafoodAnalysis()
    analysis.run_comprehensive_analysis()

if __name__ == "__main__":
    main()
