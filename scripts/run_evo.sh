#!/bin/sh

set -e -o pipefail
trap 'echo "Command failed. Exiting."; exit 1' ERR

# mounted bucket
BASE_DIR=/mnt/disks/share

SCRIPTS_DIR=$BASE_DIR/scripts
JOB_DIR=$BASE_DIR/jobs/$JOB

OUTPUT_DIR=$JOB_DIR/output

CHECKPOINT_DIR=$BASE_DIR/models
CHECKPOINT_PATH=$CHECKPOINT_DIR/$MODEL_NAME.pt

FASTA_FILE=$JOB_DIR/input.fasta

echo "Running job: $JOB"
echo "Input fasta file: $FASTA_FILE"
echo "Output directory: $OUTPUT_DIR"
echo "Scripts directory: $SCRIPTS_DIR"
echo "Model name: $MODEL_NAME"
echo "Checkpoint path: $CHECKPOINT_PATH"
echo "Output types: $OUTPUT_TYPES"

mkdir -p $OUTPUT_DIR

python3 $SCRIPTS_DIR/run_evo.py \
	--fasta_file $FASTA_FILE \
	--model_name $MODEL_NAME \
	--checkpoint_path $CHECKPOINT_PATH \
	--output_dir $OUTPUT_DIR \
	--output_types $OUTPUT_TYPES
