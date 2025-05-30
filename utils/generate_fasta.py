import random
import argparse

def generate_random_dna(length):
    return ''.join(random.choices('ACGT', k=length))

def write_fasta(filename, read_count, read_length):
    with open(filename, 'w') as f:
        for i in range(read_count):
            seq = generate_random_dna(read_length)
            f.write(f">read_{i+1}\n{seq}\n")

def main():
    parser = argparse.ArgumentParser(description="Generate a FASTA file with random DNA reads.")
    parser.add_argument("--output_file", help="Output FASTA filename")
    parser.add_argument("--read_count", type=int, help="Number of reads to generate")
    parser.add_argument("--read_length", type=int, help="Length of each read")
    
    args = parser.parse_args()

    write_fasta(args.output_file, args.read_count, args.read_length)
    print(f"Wrote {args.read_count} reads of length {args.read_length} to {args.output_file}")

if __name__ == "__main__":
    main()
