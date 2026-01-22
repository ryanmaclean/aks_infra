#!/usr/bin/env python3
"""Helm repository initialization for AKS infrastructure."""

import subprocess
import sys

REPOS = {
    "datadog": "https://helm.datadoghq.com",
    "bitnami": "https://charts.bitnami.com/bitnami",
    "azure-samples": "https://azure-samples.github.io/helm-charts",
    "ingress-nginx": "https://kubernetes.github.io/ingress-nginx",
    "jetstack": "https://charts.jetstack.io",
    "prometheus-community": "https://prometheus-community.github.io/helm-charts",
}


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    """Run a command and return the result."""
    print(f"  $ {' '.join(cmd)}")
    return subprocess.run(cmd, check=check, capture_output=False)


def add_repos() -> bool:
    """Add all Helm repositories."""
    print("Adding Helm repositories...")
    success = True
    for name, url in REPOS.items():
        result = run(["helm", "repo", "add", name, url], check=False)
        if result.returncode != 0:
            print(f"  Warning: Failed to add {name}")
            success = False
    return success


def update_repos() -> bool:
    """Update all Helm repositories."""
    print("\nUpdating Helm repositories...")
    result = run(["helm", "repo", "update"], check=False)
    return result.returncode == 0


def list_repos() -> None:
    """List configured repositories."""
    print("\nConfigured repositories:")
    run(["helm", "repo", "list"], check=False)


def main() -> int:
    add_repos()
    if not update_repos():
        print("Warning: repo update failed", file=sys.stderr)
    list_repos()
    print("\nHelm repositories configured.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
