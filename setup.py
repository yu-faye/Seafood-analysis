"""
Setup script for Norwegian Seafood Export Analysis
"""

import subprocess
import sys
import os

def install_requirements():
    """Install required packages."""
    print("Installing required packages...")
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])
        print("✅ Requirements installed successfully!")
    except subprocess.CalledProcessError as e:
        print(f"❌ Error installing requirements: {e}")
        return False
    return True

def create_directories():
    """Create necessary directories."""
    directories = ["visualizations", "data"]
    for directory in directories:
        os.makedirs(directory, exist_ok=True)
        print(f"📁 Created directory: {directory}")

def main():
    """Main setup function."""
    print("🐟 Setting up Norwegian Seafood Export Analysis")
    print("=" * 50)
    
    # Install requirements
    if not install_requirements():
        print("Setup failed. Please install requirements manually.")
        return
    
    # Create directories
    create_directories()
    
    print("\n✅ Setup completed successfully!")
    print("\nNext steps:")
    print("1. Download data from: https://en.seafood.no/market-insight/norwegian-trade/")
    print("2. Save as 'norwegian_seafood_export.xlsx' in the project directory")
    print("3. Run: python seafood_analysis.py")
    print("\nOr run the demo with sample data:")
    print("python demo.py")

if __name__ == "__main__":
    main()
