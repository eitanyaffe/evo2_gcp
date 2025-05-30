# Filename: display_char_tokens.py

# Note: Ensure the 'vortex' package (containing vortex.model.tokenizer)
# is in your PYTHONPATH, or run this script from a directory
# where 'vortex.model.tokenizer' can be imported (e.g., the workspace root /Users/eitany/work/git/evo2).
import sys # Added to handle command-line arguments
from vortex.model.tokenizer import CharLevelTokenizer

def get_char_representation(char_code: int) -> str:
    """Provides a display-friendly string for a character code."""
    # Handle common escape sequences
    if char_code == 9:
        return "\\t"  # Tab
    elif char_code == 10:
        return "\\n"  # Newline
    elif char_code == 13:
        return "\\r"  # Carriage Return
    # Standard printable ASCII characters
    elif 32 <= char_code <= 126:
        return chr(char_code)
    # For other control characters or extended ASCII, use a placeholder
    else:
        return f"ASCII_{char_code}"


def main():
    if len(sys.argv) != 2:
        print("usage: python save_tokens.py <output_filename>", file=sys.stderr)
        sys.exit(1)

    output_filename = sys.argv[1]

    # Instantiate the CharLevelTokenizer.
    # The vocab_size parameter (e.g., 256) is primarily for the clamp function
    # in decode_token and to indicate the expected range.
    # The tokenize() method itself for CharLevelTokenizer directly uses ASCII/byte values.
    tokenizer = CharLevelTokenizer(vocab_size=256)

    try:
        with open(output_filename, 'w') as f_out:
            f_out.write("Token_Index\tCharacter\n")
            f_out.write("----------- الجامعات الجامعات الجامعات الجامعات الجامعات الجامعات الجامعات\t----------\n")

            # Iterate through all possible byte values (0-255).
            for i in range(256):
                char_to_tokenize = chr(i)
                
                # Tokenize the character.
                # For CharLevelTokenizer, tokenize(single_char_string) returns a list
                # containing the single ASCII/byte value of that character.
                token_list = tokenizer.tokenize(char_to_tokenize)
                
                # The token index for a single character chr(i) will be i.
                # Adjusting to be 1-indexed by adding 1.
                token_index = token_list[0] + 1
                
                display_char = get_char_representation(i)
                
                f_out.write(f"{token_index}\t{display_char}\n")
        print(f"token table saved to {output_filename}")
    except IOError as e:
        print(f"error writing to file {output_filename}: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main() 