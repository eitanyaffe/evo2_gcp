#!/bin/sh

set -e -o pipefail
trap 'echo "Command failed. Exiting."; exit 1' ERR

SCRIPTS_DIR=$MNT_DIR/scripts
JOB_DIR=$MNT_DIR/jobs/$JOB

OUTPUT_DIR=$JOB_DIR/output

CHECKPOINT_DIR=$MNT_DIR/models
CHECKPOINT_PATH=$CHECKPOINT_DIR/$MODEL_NAME.pt

FASTA_FILE=$JOB_DIR/input.fasta

echo "Running job: $JOB"
echo "Mount directory: $MNT_DIR"
echo "Input fasta file: $FASTA_FILE"
echo "Output directory: $OUTPUT_DIR"
echo "Scripts directory: $SCRIPTS_DIR"
echo "Model name: $MODEL_NAME"
echo "Checkpoint path: $CHECKPOINT_PATH"
echo "Include embedding: $INCLUDE_EMBEDDING"
echo "Embedding layers: $EMBEDDING_LAYERS"
echo "CUDA_VISIBLE_DEVICES: $CUDA_VISIBLE_DEVICES"
mkdir -p $OUTPUT_DIR

# Construct arguments for run_evo.py
SCRIPT_ARGS="--fasta_file $FASTA_FILE --model_name $MODEL_NAME --checkpoint_path $CHECKPOINT_PATH --output_dir $OUTPUT_DIR"

if [ "$INCLUDE_EMBEDDING" = "true" ]; then
    SCRIPT_ARGS="$SCRIPT_ARGS --include_embedding"
    if [ -n "$EMBEDDING_LAYERS" ]; then
        SCRIPT_ARGS="$SCRIPT_ARGS --embedding_layers $EMBEDDING_LAYERS"
    fi
fi

echo "initial CUDA_VISIBLE_DEVICES: $CUDA_VISIBLE_DEVICES"

python3 $SCRIPTS_DIR/run_evo.py $SCRIPT_ARGS 2>&1 | tee $OUTPUT_DIR/run_evo.log
