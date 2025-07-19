#!/usr/bin/env python3
import sys
import csv
import argparse
from collections import defaultdict
from Bio import SeqIO
from Bio.Seq import Seq

def read_codon_table(codon_table_file):
    """read codon table and return codon->aa mapping"""
    with open(codon_table_file, 'r') as f:
        reader = csv.DictReader(f, delimiter='\t')
        return {row['codon']: row['aa'] for row in reader}

def read_fasta(fasta_file, target_id):
    """read sequence from fasta file by identifier"""
    sequences = SeqIO.parse(fasta_file, "fasta")
    
    for record in sequences:
        if record.id == target_id:
            return record.id, str(record.seq)
    
    # sequence not found
    print(f"error: sequence with identifier '{target_id}' not found in fasta file", file=sys.stderr)
    sys.exit(1)

def generate_all_codons():
    """generate all 64 possible codons"""
    bases = ['A', 'T', 'G', 'C']
    codons = []
    for b1 in bases:
        for b2 in bases:
            for b3 in bases:
                codons.append(b1 + b2 + b3)
    return codons

def main():
    parser = argparse.ArgumentParser(description='Generate codon variants for a specific position')
    parser.add_argument('--fasta', '-f', required=True, help='Input FASTA file')
    parser.add_argument('--codon-table', '-c', required=True, help='Codon table file')
    parser.add_argument('--aa-coord', '-a', type=int, required=True, help='Amino acid coordinate (1-based)')
    parser.add_argument('--seq-id', '-s', required=True, help='Sequence identifier')
    parser.add_argument('--output-fasta', '-o', required=True, help='Output FASTA file')
    parser.add_argument('--output-codon-table', '-v', required=True, help='Output codon file (original codon)')
    
    args = parser.parse_args()
    
    # read codon table
    codon_to_aa = read_codon_table(args.codon_table)
    
    # read input fasta
    header, sequence = read_fasta(args.fasta, args.seq_id)
    
    # calculate nucleotide position (1-based aa coord to 0-based nucleotide)
    nt_start = (args.aa_coord - 1) * 3
    nt_end = nt_start + 3
    
    # check bounds
    if nt_end > len(sequence):
        print(f"error: position {args.aa_coord} is beyond sequence length", file=sys.stderr)
        sys.exit(1)
    
    # print sequence length in nt and aa
    print(f"sequence length: {len(sequence)} nt, {len(sequence) // 3} aa")

    # extract and print original codon as sanity check
    original_codon = sequence[nt_start:nt_end]
    original_aa = codon_to_aa.get(original_codon, 'X')

    print(f"original codon at position {args.aa_coord}: {original_codon} -> {original_aa}")

    # write original codon to output file
    print(f"writing original codon to {args.output_codon_table}")
    with open(args.output_codon_table, 'w') as out:
        out.write(f"coord\tcodon\taa\n")
        out.write(f"{args.aa_coord}\t{original_codon}\t{original_aa}\n")
    
    # get all possible codons
    all_codons = generate_all_codons()
    
    print(f"Generating file: {args.output_fasta}")
    # generate variants
    with open(args.output_fasta, 'w') as out:
        for codon in all_codons:
            aa = codon_to_aa.get(codon, 'X')  # X for unknown

            # replace stop codon symbol (*) with Z
            aa = 'Z' if aa == '*' else aa
            
            # create forward variant
            variant_seq = sequence[:nt_start] + codon + sequence[nt_end:]
            out.write(f">{args.aa_coord}_{aa}_{codon}_P\n")
            out.write(f"{variant_seq}\n")
            
            # create reverse complement variant
            rc_seq = str(Seq(variant_seq).reverse_complement())
            out.write(f">{args.aa_coord}_{aa}_{codon}_M\n")
            out.write(f"{rc_seq}\n")

if __name__ == "__main__":
    main() 