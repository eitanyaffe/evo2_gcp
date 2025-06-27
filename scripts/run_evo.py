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
    parser.add_argument('--include_embedding', action='store_true',
                        help="Include embeddings in the output. Logits are always included. "
                             "Embeddings will be from the 'final_norm' layer.")
    parser.add_argument('--embedding_layers', nargs='+', default=None,
                        help="List of layer names for embedding extraction. "
                             "Required if --include_embedding is set. "
                             "Example: 'blocks.28.mlp.l3' or 'final_norm'")

    args = parser.parse_args()

    if args.include_embedding and not args.embedding_layers:
        parser.error("--embedding_layers is required when --include_embedding is set.")

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

    print(f"processing {len(seqs_to_process)} sequences...")

    # Determine if embeddings are needed
    return_embeddings = args.include_embedding

    all_logits = []
    all_embeddings = {} # Dict to store embeddings layer_name -> list_of_tensors

    for i in range(len(seqs_to_process)):
        seq_id = seq_ids[i]
        sequence = seqs_to_process[i]
        print(f"  processing sequence: {seq_id} (length: {len(sequence)})")

        # Tokenize the single sequence
        # The evo2_model.tokenizer.tokenize method returns a list of token IDs.
        # For individual processing or to match `forward`'s expected input, we tokenize one by one.
        token_ids = evo_model.tokenizer.tokenize(sequence) # Tokenize the sequence into a list of token IDs
        # Convert to 2D tensor [1, sequence_length], set dtype to torch.int, and move to the model's device
        input_ids = torch.tensor(token_ids, dtype=torch.int).unsqueeze(0).to('cuda:0')

        logits, embeddings = evo_model.forward(
            input_ids,
            return_embeddings=return_embeddings,
            layer_names=args.embedding_layers if return_embeddings else None
        )

        # Logits are always processed
        # Detach logits from the graph, move to CPU, convert to float32, then to NumPy
        all_logits.append(logits[0].detach().cpu().to(torch.float32).numpy())
        print(f"    logits shape: {logits[0].shape}")

        if return_embeddings and embeddings:
            for layer_name, emb_tensor in embeddings.items():
                if layer_name not in all_embeddings:
                    all_embeddings[layer_name] = []
                # Detach embeddings, move to CPU, convert to float32, then to NumPy
                all_embeddings[layer_name].append(emb_tensor.detach().cpu().to(torch.float32).numpy())
                print(f"    embeddings from {layer_name} shape: {emb_tensor.shape}")
    
    # Create output directory if it doesn't exist
    os.makedirs(args.output_dir, exist_ok=True)

    # Save outputs

    output_basename = os.path.splitext(os.path.basename(args.fasta_file))[0]

    with open(os.path.join(args.output_dir, f"{output_basename}_processed_ids.txt"), 'w') as f:
        for seq_id in seq_ids:
            f.write(f"{seq_id}\n")

    # Logits are always saved
    if all_logits:
        # Saving as individual npy files per sequence for easier R import if sequences are variable length
        for idx, logit_arr in enumerate(all_logits):
            seq_id_safe_filename = "".join(c if c.isalnum() else "_" for c in seq_ids[idx]) # make filename safe
            logit_output_path = os.path.join(args.output_dir, f"{output_basename}_{seq_id_safe_filename}_logits.npy")
            np.save(logit_output_path, logit_arr)
            print(f"  logits for {seq_ids[idx]} saved to {logit_output_path}")

    if args.include_embedding and all_embeddings:
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