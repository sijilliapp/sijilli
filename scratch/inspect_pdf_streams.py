import re
import zlib

def inspect_pdf_streams(file_path):
    print(f"Reading: {file_path}")
    with open(file_path, 'rb') as f:
        data = f.read()
    
    # Let's find streams
    # Stream format: stream\r?\n(bytes)endstream
    stream_pattern = re.compile(b'stream[\r\n]+(.*?)(?:[\r\n]+)?endstream', re.DOTALL)
    streams = stream_pattern.findall(data)
    print(f"Found {len(streams)} streams in PDF.")
    
    decompressed_count = 0
    for idx, stream in enumerate(streams):
        try:
            decompressed = zlib.decompress(stream)
            decompressed_count += 1
            # Search for text operator like Tj or TJ (which holds text in PDF)
            if b'Tj' in decompressed or b'TJ' in decompressed:
                print(f"\nStream {idx} (Decompressed size: {len(decompressed)} bytes):")
                # Print hex and try to show text preview
                print(f"  First 200 bytes of stream: {decompressed[:200]}")
                
                # Check for brackets like (string) or <hex_string>
                # Let's try to extract text inside parentheses (which is standard PDF text)
                matches_paren = re.findall(b'\((.*?)\)', decompressed)
                if matches_paren:
                    preview = b" ".join(matches_paren[:5])
                    print(f"  Parentheses text preview: {preview.decode('utf-8', errors='ignore')}")
                    # Try other encodings
                    print(f"  Parentheses text preview (cp1256): {preview.decode('cp1256', errors='ignore')}")
                
                # Check for hex strings inside angle brackets like <00410042> (often UTF-16BE in PDFs)
                matches_hex = re.findall(b'<([0-9a-fA-F]+)>', decompressed)
                if matches_hex:
                    hex_data = b"".join(matches_hex[:5])
                    try:
                        byte_data = bytes.fromhex(hex_data.decode('ascii'))
                        print(f"  Hex text preview (decoded UTF-16BE): {byte_data.decode('utf-16-be', errors='ignore')}")
                    except Exception as e:
                        print(f"  Hex decoding failed: {e}")
                
                if decompressed_count >= 3:
                    break
        except Exception as e:
            # Not all streams are zlib compressed or they might be images/fonts
            pass
            
inspect_pdf_streams('/Users/hussain/Documents/sijilli/docs/PDB Books/book377.pdf')
