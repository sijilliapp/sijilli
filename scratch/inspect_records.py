import struct

def inspect_records(file_path):
    print(f"File: {file_path}")
    with open(file_path, 'rb') as f:
        # Header is 78 bytes
        header = f.read(78)
        fields = struct.unpack('>32sHHIIIIII4s4sIIH', header)
        num_records = fields[13]
        
        # Read records info
        offsets = []
        for i in range(num_records):
            record_entry = f.read(8)
            offset, attrs = struct.unpack('>IB', record_entry[:5])
            offsets.append(offset)
            
        print(f"Found {num_records} records.")
        
        # Print offsets and sizes of first few records
        for i in range(min(num_records, 10)):
            start = offsets[i]
            end = offsets[i+1] if i + 1 < num_records else None
            f.seek(start)
            if end:
                size = end - start
                data = f.read(size)
            else:
                data = f.read(100)
                size = "unknown"
            
            print(f"Record {i}: Offset={start}, Size={size}")
            print(f"  Hex:  {data[:32].hex()}")
            # Try to decode as ascii or utf-8, ignoring errors
            text_preview = data[:64].decode('utf-8', errors='ignore').replace('\n', ' ')
            print(f"  Text: {text_preview}")
            arabic_preview = data[:64].decode('utf-16-be', errors='ignore').replace('\n', ' ')
            print(f"  Text (UTF-16BE): {arabic_preview}")

inspect_records('/Users/hussain/Documents/sijilli/docs/PDB Books/استفتاءات الكنز.pdb')
