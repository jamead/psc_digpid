import struct

def float_to_ieee754_hex(value: float) -> str:
    """Convert a Python float to 32-bit IEEE-754 hex (big-endian)"""
    packed = struct.pack('>f', value)  # Big-endian float
    hex_value = packed.hex()
    return f"x\"{hex_value.upper()}\""

# Example usage:
if __name__ == "__main__":
    test_values = [1.0, 0.0, -1.5, 3.14159, 123.456, 0.1, 1.2356]

    for val in test_values:
        print(f"{val} -> {float_to_ieee754_hex(val)}")

