import argparse
import torch
import sys

num_devices = torch.cuda.device_count()
print(f"Found {num_devices} CUDA devices:")
for i in range(num_devices):
    print(f"  Device {i}: {torch.cuda.get_device_name(i)}")

import os
import numpy as np # Add numpy import here
import json
import torch.nn.functional as F

from evo2 import Evo2

def read_fasta(fasta_file):
    """Reads a FASTA file and returns a dictionary of sequences."""
    sequences = {}
    current_seq_id = None
    with open(fasta_file, 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('>'):
                current_seq_id = line[1:]
                sequences[current_seq_id] = ''
            elif current_seq_id:
                sequences[current_seq_id] += line
    return sequences

def read_query_table(query_table_file):
    """Reads query table with seq_id, start, end columns (1-indexed, inclusive)."""
    print(f"reading query table from {query_table_file}")
    query_data = {}
    with open(query_table_file, 'r') as f:
        header = f.readline().strip()
        print(f"query table header: {header}")
        if header != "seq_id\tstart\tend":
            raise ValueError(f"expected header 'seq_id\\tstart\\tend', got '{header}'")
        
        line_num = 1
        for line in f:
            line_num += 1
            line = line.strip()
            if not line:
                continue
            parts = line.split('\t')
            if len(parts) != 3:
                raise ValueError(f"line {line_num}: expected 3 columns, got {len(parts)}")
            
            seq_id = parts[0]
            try:
                start = int(parts[1])
                end = int(parts[2])
            except ValueError as e:
                raise ValueError(f"line {line_num}: invalid coordinates - {e}")
            
            if start < 1 or end < 1 or start > end:
                raise ValueError(f"line {line_num}: invalid coordinates start={start}, end={end}")
            
            query_data[seq_id] = (start, end)
            print(f"  {seq_id}: positions {start}-{end}")
    
    print(f"loaded {len(query_data)} entries from query table")
    return query_data

def main():
    parser = argparse.ArgumentParser(description="Run Evo2 model on sequences.")
    parser.add_argument('--fasta_file', type=str, required=True,
                        help="Path to the input FASTA file.")
    parser.add_argument('--model_name', type=str, default='evo2_7b',
                        help=f"Name of the Evo2 model to use. Defaults to 'evo2_7b'. ")
    parser.add_argument('--checkpoint_path', type=str, default=None,
                        help="Path to a local checkpoint file. If not provided, "
                             "the script will attempt to download from HuggingFace.")
    parser.add_argument('--output_dir', type=str, default='.',
                        help="Directory to save the output. Defaults to current directory.")
    parser.add_argument('--output_type', type=str, choices=['logits', 'logits_and_embedding', 'embedding', 'summary_only'], 
                        default='logits',
                        help="Type of output to generate: 'logits' (logits only), "
                             "'logits_and_embedding' (both logits and embeddings), "
                             "'embedding' (embeddings only), or 'summary_only' (summary table only). "
                             "Summary table is always included.")
    parser.add_argument('--embedding_layers', nargs='+', default=None,
                        help="List of layer names for embedding extraction. "
                             "Required if output_type includes embeddings. "
                             "Example: 'blocks.28.mlp.l3' or 'final_norm'")
    parser.add_argument('--query_table', type=str, default=None,
                        help="Optional TSV file with seq_id, start, end columns (1-indexed, inclusive). "
                             "Only affects detailed output - restricts logits and embeddings to specified ranges.")

    args = parser.parse_args()

    if args.output_type in ['logits_and_embedding', 'embedding'] and not args.embedding_layers:
        parser.error("--embedding_layers is required when output_type includes embeddings.")

    # read query table if provided
    query_data = None
    if args.query_table:
        query_data = read_query_table(args.query_table)

    print(f"loading Evo2 model: {args.model_name}")
    evo_model = Evo2(model_name=args.model_name, local_path=args.checkpoint_path)
    print("model loaded.")

    print(f"reading sequences from {args.fasta_file}")
    sequences_dict = read_fasta(args.fasta_file)
    if not sequences_dict:
        print(f"no sequences found in {args.fasta_file}")
        return
    
    seq_ids = list(sequences_dict.keys())
    seqs_to_process = list(sequences_dict.values())

    # create default query table if not provided
    if not query_data:
        print("no query table provided, using full sequences")
        query_data = {}
        for seq_id, sequence in sequences_dict.items():
            query_data[seq_id] = (1, len(sequence))

    # verify all query sequences exist
    for seq_id in query_data:
        if seq_id not in sequences_dict:
            raise ValueError(f"query table references missing sequence: {seq_id}")

    print(f"processing {len(seqs_to_process)} sequences...")

    # determine what outputs are needed
    include_logits = args.output_type in ['logits', 'logits_and_embedding']
    include_embeddings = args.output_type in ['logits_and_embedding', 'embedding']

    all_logits = []
    all_embeddings = {} # Dict to store embeddings layer_name -> list_of_tensors
    summary_data = [] # List of (seq_id, start, end, total_log_likelihood)

    for i in range(len(seqs_to_process)):
        seq_id = seq_ids[i]
        sequence = seqs_to_process[i]
        print(f"  processing sequence: {seq_id} (length: {len(sequence)})")

        # verify query range is valid
        if seq_id in query_data:
            start, end = query_data[seq_id]
            if start < 1 or end > len(sequence) or start > end:
                raise ValueError(f"query range {start}-{end} out of bounds for sequence {seq_id} (length {len(sequence)})")

        # Tokenize the single sequence
        # The evo2_model.tokenizer.tokenize method returns a list of token IDs.
        # For individual processing or to match `forward`'s expected input, we tokenize one by one.
        token_ids = evo_model.tokenizer.tokenize(sequence) # Tokenize the sequence into a list of token IDs
        # Convert to 2D tensor [1, sequence_length], set dtype to torch.int, and move to the model's device
        input_ids = torch.tensor(token_ids, dtype=torch.int).unsqueeze(0).to('cuda:0')

        logits, embeddings = evo_model.forward(
            input_ids,
            return_embeddings=include_embeddings,
            layer_names=args.embedding_layers if include_embeddings else None
        )

        # calculate total log-likelihood for summary (next-token prediction)
        target_ids = input_ids[:, 1:].long()  # shape: [1, L-1], convert to int64 for gather()
        pred_logits = logits[0][:, :-1, :]     # shape: [1, L-1, V] to match targets
        
        # compute log-probs using log-softmax
        log_probs = F.log_softmax(pred_logits, dim=-1)
        
        # gather log-likelihoods for the true next tokens
        log_likelihoods = log_probs.gather(dim=2, index=target_ids.unsqueeze(-1)).squeeze(-1)  # shape: [1, L-1]
        
        # sum for total log-likelihood
        total_log_likelihood = log_likelihoods.to(torch.float32).sum().item()

        # get query range for this sequence
        start, end = query_data.get(seq_id, (1, len(sequence)))
        summary_data.append((seq_id, start, end, total_log_likelihood))

        # subset logits and embeddings to query range (convert to 0-indexed)
        query_start_idx = start - 1
        query_end_idx = end  # end is inclusive in 1-indexed, so this works for slicing

        # save logits if requested
        if include_logits:
            # Detach logits from the graph, move to CPU, convert to float32, then to NumPy
            query_logits = logits[0][:, query_start_idx:query_end_idx, :].detach().cpu().to(torch.float32).numpy()
            all_logits.append(query_logits)

        if include_embeddings and embeddings:
            for layer_name, emb_tensor in embeddings.items():
                if layer_name not in all_embeddings:
                    all_embeddings[layer_name] = []
                # Detach embeddings, move to CPU, convert to float32, then to NumPy
                query_embeddings = emb_tensor[query_start_idx:query_end_idx, :].detach().cpu().to(torch.float32).numpy()
                all_embeddings[layer_name].append(query_embeddings)
                print(f"    embeddings from {layer_name} shape: {query_embeddings.shape} (query range {start}-{end})")
    
    # Create output directory if it doesn't exist
    os.makedirs(args.output_dir, exist_ok=True)

    # Save outputs
    output_basename = os.path.splitext(os.path.basename(args.fasta_file))[0]

    with open(os.path.join(args.output_dir, f"{output_basename}_processed_ids.txt"), 'w') as f:
        for seq_id in seq_ids:
            f.write(f"{seq_id}\n")

    # save summary table
    summary_output_path = os.path.join(args.output_dir, f"{output_basename}_summary.txt")
    with open(summary_output_path, 'w') as f:
        f.write("seq_id\tstart\tend\ttotal_log_likelihood\n")
        for seq_id, start, end, total_log_lik in summary_data:
            f.write(f"{seq_id}\t{start}\t{end}\t{total_log_lik:.6f}\n")
    print(f"summary table saved to {summary_output_path}")

    # save logits if requested
    if include_logits and all_logits:
        # Saving as individual npy files per sequence for easier R import if sequences are variable length
        for idx, logit_arr in enumerate(all_logits):
            seq_id_safe_filename = "".join(c if c.isalnum() else "_" for c in seq_ids[idx]) # make filename safe
            logit_output_path = os.path.join(args.output_dir, f"{output_basename}_{seq_id_safe_filename}_logits.npy")
            np.save(logit_output_path, logit_arr)
            print(f"  logits for {seq_ids[idx]} saved to {logit_output_path}")

    if include_embeddings and all_embeddings:
        for layer_name, layer_embs_list in all_embeddings.items():
            # Saving as individual npy files per sequence
            safe_layer_name = layer_name.replace('.', '_')
            for idx, emb_arr in enumerate(layer_embs_list):
                seq_id_safe_filename = "".join(c if c.isalnum() else "_" for c in seq_ids[idx])
                emb_output_path = os.path.join(args.output_dir, f"{output_basename}_{seq_id_safe_filename}_embeddings_{safe_layer_name}.npy")
                np.save(emb_output_path, emb_arr)
                print(f"  embeddings from {layer_name} for {seq_ids[idx]} saved to {emb_output_path}")

    print("processing complete.")

if __name__ == "__main__":
    main() 