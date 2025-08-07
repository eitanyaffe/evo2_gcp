import argparse
import json

def main():
    parser = argparse.ArgumentParser(description="Build a JSON configuration file for a Google Cloud Batch job.")

    # Required arguments
    parser.add_argument("--output_file_path", required=True, help="Path to save the generated JSON file.")
    parser.add_argument("--remote_path", required=True, help="The GCS bucket path (e.g., \"relman-evo2\").")
    parser.add_argument("--image_uri", required=True, help="The Docker image URI (e.g., \"gcr.io/relman-yaffe/evo2\").")
    parser.add_argument("--job_env", required=True, help="Value for the JOB environment variable.")
    parser.add_argument("--model_name_env", required=True, help="Value for the MODEL_NAME environment variable.")
    parser.add_argument("--output_type_env", default="logits", help="Output type: logits, logits_and_embedding, or embedding.")
    parser.add_argument("--embedding_layers_env", default="", help="Space-separated list of embedding layers. Required if output_type_env includes embeddings.")
    parser.add_argument("--steering_layer_env", default="", help="Layer name to apply steering vector to.")
    parser.add_argument("--steering_scales_env", default="", help="Comma-separated steering scales.")
    parser.add_argument("--run_script_path", required=True, help="Path to the execution script within the container (e.g., \"scripts/run_evo2.sh\").")

    # Optional arguments with defaults from test.json
    parser.add_argument("--machine_type", default="a3-highgpu-1g", help="The machine type.")
    parser.add_argument("--disk_size_gb", type=int, default=100, help="The boot disk size in GB.")
    parser.add_argument("--accelerator_type", default="nvidia-h100-80gb", help="The accelerator type.")
    parser.add_argument("--accelerator_count", type=int, default=1, help="The number of accelerators.")
    parser.add_argument("--provisioning_model", default="SPOT", help="The provisioning model (e.g., SPOT, STANDARD).")
    parser.add_argument("--max_retry_count", type=int, default=0, help="The maximum retry count for the task.")

    args = parser.parse_args()

    # make sure output_type_env is one of the allowed values
    if args.output_type_env not in ['logits', 'logits_and_embedding', 'embedding', 'summary_only']:
        parser.error(f"Invalid output_type_env: {args.output_type_env}. Allowed values are: logits, logits_and_embedding, embedding, summary_only.")

    # make sure embedding_layers_env is provided if output_type_env includes embeddings
    if args.output_type_env in ['logits_and_embedding', 'embedding'] and not args.embedding_layers_env:
        parser.error("--embedding_layers_env is required when output_type_env includes embeddings.")

    # Construct the command for the container
    # The script path is relative to the mount point /mnt/disks/share
    container_command = f"bash /mnt/disks/share/{args.run_script_path}"

    cuda_visible_devices = ",".join(map(str, range(args.accelerator_count)))

    job_config = {
        "taskGroups": [
            {
                "name": "gpu-task-group",
                "taskSpec": {
                    "runnables": [
                        {
                            "container": {
                                "imageUri": args.image_uri,
                                "entrypoint": "/bin/bash",
                                "commands": [
                                    "-c",
                                    container_command
                                ],
                                "options": "--workdir /mnt/disks/share"
                            }
                        }
                    ],
                    "environment": {
                        "variables": {
                            "MNT_DIR": "/mnt/disks/share",
                            "JOB": args.job_env,
                            "MODEL_NAME": args.model_name_env,
                            "OUTPUT_TYPE": args.output_type_env,
                            "EMBEDDING_LAYERS": args.embedding_layers_env if args.output_type_env in ['logits_and_embedding', 'embedding'] and args.embedding_layers_env else "",
                            "STEERING_LAYER": args.steering_layer_env,
                            "STEERING_SCALES": args.steering_scales_env,
                            "CUDA_VISIBLE_DEVICES": cuda_visible_devices
                        }
                    },
                    "volumes": [
                        {
                            "gcs": {
                                "remotePath": args.remote_path
                            },
                            "mountPath": "/mnt/disks/share"
                        }
                    ],
                    "maxRetryCount": args.max_retry_count
                },
                "taskCount": 1
            }
        ],
        "allocationPolicy": {
            "instances": [
                {
                    "installGpuDrivers": True,
                    "policy": {
                        "machineType": args.machine_type,
                        "bootDisk": {
                            "type": "pd-ssd",
                            "sizeGb": args.disk_size_gb
                        },
                        "accelerators": [
                            {
                                "type": args.accelerator_type,
                                "count": args.accelerator_count
                            }
                        ],
                        "provisioningModel": args.provisioning_model
                    }
                }
            ]
        },
        "logsPolicy": {
            "destination": "CLOUD_LOGGING"
        }
    }

    with open(args.output_file_path, 'w') as f:
        json.dump(job_config, f, indent=4)

    print(f"Successfully generated job configuration file at: {args.output_file_path}")

if __name__ == "__main__":
    main() 