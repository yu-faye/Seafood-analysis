"""
Demo script for Norwegian Seafood Export Analysis

This script demonstrates the analysis with sample data.
"""

from generate_sample_data import generate_sample_data
from seafood_analysis import NorwegianSeafoodAnalysis
import os

def run_demo():
    """Run a complete demo of the seafood analysis."""
    
    print("🐟 Norwegian Seafood Export Analysis Demo")
    print("=" * 50)
    
    # Step 1: Generate sample data
    print("\n1. Generating sample data...")
    sample_file = "sample_norwegian_seafood_export.xlsx"
    
    if not os.path.exists(sample_file):
        generate_sample_data(years=5, output_file=sample_file)
    else:
        print(f"   Sample data already exists: {sample_file}")
    
    # Step 2: Run analysis
    print("\n2. Running analysis...")
    analysis = NorwegianSeafoodAnalysis(data_file=sample_file)
    analysis.run_complete_analysis()
    
    print("\n🎉 Demo completed successfully!")
    print("\nCheck the 'visualizations' folder for generated charts.")

if __name__ == "__main__":
    run_demo()
