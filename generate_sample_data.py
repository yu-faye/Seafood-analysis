"""
Sample Data Generator for Norwegian Seafood Export Statistics

This script generates sample data that mimics the structure of the Norwegian
Seafood Council Export Statistics dataset for demonstration purposes.
"""

import pandas as pd
import numpy as np
from datetime import datetime
import random

def generate_sample_data(years=5, output_file="sample_norwegian_seafood_export.xlsx"):
    """
    Generate sample Norwegian seafood export data.
    
    Args:
        years (int): Number of years of data to generate
        output_file (str): Output Excel filename
    """
    
    # Define the data structure based on Norwegian Seafood Council format
    species = [
        'Atlantic Salmon', 'Atlantic Cod', 'Norwegian Spring Spawning Herring',
        'Mackerel', 'Capelin', 'Saithe', 'Haddock', 'Redfish', 'Ling',
        'Tusk', 'Wolffish', 'Halibut', 'Turbot', 'Plaice', 'Dab'
    ]
    
    product_forms = [
        'Fresh', 'Frozen', 'Salted', 'Dried', 'Smoked', 'Canned',
        'Fillet', 'Whole', 'Headless', 'Gutted', 'Roe', 'Liver'
    ]
    
    markets = [
        'China', 'EU', 'USA', 'Japan', 'South Korea', 'Thailand',
        'Vietnam', 'Brazil', 'Russia', 'Ukraine', 'Poland', 'Germany',
        'France', 'Spain', 'Italy', 'United Kingdom', 'Netherlands',
        'Belgium', 'Denmark', 'Sweden', 'Norway', 'Finland'
    ]
    
    # Generate data
    data = []
    np.random.seed(42)  # For reproducible results
    
    for year in range(2020, 2020 + years):
        for month in range(1, 13):
            # Generate 50-100 records per month
            num_records = np.random.randint(50, 101)
            
            for _ in range(num_records):
                species_choice = np.random.choice(species)
                product_form = np.random.choice(product_forms)
                market = np.random.choice(markets)
                
                # Generate realistic volume and value based on species and market
                base_volume = np.random.uniform(10, 1000)  # tons
                base_value = base_volume * np.random.uniform(20, 150)  # NOK per ton
                
                # Adjust based on species (salmon and cod are more valuable)
                if species_choice in ['Atlantic Salmon', 'Atlantic Cod']:
                    base_value *= np.random.uniform(1.5, 3.0)
                elif species_choice in ['Mackerel', 'Herring']:
                    base_value *= np.random.uniform(0.3, 0.8)
                
                # Adjust based on market (China and EU are major markets)
                if market in ['China', 'EU']:
                    base_volume *= np.random.uniform(1.2, 2.5)
                    base_value *= np.random.uniform(1.1, 2.0)
                elif market in ['USA', 'Japan']:
                    base_volume *= np.random.uniform(0.8, 1.5)
                    base_value *= np.random.uniform(1.2, 2.2)
                
                # Add some year-over-year growth
                year_factor = 1 + (year - 2020) * 0.05  # 5% growth per year
                base_volume *= year_factor
                base_value *= year_factor
                
                # Add seasonal variation
                if month in [11, 12, 1, 2]:  # Winter months
                    base_volume *= np.random.uniform(0.8, 1.2)
                    base_value *= np.random.uniform(0.9, 1.3)
                elif month in [6, 7, 8]:  # Summer months
                    base_volume *= np.random.uniform(1.1, 1.4)
                    base_value *= np.random.uniform(1.0, 1.2)
                
                # Add some noise
                volume = max(0, base_volume + np.random.normal(0, base_volume * 0.1))
                value = max(0, base_value + np.random.normal(0, base_value * 0.1))
                
                data.append({
                    'Year': year,
                    'Month': month,
                    'Species': species_choice,
                    'Product Form': product_form,
                    'Market': market,
                    'Volume (tons)': round(volume, 2),
                    'Value (NOK)': round(value, 2)
                })
    
    # Create DataFrame
    df = pd.DataFrame(data)
    
    # Add some missing values to make it realistic
    missing_indices = np.random.choice(df.index, size=int(len(df) * 0.02), replace=False)
    df.loc[missing_indices, 'Volume (tons)'] = np.nan
    
    missing_indices = np.random.choice(df.index, size=int(len(df) * 0.01), replace=False)
    df.loc[missing_indices, 'Value (NOK)'] = np.nan
    
    # Save to Excel
    df.to_excel(output_file, index=False)
    
    print(f"Sample data generated: {len(df)} records")
    print(f"Years: {df['Year'].min()}-{df['Year'].max()}")
    print(f"Species: {df['Species'].nunique()}")
    print(f"Markets: {df['Market'].nunique()}")
    print(f"Total Volume: {df['Volume (tons)'].sum():,.0f} tons")
    print(f"Total Value: {df['Value (NOK)'].sum():,.0f} NOK")
    print(f"Saved to: {output_file}")
    
    return df

if __name__ == "__main__":
    # Generate sample data
    sample_df = generate_sample_data(years=5)
    
    # Display sample of the data
    print("\nSample of generated data:")
    print(sample_df.head(10))
