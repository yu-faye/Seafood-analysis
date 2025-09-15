"""
Simple script to download all Norwegian Seafood Council data
"""

from enhanced_downloader import EnhancedSeafoodDownloader

def main():
    print("🚀 Starting comprehensive data download from Norwegian Seafood Council...")
    print("This will download all available Excel files from the statistics archive.")
    print("=" * 70)
    
    downloader = EnhancedSeafoodDownloader()
    downloader.download_all_data()
    
    print("\n🎉 Download process completed!")
    print("Check the 'data/' directory for all downloaded files.")

if __name__ == "__main__":
    main()
