"""
Norwegian Seafood Council Data Downloader

This script downloads all available Excel files from the Norwegian Seafood Council
statistics archive website.
"""

import requests
from bs4 import BeautifulSoup
import os
import time
from urllib.parse import urljoin, urlparse
from pathlib import Path
import re

class NorwegianSeafoodDownloader:
    """Downloads Norwegian Seafood Council data from their statistics archive."""
    
    def __init__(self, base_url="https://en.seafood.no/market-insight/statistics-archive/"):
        self.base_url = base_url
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        })
        self.downloaded_files = []
        self.failed_downloads = []
        
    def get_page_content(self, url):
        """Get the content of a webpage."""
        try:
            response = self.session.get(url, timeout=30)
            response.raise_for_status()
            return response.text
        except requests.RequestException as e:
            print(f"Error fetching {url}: {e}")
            return None
    
    def find_excel_links(self, html_content, base_url):
        """Find all Excel file links on the page."""
        soup = BeautifulSoup(html_content, 'html.parser')
        excel_links = []
        
        # Look for direct Excel file links
        for link in soup.find_all('a', href=True):
            href = link['href']
            if href.lower().endswith(('.xlsx', '.xls')):
                full_url = urljoin(base_url, href)
                excel_links.append({
                    'url': full_url,
                    'text': link.get_text(strip=True),
                    'filename': os.path.basename(urlparse(full_url).path)
                })
        
        # Look for links that might lead to Excel files
        for link in soup.find_all('a', href=True):
            href = link['href']
            text = link.get_text(strip=True).lower()
            
            # Check if the link text suggests it contains data
            if any(keyword in text for keyword in ['export', 'statistics', 'data', 'monthly', 'weekly', 'trade']):
                full_url = urljoin(base_url, href)
                if not full_url.endswith(('.xlsx', '.xls')):
                    # This might be a page with Excel files, explore it
                    excel_links.extend(self.explore_page_for_excel(full_url))
        
        return excel_links
    
    def explore_page_for_excel(self, url):
        """Explore a page to find Excel files."""
        print(f"Exploring page: {url}")
        content = self.get_page_content(url)
        if not content:
            return []
        
        return self.find_excel_links(content, url)
    
    def download_file(self, url, filename, download_dir="data"):
        """Download a file from URL."""
        try:
            # Create download directory
            Path(download_dir).mkdir(exist_ok=True)
            
            # Get the file
            response = self.session.get(url, timeout=60, stream=True)
            response.raise_for_status()
            
            # Determine file path
            file_path = os.path.join(download_dir, filename)
            
            # Download the file
            with open(file_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            
            file_size = os.path.getsize(file_path)
            print(f"✅ Downloaded: {filename} ({file_size:,} bytes)")
            self.downloaded_files.append({
                'filename': filename,
                'url': url,
                'size': file_size,
                'path': file_path
            })
            return True
            
        except Exception as e:
            print(f"❌ Failed to download {filename}: {e}")
            self.failed_downloads.append({
                'filename': filename,
                'url': url,
                'error': str(e)
            })
            return False
    
    def clean_filename(self, filename):
        """Clean filename to be filesystem-safe."""
        # Remove or replace invalid characters
        filename = re.sub(r'[<>:"/\\|?*]', '_', filename)
        filename = filename.strip()
        
        # Ensure it has an extension
        if not filename.lower().endswith(('.xlsx', '.xls')):
            filename += '.xlsx'
        
        return filename
    
    def download_all_data(self):
        """Download all available Excel data from the statistics archive."""
        print("🐟 Norwegian Seafood Council Data Downloader")
        print("=" * 50)
        print(f"Target URL: {self.base_url}")
        
        # Get the main page
        print("\n1. Fetching main statistics archive page...")
        content = self.get_page_content(self.base_url)
        if not content:
            print("❌ Failed to fetch main page")
            return
        
        # Find all Excel links
        print("2. Searching for Excel files...")
        excel_links = self.find_excel_links(content, self.base_url)
        
        print(f"Found {len(excel_links)} potential Excel files")
        
        if not excel_links:
            print("No Excel files found. Let me try alternative approaches...")
            # Try to find other data sources
            self.try_alternative_sources()
            return
        
        # Download all files
        print(f"\n3. Downloading {len(excel_links)} files...")
        for i, link_info in enumerate(excel_links, 1):
            url = link_info['url']
            original_filename = link_info['filename']
            display_text = link_info['text']
            
            # Clean filename
            clean_name = self.clean_filename(original_filename or f"seafood_data_{i}")
            
            print(f"\n[{i}/{len(excel_links)}] Downloading: {display_text}")
            print(f"URL: {url}")
            print(f"Filename: {clean_name}")
            
            # Download the file
            self.download_file(url, clean_name)
            
            # Be respectful - add a small delay
            time.sleep(1)
        
        # Summary
        self.print_summary()
    
    def try_alternative_sources(self):
        """Try alternative approaches to find data."""
        print("\nTrying alternative data sources...")
        
        # Common Norwegian Seafood data URLs to try
        alternative_urls = [
            "https://en.seafood.no/market-insight/open-statistics/",
            "https://en.seafood.no/market-insight/",
            "https://en.seafood.no/",
        ]
        
        for url in alternative_urls:
            print(f"Checking: {url}")
            content = self.get_page_content(url)
            if content:
                excel_links = self.find_excel_links(content, url)
                if excel_links:
                    print(f"Found {len(excel_links)} files at {url}")
                    # Download these files
                    for link_info in excel_links:
                        url = link_info['url']
                        filename = self.clean_filename(link_info['filename'] or "seafood_data")
                        self.download_file(url, filename)
                    break
    
    def print_summary(self):
        """Print download summary."""
        print("\n" + "=" * 50)
        print("📊 DOWNLOAD SUMMARY")
        print("=" * 50)
        
        print(f"✅ Successfully downloaded: {len(self.downloaded_files)} files")
        print(f"❌ Failed downloads: {len(self.failed_downloads)} files")
        
        if self.downloaded_files:
            print(f"\n📁 Downloaded files:")
            total_size = 0
            for file_info in self.downloaded_files:
                size_mb = file_info['size'] / (1024 * 1024)
                total_size += file_info['size']
                print(f"  • {file_info['filename']} ({size_mb:.2f} MB)")
            
            total_size_mb = total_size / (1024 * 1024)
            print(f"\nTotal size: {total_size_mb:.2f} MB")
        
        if self.failed_downloads:
            print(f"\n❌ Failed downloads:")
            for file_info in self.failed_downloads:
                print(f"  • {file_info['filename']}: {file_info['error']}")
        
        print(f"\n📂 Files saved in: data/ directory")
        
        if self.downloaded_files:
            print(f"\n🚀 Next steps:")
            print(f"1. Check the downloaded files in the 'data/' directory")
            print(f"2. Run the analysis: python seafood_analysis.py")
            print(f"3. Or use the quick analysis: python quick_analysis.py")

def main():
    """Main function to run the downloader."""
    downloader = NorwegianSeafoodDownloader()
    downloader.download_all_data()

if __name__ == "__main__":
    main()
