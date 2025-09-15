"""
Enhanced Norwegian Seafood Council Data Downloader

This script specifically targets the Norwegian Seafood Council statistics archive
and downloads all available Excel files with proper structure handling.
"""

import requests
from bs4 import BeautifulSoup
import os
import time
from urllib.parse import urljoin, urlparse
from pathlib import Path
import re
import json
from datetime import datetime

class EnhancedSeafoodDownloader:
    """Enhanced downloader for Norwegian Seafood Council data."""
    
    def __init__(self):
        self.base_url = "https://en.seafood.no/market-insight/statistics-archive/"
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Accept-Encoding': 'gzip, deflate',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        })
        self.downloaded_files = []
        self.failed_downloads = []
        self.data_dir = Path("data")
        self.data_dir.mkdir(exist_ok=True)
        
    def get_page_content(self, url, max_retries=3):
        """Get page content with retries."""
        for attempt in range(max_retries):
            try:
                print(f"Fetching: {url} (attempt {attempt + 1})")
                response = self.session.get(url, timeout=30)
                response.raise_for_status()
                return response.text
            except requests.RequestException as e:
                print(f"Attempt {attempt + 1} failed: {e}")
                if attempt < max_retries - 1:
                    time.sleep(2 ** attempt)  # Exponential backoff
                else:
                    return None
    
    def find_all_data_links(self, base_url):
        """Find all potential data links from the statistics archive."""
        all_links = []
        
        # Get main page
        content = self.get_page_content(base_url)
        if not content:
            return all_links
        
        soup = BeautifulSoup(content, 'html.parser')
        
        # Look for all links that might contain data
        for link in soup.find_all('a', href=True):
            href = link['href']
            text = link.get_text(strip=True)
            
            # Skip empty links
            if not href or not text:
                continue
            
            # Convert relative URLs to absolute
            full_url = urljoin(base_url, href)
            
            # Check if this looks like a data link
            if self.is_data_link(text, href):
                all_links.append({
                    'url': full_url,
                    'text': text,
                    'type': self.classify_link(text, href)
                })
        
        return all_links
    
    def is_data_link(self, text, href):
        """Check if a link likely contains data."""
        text_lower = text.lower()
        href_lower = href.lower()
        
        # Keywords that suggest data content
        data_keywords = [
            'export', 'import', 'statistics', 'data', 'trade', 'market',
            'monthly', 'weekly', 'annual', 'yearly', 'quarterly',
            'volume', 'value', 'tonnage', 'seafood', 'fish', 'salmon',
            'cod', 'herring', 'mackerel', 'species', 'product'
        ]
        
        # File extensions that suggest data
        data_extensions = ['.xlsx', '.xls', '.csv', '.pdf']
        
        # Check for data keywords in text or URL
        has_data_keyword = any(keyword in text_lower or keyword in href_lower 
                              for keyword in data_keywords)
        
        # Check for data file extensions
        has_data_extension = any(href_lower.endswith(ext) for ext in data_extensions)
        
        return has_data_keyword or has_data_extension
    
    def classify_link(self, text, href):
        """Classify the type of data link."""
        text_lower = text.lower()
        href_lower = href.lower()
        
        if any(word in text_lower for word in ['monthly', 'month']):
            return 'monthly'
        elif any(word in text_lower for word in ['weekly', 'week']):
            return 'weekly'
        elif any(word in text_lower for word in ['annual', 'yearly', 'year']):
            return 'annual'
        elif any(word in text_lower for word in ['export', 'exports']):
            return 'export'
        elif any(word in text_lower for word in ['import', 'imports']):
            return 'import'
        else:
            return 'general'
    
    def explore_data_page(self, url, link_type):
        """Explore a specific data page to find downloadable files."""
        print(f"Exploring {link_type} data page: {url}")
        
        content = self.get_page_content(url)
        if not content:
            return []
        
        soup = BeautifulSoup(content, 'html.parser')
        files_found = []
        
        # Look for direct file downloads
        for link in soup.find_all('a', href=True):
            href = link['href']
            text = link.get_text(strip=True)
            
            if href.lower().endswith(('.xlsx', '.xls', '.csv')):
                full_url = urljoin(url, href)
                files_found.append({
                    'url': full_url,
                    'filename': os.path.basename(urlparse(full_url).path),
                    'text': text,
                    'type': link_type,
                    'source_page': url
                })
        
        # Look for embedded data or iframes
        for iframe in soup.find_all('iframe', src=True):
            iframe_url = urljoin(url, iframe['src'])
            print(f"Found iframe: {iframe_url}")
            # Recursively explore iframe content
            iframe_files = self.explore_data_page(iframe_url, link_type)
            files_found.extend(iframe_files)
        
        return files_found
    
    def download_file(self, file_info):
        """Download a single file."""
        url = file_info['url']
        original_filename = file_info['filename']
        file_type = file_info['type']
        source_page = file_info.get('source_page', '')
        
        # Create filename with type prefix
        clean_filename = self.clean_filename(original_filename)
        if not clean_filename.lower().endswith(('.xlsx', '.xls', '.csv')):
            clean_filename += '.xlsx'
        
        # Add type prefix
        type_prefix = f"{file_type}_" if file_type != 'general' else ""
        final_filename = f"{type_prefix}{clean_filename}"
        
        try:
            print(f"Downloading: {final_filename}")
            print(f"From: {url}")
            
            response = self.session.get(url, timeout=60, stream=True)
            response.raise_for_status()
            
            file_path = self.data_dir / final_filename
            
            with open(file_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            
            file_size = file_path.stat().st_size
            print(f"✅ Downloaded: {final_filename} ({file_size:,} bytes)")
            
            self.downloaded_files.append({
                'filename': final_filename,
                'url': url,
                'size': file_size,
                'path': str(file_path),
                'type': file_type,
                'source_page': source_page
            })
            
            return True
            
        except Exception as e:
            print(f"❌ Failed to download {final_filename}: {e}")
            self.failed_downloads.append({
                'filename': final_filename,
                'url': url,
                'error': str(e),
                'type': file_type
            })
            return False
    
    def clean_filename(self, filename):
        """Clean filename to be filesystem-safe."""
        if not filename:
            return f"seafood_data_{int(time.time())}"
        
        # Remove or replace invalid characters
        filename = re.sub(r'[<>:"/\\|?*]', '_', filename)
        filename = re.sub(r'\s+', '_', filename)  # Replace spaces with underscores
        filename = filename.strip('._')
        
        return filename
    
    def download_all_data(self):
        """Main method to download all available data."""
        print("🐟 Enhanced Norwegian Seafood Council Data Downloader")
        print("=" * 60)
        print(f"Target: {self.base_url}")
        print(f"Download directory: {self.data_dir.absolute()}")
        
        # Step 1: Find all data links
        print("\n1. Discovering data links...")
        data_links = self.find_all_data_links(self.base_url)
        
        print(f"Found {len(data_links)} potential data links")
        
        # Group links by type
        links_by_type = {}
        for link in data_links:
            link_type = link['type']
            if link_type not in links_by_type:
                links_by_type[link_type] = []
            links_by_type[link_type].append(link)
        
        print(f"Link types found: {list(links_by_type.keys())}")
        
        # Step 2: Explore each link to find downloadable files
        all_files = []
        for link_type, links in links_by_type.items():
            print(f"\n2. Exploring {link_type} links ({len(links)} links)...")
            
            for i, link in enumerate(links, 1):
                print(f"\n[{i}/{len(links)}] {link['text']}")
                files = self.explore_data_page(link['url'], link_type)
                all_files.extend(files)
                
                # Be respectful - add delay
                time.sleep(1)
        
        print(f"\nFound {len(all_files)} downloadable files")
        
        # Step 3: Download all files
        if all_files:
            print(f"\n3. Downloading {len(all_files)} files...")
            
            for i, file_info in enumerate(all_files, 1):
                print(f"\n[{i}/{len(all_files)}] {file_info['text']}")
                self.download_file(file_info)
                time.sleep(0.5)  # Small delay between downloads
        
        # Step 4: Generate summary
        self.generate_summary()
        
        # Step 5: Create analysis-ready dataset
        self.prepare_analysis_dataset()
    
    def generate_summary(self):
        """Generate download summary and metadata."""
        print("\n" + "=" * 60)
        print("📊 DOWNLOAD SUMMARY")
        print("=" * 60)
        
        print(f"✅ Successfully downloaded: {len(self.downloaded_files)} files")
        print(f"❌ Failed downloads: {len(self.failed_downloads)} files")
        
        if self.downloaded_files:
            # Group by type
            by_type = {}
            total_size = 0
            
            for file_info in self.downloaded_files:
                file_type = file_info['type']
                if file_type not in by_type:
                    by_type[file_type] = []
                by_type[file_type].append(file_info)
                total_size += file_info['size']
            
            print(f"\n📁 Files by type:")
            for file_type, files in by_type.items():
                type_size = sum(f['size'] for f in files)
                print(f"  {file_type.upper()}: {len(files)} files ({type_size / (1024*1024):.2f} MB)")
            
            print(f"\nTotal size: {total_size / (1024*1024):.2f} MB")
            
            # Save metadata
            metadata = {
                'download_date': datetime.now().isoformat(),
                'total_files': len(self.downloaded_files),
                'total_size_bytes': total_size,
                'files_by_type': {k: len(v) for k, v in by_type.items()},
                'downloaded_files': self.downloaded_files,
                'failed_downloads': self.failed_downloads
            }
            
            with open(self.data_dir / 'download_metadata.json', 'w') as f:
                json.dump(metadata, f, indent=2)
            
            print(f"\n📄 Metadata saved to: {self.data_dir / 'download_metadata.json'}")
        
        if self.failed_downloads:
            print(f"\n❌ Failed downloads:")
            for file_info in self.failed_downloads:
                print(f"  • {file_info['filename']}: {file_info['error']}")
    
    def prepare_analysis_dataset(self):
        """Prepare the downloaded data for analysis."""
        if not self.downloaded_files:
            print("No files downloaded to prepare for analysis.")
            return
        
        print(f"\n4. Preparing data for analysis...")
        
        # Look for the most comprehensive dataset
        excel_files = [f for f in self.downloaded_files 
                      if f['filename'].lower().endswith(('.xlsx', '.xls'))]
        
        if excel_files:
            # Use the largest file as the main dataset
            main_file = max(excel_files, key=lambda x: x['size'])
            main_path = Path(main_file['path'])
            
            # Copy to project root for easy access
            import shutil
            target_path = Path("norwegian_seafood_export.xlsx")
            shutil.copy2(main_path, target_path)
            
            print(f"📊 Main dataset prepared: {target_path}")
            print(f"   Source: {main_file['filename']} ({main_file['size']:,} bytes)")
            
            print(f"\n🚀 Ready for analysis!")
            print(f"   Run: python seafood_analysis.py")
            print(f"   Or: python quick_analysis.py")

def main():
    """Main function."""
    downloader = EnhancedSeafoodDownloader()
    downloader.download_all_data()

if __name__ == "__main__":
    main()
