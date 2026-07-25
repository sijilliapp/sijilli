with open('/Users/hussain/Documents/sijilli/docs/PDB Books/book377.pdf', 'rb') as f:
    data = f.read()

has_to_unicode = b'/ToUnicode' in data
print(f"Has /ToUnicode: {has_to_unicode}")

# Count fonts
font_count = data.count(b'/Font')
print(f"Occurrences of '/Font': {font_count}")

# Check for '/Encrypt'
print(f"Is Encrypted (via /Encrypt): {b'/Encrypt' in data}")
