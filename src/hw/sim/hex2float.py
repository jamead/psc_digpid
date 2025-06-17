import struct
import sys

def ieee754_hex_to_float(hex_str: str) -> float:
    """
    Convert IEEE-754 32-bit hex string (e.g., '3F800000') to Python float.
    Accepts optional 'x"' wrapper or spaces.
    """
    hex_str = hex_str.strip().replace("x", "").replace('"', "").replace("X", "")

    if len(hex_str) != 8:
        raise ValueError("Hex string must be exactly 8 characters long (32-bit IEEE-754 float)")

    bytes_val = bytes.fromhex(hex_str)
    return struct.unpack('>f', bytes_val)[0]

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python hex_to_float.py <hex_value>")
        print('Example: python hex_to_float.py x"3F800000"')
        sys.exit(1)

    hex_input = sys.argv[1]
    try:
        float_value = ieee754_hex_to_float(hex_input)
        print(f"{hex_input} -> {float_value}")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

