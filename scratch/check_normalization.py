import unicodedata

text = "ﻛﺘﺎﺏ ﺍﻟﻤﻜﺎﺳﺐ"
normalized = unicodedata.normalize('NFKC', text)

print("Original:")
for c in text:
    print(f"  '{c}': U+{ord(c):04X}")

print("\nNormalized with NFKC:")
for c in normalized:
    print(f"  '{c}': U+{ord(c):04X}")
    
print(f"\nString match: {normalized == 'كتاب المكاسب'}")
