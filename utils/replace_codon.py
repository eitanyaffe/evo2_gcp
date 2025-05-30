import argparse


def read_fasta(filepath):
    with open(filepath, "r") as f:
        lines = f.readlines()
    header = lines[0].strip()
    sequence = "".join(line.strip() for line in lines[1:])
    return header, sequence.upper()


def write_fasta(header, sequence, output_file):
    with open(output_file, "w") as f:
        f.write(f"{header}\n")
        for i in range(0, len(sequence), 70):
            f.write(sequence[i:i + 70] + "\n")


def replace_codon(fasta_file, aa_position, new_codon, output_file):
    header, seq = read_fasta(fasta_file)

    if len(seq) % 3 != 0:
        raise ValueError("Sequence length is not divisible by 3. Not a valid CDS.")

    codon_index = aa_position - 1  # 0-based
    nt_index = codon_index * 3
    original_codon = seq[nt_index:nt_index + 3]

    if len(original_codon) != 3:
        raise ValueError(f"Incomplete codon at position {aa_position}.")

    print(f"Original codon at position {aa_position}: {original_codon}")
    print(f"New codon: {new_codon}")

    new_seq = seq[:nt_index] + new_codon + seq[nt_index + 3:]
    write_fasta(header, new_seq, output_file)

    print(f"Modified sequence written to: {output_file}")


def main():
    parser = argparse.ArgumentParser(description="Replace a codon at a given amino acid position in a FASTA sequence.")
    parser.add_argument("--fasta_file", required=True, help="Input FASTA file with a single CDS.")
    parser.add_argument("--aa_position", type=int, required=True, help="Amino acid coordinate (1-based).")
    parser.add_argument("--new_codon", required=True, help="New codon to insert (e.g. GGA).")
    parser.add_argument("--output_file", required=True, help="Output FASTA file.")

    args = parser.parse_args()

    new_codon = args.new_codon.upper()
    if len(new_codon) != 3 or any(base not in "ACGT" for base in new_codon):
        parser.error("New codon must be exactly 3 bases from A/C/G/T.")

    replace_codon(args.fasta_file, args.aa_position, new_codon, args.output_file)


if __name__ == "__main__":
    main()
