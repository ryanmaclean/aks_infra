#!/usr/bin/env python3
"""Datadog Helm installation for AKS."""

import os
import subprocess
import sys
from pathlib import Path

# Configuration
NAMESPACE = "datadog"
RELEASE_NAME = "datadog"
CHART_VERSION = "3.80.0"
AGENT_VERSION = "7.60.0"
CLUSTER_NAME = "aks-cluster"
SITE = "datadoghq.com"
TIMEOUT = "10m"


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    """Run a command and return the result."""
    print(f"  $ {' '.join(cmd)}")
    return subprocess.run(cmd, check=check)


def get_api_key() -> str | None:
    """Get Datadog API key from environment."""
    return os.environ.get("DD_API_KEY")


def create_namespace() -> None:
    """Create namespace if it doesn't exist."""
    print(f"Creating namespace '{NAMESPACE}'...")
    # Using dry-run + apply for idempotency
    create = subprocess.run(
        ["kubectl", "create", "namespace", NAMESPACE, "--dry-run=client", "-o", "yaml"],
        capture_output=True,
        text=True,
    )
    subprocess.run(["kubectl", "apply", "-f", "-"], input=create.stdout, text=True, check=True)


def create_secret(api_key: str) -> None:
    """Create Datadog API key secret."""
    print("Creating Datadog secret...")
    create = subprocess.run(
        [
            "kubectl", "create", "secret", "generic", "datadog-secret",
            f"--namespace={NAMESPACE}",
            f"--from-literal=api-key={api_key}",
            "--dry-run=client", "-o", "yaml",
        ],
        capture_output=True,
        text=True,
    )
    subprocess.run(["kubectl", "apply", "-f", "-"], input=create.stdout, text=True, check=True)


def install_datadog(api_key: str, values_file: Path) -> bool:
    """Install or upgrade Datadog via Helm."""
    print("\nInstalling/Upgrading Datadog agent...")

    cmd = [
        "helm", "upgrade", "--install", RELEASE_NAME, "datadog/datadog",
        f"--namespace={NAMESPACE}",
        f"--version={CHART_VERSION}",
        f"--values={values_file}",
        f"--set=datadog.apiKey={api_key}",
        f"--set=datadog.site={SITE}",
        f"--set=datadog.clusterName={CLUSTER_NAME}",
        f"--set=agents.image.tag={AGENT_VERSION}",
        "--set=clusterAgent.enabled=true",
        f"--set=clusterAgent.image.tag={AGENT_VERSION}",
        "--wait",
        f"--timeout={TIMEOUT}",
    ]

    result = run(cmd, check=False)
    return result.returncode == 0


def main() -> int:
    api_key = get_api_key()
    if not api_key:
        print("Error: DD_API_KEY environment variable is required", file=sys.stderr)
        print("Usage: DD_API_KEY=your-api-key python helm_dd_install.py", file=sys.stderr)
        return 1

    # Find values file relative to script location
    script_dir = Path(__file__).parent
    values_file = script_dir / "datadog-values.yaml"

    if not values_file.exists():
        print(f"Error: {values_file} not found", file=sys.stderr)
        return 1

    try:
        create_namespace()
        create_secret(api_key)

        if not install_datadog(api_key, values_file):
            print("Datadog installation failed", file=sys.stderr)
            return 1

        print("\nDatadog installation complete!")
        print(f"Verify with: kubectl get pods -n {NAMESPACE}")
        return 0

    except subprocess.CalledProcessError as e:
        print(f"Command failed: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
