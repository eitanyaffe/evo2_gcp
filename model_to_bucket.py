import os
import argparse
from huggingface_hub import snapshot_download
from google.cloud import storage
from pathlib import Path
import signal
import subprocess
import sys

def kill_child_processes(signum, frame):
    """Signal handler to kill all child processes."""
    print("\nInterrupt received, killing child processes...", file=sys.stderr)
    try:
        parent_pid = os.getpid()
        child_pids = subprocess.check_output(["pgrep", "-P", str(parent_pid)])
        for pid_str in child_pids.split():
            pid = int(pid_str)
            # Kill the entire process group of the child
            os.killpg(os.getpgid(pid), signal.SIGKILL)
    except (subprocess.CalledProcessError, ProcessLookupError, PermissionError):
        # Errors can happen if children exit before we kill them
        pass
    print("Cleanup complete. Exiting.", file=sys.stderr)
    sys.exit(130)

def download_model(model_name: str, local_dir: str):
    print(f"Downloading model '{model_name}' to '{local_dir}'...")
    snapshot_download(repo_id=model_name, local_dir=local_dir, resume_download=True)
    print("Download complete.")

def upload_directory_to_gcs(local_dir: str, bucket_name: str, gcs_prefix: str = ""):
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    local_path = Path(local_dir)

    print(f"Uploading contents of '{local_dir}' to 'gs://{bucket_name}/{gcs_prefix}'...")
    for path in local_path.rglob("*"):
        if path.is_file():
            rel_path = path.relative_to(local_path)
            blob_path = f"{gcs_prefix}/{rel_path}".strip("/")
            blob = bucket.blob(blob_path)
            blob.upload_from_filename(str(path))
            print(f"Uploaded: gs://{bucket_name}/{blob_path}")
    print("Upload complete.")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_name", required=True, help="Hugging Face model name, e.g., 'arcinstitute/evo2_7b'")
    parser.add_argument("--bucket", required=True, help="GCS bucket name")
    parser.add_argument("--gcs_path", default="", help="Path prefix within the GCS bucket")
    parser.add_argument("--tmp_dir", default="hf_model_tmp", help="Local temp directory to store the model")
    args = parser.parse_args()

    # Register the signal handler for Ctrl+C
    signal.signal(signal.SIGINT, kill_child_processes)

    download_model(args.model_name, args.tmp_dir)
    upload_directory_to_gcs(args.tmp_dir, args.bucket, args.gcs_path)

if __name__ == "__main__":
    main()
