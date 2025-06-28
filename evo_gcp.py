#!/usr/bin/env python3

import argparse
import os
import re
import subprocess
import sys
import signal

def parse_config_vars(config_path):
    """
    Parses a makefile-style config file and returns a dict of variables.
    It captures the comment immediately above the variable as its description.
    """
    vars = {}
    last_comment = ""
    try:
        with open(config_path, 'r') as f:
            for line in f:
                line = line.strip()

                if not line:
                    last_comment = ""  # Reset on empty lines
                    continue

                if line.startswith('#'):
                    # Capture the comment, removing '#' and leading space
                    last_comment = line.lstrip('#').strip()
                    continue

                match = re.match(r'^([A-Z_]+)\s*\??=\s*(.*)', line)
                if match:
                    key, value = match.groups()
                    vars[key] = {
                        'value': value.strip(),
                        'description': last_comment
                    }
                    last_comment = "" # Reset after use
    except FileNotFoundError:
        # Since we hard-code config.mk, this is a fatal error for the script's setup
        print(f"Error: Main config file not found at '{config_path}'", file=sys.stderr)
        print("This file is required to define available arguments.", file=sys.stderr)
        sys.exit(1)
    return vars

def run_command(command):
    cmd_str = ' '.join(command)
    print(f"Running command: {cmd_str}")
    try:
        exit_code = os.system(cmd_str)
        # os.system returns a 16-bit encoded value: high byte is signal, low byte is exit code
        if os.WIFSIGNALED(exit_code):
            sig = os.WTERMSIG(exit_code)
            print(f"Command terminated by signal {sig}", file=sys.stderr)
            sys.exit(128 + sig)
        elif os.WEXITSTATUS(exit_code) != 0:
            print(f"Command exited with code {os.WEXITSTATUS(exit_code)}", file=sys.stderr)
            sys.exit(1)
    except KeyboardInterrupt:
        print("\nInterrupted by user.", file=sys.stderr)
        sys.exit(130)

def get_make_args(args, config_vars):
    """Constructs a list of KEY=VALUE strings for make."""
    make_args = []
    # We only need the keys from the config_vars to check against args
    for key in config_vars.keys():
        arg_key = key.lower()
        if hasattr(args, arg_key) and getattr(args, arg_key) is not None:
            make_args.append(f"{key}={getattr(args, arg_key)}")
    return make_args
    
