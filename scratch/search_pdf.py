import sys
import time
import os
import unicodedata

# Add the local lib directory to sys.path
sys.path.insert(0, '/Users/hussain/Documents/sijilli/scratch/lib')
from pypdf import PdfReader

def search_phrase_in_pdf(file_path, query_phrase):
    print(f"Loading and searching inside: {file_path}")
    start_time = time.time()
    
    # 1. Normalize the query phrase
    normalized_query = unicodedata.normalize('NFKC', query_phrase).strip()
    print(f"Original Query: '{query_phrase}'")
    print(f"Normalized Query: '{normalized_query}'")
    
    reader = PdfReader(file_path)
    total_pages = len(reader.pages)
    
    found_results = []
    
    # 2. Iterate and extract text (representing what indexing does)
    for page_num in range(total_pages):
        page = reader.pages[page_num]
        text = page.extract_text()
        if not text:
            continue
            
        # Normalize page text
        normalized_text = unicodedata.normalize('NFKC', text)
        
        # Search
        if normalized_query in normalized_text:
            idx = normalized_text.find(normalized_query)
            # Extract snippet of 50 chars before and after
            start_idx = max(0, idx - 60)
            end_idx = min(len(normalized_text), idx + len(normalized_query) + 60)
            snippet = normalized_text[start_idx:end_idx].replace('\n', ' ')
            found_results.append((page_num, snippet))
            
    end_time = time.time()
    duration = end_time - start_time
    
    print("\nSearch Results:")
    print("-" * 50)
    if found_results:
        for page_num, snippet in found_results:
            print(f"Found on Page {page_num + 1}:")
            print(f"  ... {snippet} ...")
    else:
        print("Phrase not found.")
    print("-" * 50)
    print(f"Time taken to extract and search 352 pages: {duration * 1000:.2f} milliseconds ({duration:.4f} seconds)")

search_phrase_in_pdf('/Users/hussain/Documents/sijilli/docs/PDB Books/book377.pdf', 'ﻓﻴﺨﻠﻂ ﻣﻊ ﺍﻟﺨﺒﺰ')
