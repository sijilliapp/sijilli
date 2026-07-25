import sys
import os

sys.path.insert(0, '/Users/hussain/Documents/sijilli/scratch/lib')
from pypdf import PdfReader

def inspect_page(file_path, page_num):
    reader = PdfReader(file_path)
    if page_num < len(reader.pages):
        page = reader.pages[page_num]
        text = page.extract_text()
        print(f"Page {page_num} text preview (length {len(text)}):")
        print("-" * 40)
        print(text[:800])
        print("-" * 40)
        
        # Print representation values of some characters
        if len(text) > 0:
            print("Unicode points of first 20 characters:")
            for c in text[:20]:
                print(f"  '{c}': U+{ord(c):04X}")

inspect_page('/Users/hussain/Documents/sijilli/docs/PDB Books/book377.pdf', 1)
inspect_page('/Users/hussain/Documents/sijilli/docs/PDB Books/book377.pdf', 2)