def main():
    """Main function."""
    evo_gcp_dir = os.environ.get('EVO_GCP_DIR')
    if not evo_gcp_dir:
        print("Error: The environment variable EVO_GCP_DIR is not set.", file=sys.stderr)
        print("Please set it to the root directory of the evo2_gcp project.", file=sys.stderr)
        print("For example, add this to your .zshrc or .bashrc:", file=sys.stderr)
        print("export EVO_GCP_DIR=/path/to/your/evo2_gcp", file=sys.stderr)
        sys.exit(1)

    try:
        os.chdir(evo_gcp_dir)
    except FileNotFoundError:
        print(f"Error: The directory specified by EVO_GCP_DIR does not exist: {evo_gcp_dir}", file=sys.stderr)
        sys.exit(1)

    # Hard-code the use of the main config file for variable definitions and descriptions.
    config_vars = parse_config_vars('config.mk')

    examples = """
Usage example:
  # Build the docker image
  evo_gcp docker_image

  # Set up the project bucket for the first time
  evo_gcp setup_bucket

  # Submit a job with a specific FASTA file and wait for it to complete
  evo_gcp submit --job my-first-run --input_fasta examples/gyrA_sensitive.fasta --wait

  # Download the results for a specific job
  evo_gcp download --job my-first-run
"""

    parser = argparse.ArgumentParser(
        description="A Python script for evo2_gcp.\n",
        formatter_class=argparse.RawTextHelpFormatter
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    subparsers.required = True

    # Command descriptions
    command_descriptions = {
        'docker_image': 'Builds the Docker image and pushes it to Google Container Registry (GCR).\nIt uses the IMAGE_NAME and DOCKER_IMAGE variables from your config.',
        'create_bucket': 'Creates the GCS bucket specified by BUCKET_NAME in the configured LOCATION.',
        'setup_bucket': 'A combo command that creates the bucket, uploads the model, and uploads the code.\nThis runs the `create_bucket`, `upload_model`, and `upload_code` commands in sequence.',
        'upload_model': 'Uploads the specified ML model to the GCS bucket.',
        'upload_code': 'Uploads the `scripts` and `configs` directories to the GCS bucket.',
        'upload_fasta': 'Uploads a specific FASTA file to the job directory in the GCS bucket.\nRequires --input_fasta.',
        'build_json': 'Builds the job.json configuration file for a batch job.',
        'submit': 'Submits a job to Google Cloud Batch.\nThis combines `upload_code`, `upload_fasta`, and `build_json` before submitting.\nUse --wait to block until the job completes.',
        'download': 'Downloads the output of a completed job from the GCS bucket into the local `jobs` directory.',
        'list_jobs': 'Lists all Google Cloud Batch jobs in the configured GCP location.',
        'show': 'Shows the contents of the remote job directory in the GCS bucket.'
    }

    # Dynamically add commands and their arguments
    commands = [
        'docker_image', 'create_bucket', 'upload_model', 'upload_code', 
        'upload_fasta', 'build_json', 'submit', 'download', 'list_jobs', 'show'
    ]
    
    combo_commands = {
        'setup_bucket': ['create_bucket', 'upload_model', 'upload_code']
    }
    
    all_commands = commands + list(combo_commands.keys())
    
    for cmd in all_commands:
        cmd_parser = subparsers.add_parser(
            cmd,
            help=command_descriptions.get(cmd, f'Execute the {cmd} make target.').split('\n')[0],
            description=command_descriptions.get(cmd, f'Execute the {cmd} make target.'),
            formatter_class=argparse.RawTextHelpFormatter
        )
        
        # Keep track of arguments added to this subparser to avoid conflicts
        added_args = set()

        if cmd == 'submit':
            cmd_parser.add_argument('--wait', action='store_true', help='Wait for the job to complete.')
            added_args.add('--wait')

        for var, data in config_vars.items():
            arg_name = f'--{var.lower()}'
            if arg_name not in added_args:
                help_text = data.get('description') or f"Overrides {var}."
                default_val_str = f" Default: {data.get('value')}"
                help_text += default_val_str
                cmd_parser.add_argument(arg_name, help=help_text)
                added_args.add(arg_name)
    
    # If run without arguments, print help and exit
    if len(sys.argv) == 1:
        parser.print_help(sys.stderr)
        print("\nConfiguration Arguments (from config.mk):", file=sys.stderr)
        
        if config_vars:
            # Evaluate default values by calling make for each variable
            evaluated_defaults = {}
            for var in config_vars.keys():
                try:
                    # Use the generic 'print-VAR' rule now in the makefile
                    command = ['make', '-s', f'print-{var}']
                    result = subprocess.run(
                        command,
                        capture_output=True,
                        text=True,
                        check=True,
                        cwd=evo_gcp_dir 
                    )
                    evaluated_defaults[var] = result.stdout.strip()
                except (subprocess.CalledProcessError, FileNotFoundError):
                    # If make fails, fall back to the raw value from the config file
                    evaluated_defaults[var] = config_vars[var].get('value', 'N/A')

            # Calculate padding for alignment
            max_len = max(len(f'--{var.lower()}') for var in config_vars.keys())
            for var, data in config_vars.items():
                arg_name = f'--{var.lower()}'
                description = data.get('description', 'No description available.')
                default_val = evaluated_defaults.get(var, 'N/A')
                print(f"  {arg_name:<{max_len + 2}} {description} (Default: {default_val})", file=sys.stderr)

        print(examples, file=sys.stderr)
        sys.exit(0)

    args = parser.parse_args()
    make_args = get_make_args(args, config_vars)
    
    if args.command in combo_commands:
        for target in combo_commands[args.command]:
            run_command(['make', target] + make_args)
    else:
        command_to_run = ['make', args.command] + make_args
        if args.command == 'submit' and args.wait:
            command_to_run.append('WAIT=true')
        run_command(command_to_run)

if __name__ == "__main__":
    main() 