import struct
import sys

def inspect_pdb(file_path):
    print(f"Analyzing: {file_path}")
    with open(file_path, 'rb') as f:
        header = f.read(78)
        if len(header) < 78:
            print("File too short to be a valid PDB.")
            return
        
        # Unpack header fields
        # Name: 32s
        # Attributes: H
        # Version: H
        # Creation Date: I
        # Modification Date: I
        # Backup Date: I
        # Modification Number: I
        # App Info: I
        # Sort Info: I
        # Type: 4s
        # Creator: 4s
        # Unique ID Seed: I
        # Next Record List ID: I
        # Num Records: H
        
        fields = struct.unpack('>32sHHIIIIII4s4sIIH', header)
        name = fields[0].decode('latin-1').strip('\x00')
        attributes = fields[1]
        version = fields[2]
        c_time = fields[3]
        m_time = fields[4]
        b_time = fields[5]
        mod_num = fields[6]
        app_info = fields[7]
        sort_info = fields[8]
        type_code = fields[9].decode('latin-1')
        creator_code = fields[10].decode('latin-1')
        num_records = fields[13]
        
        print(f"  Name: {name}")
        print(f"  Type: {type_code}")
        print(f"  Creator: {creator_code}")
        print(f"  Version: {version}")
        print(f"  Num Records: {num_records}")
        
        # Read the first few record offsets
        record_list_size = num_records * 8
        record_list_data = f.read(record_list_size)
        
        if len(record_list_data) >= 8:
            first_offset = struct.unpack('>I', record_list_data[0:4])[0]
            print(f"  First Record Offset: {first_offset}")
            
            # Read first record's metadata/header
            f.seek(first_offset)
            first_record_data = f.read(16)
            print(f"  First Record Hex (first 16 bytes): {first_record_data.hex()}")

inspect_pdb('/Users/hussain/Documents/sijilli/docs/PDB Books/استفتاءات الكنز.pdb')
print("-" * 50)
inspect_pdb('/Users/hussain/Documents/sijilli/docs/PDB Books/متون الحديث.pdb')
