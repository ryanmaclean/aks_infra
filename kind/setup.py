#!/usr/bin/env python3
"""KIND local development setup.

Usage:
    python kind/setup.py           # Create cluster + deploy app
    python kind/setup.py --cilium  # Include Cilium for NetworkPolicy
    python kind/setup.py deploy    # Deploy to existing cluster
    python kind/setup.py delete    # Delete cluster
"""

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
CLUSTER_NAME = "aks-store-local"


def run(cmd: list[str], check: bool = True, capture: bool = False) -> subprocess.CompletedProcess:
    """Run command with output."""
    print(f"$ {' '.join(cmd)}")
    return subprocess.run(cmd, check=check, capture_output=capture, text=capture)


def check_prerequisites() -> bool:
    """Verify required tools are installed."""
    required = ["kind", "kubectl", "docker"]
    missing = [cmd for cmd in required if not shutil.which(cmd)]
    if missing:
        print(f"ERROR: Required tools not installed: {', '.join(missing)}")
        return False
    return True


def cluster_exists() -> bool:
    """Check if KIND cluster exists."""
    result = run(["kind", "get", "clusters"], check=False, capture=True)
    return CLUSTER_NAME in result.stdout.split()


def create_cluster() -> int:
    """Create KIND cluster."""
    if cluster_exists():
        print(f"Cluster '{CLUSTER_NAME}' already exists")
        response = input("Delete and recreate? [y/N] ").strip().lower()
        if response == "y":
            delete_cluster()
        else:
            print("Using existing cluster")
            return 0

    print("Creating KIND cluster...")
    config_file = SCRIPT_DIR / "kind-config.yaml"
    return run(
        ["kind", "create", "cluster", "--config", str(config_file), "--name", CLUSTER_NAME],
        check=False,
    ).returncode


def delete_cluster() -> int:
    """Delete KIND cluster."""
    if not cluster_exists():
        print(f"Cluster '{CLUSTER_NAME}' does not exist")
        return 0
    print(f"Deleting cluster '{CLUSTER_NAME}'...")
    return run(["kind", "delete", "cluster", "--name", CLUSTER_NAME], check=False).returncode


def deploy_app() -> int:
    """Deploy app using kustomize."""
    print("Deploying AKS Store Demo...")
    if run(["kubectl", "apply", "-k", str(SCRIPT_DIR)], check=False).returncode != 0:
        return 1

    print("Waiting for deployments...")
    run(
        ["kubectl", "wait", "--for=condition=available", "--timeout=300s", "deployment", "--all", "-n", "pets"],
        check=False,
    )

    print("\n=== Deployment Complete ===")
    run(["kubectl", "get", "pods", "-n", "pets"], check=False)
    print("\nStore URL: http://localhost:8080")
    return 0


def install_cilium() -> int:
    """Install Cilium CNI for NetworkPolicy support."""
    if not shutil.which("helm"):
        print("ERROR: helm is required for Cilium installation")
        return 1

    print("Installing Cilium CNI...")
    run(["helm", "repo", "add", "cilium", "https://helm.cilium.io/"], check=False)
    run(["helm", "repo", "update", "cilium"], check=False)

    result = run(
        [
            "helm", "upgrade", "--install", "cilium", "cilium/cilium",
            "--namespace", "kube-system",
            "--set", "image.pullPolicy=IfNotPresent",
            "--set", "ipam.mode=kubernetes",
            "--set", "kubeProxyReplacement=partial",
            "--set", "operator.replicas=1",
            "--wait", "--timeout=5m",
        ],
        check=False,
    )
    if result.returncode != 0:
        return result.returncode

    print("Waiting for Cilium...")
    run(["kubectl", "-n", "kube-system", "rollout", "status", "daemonset/cilium", "--timeout=120s"], check=False)
    print("\nCilium installed - NetworkPolicy enforcement active")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="KIND local development setup")
    parser.add_argument("action", nargs="?", default="up", choices=["up", "deploy", "delete", "cilium"])
    parser.add_argument("--cilium", action="store_true", help="Install Cilium for NetworkPolicy support")
    args = parser.parse_args()

    if not check_prerequisites():
        return 1

    if args.action == "delete":
        return delete_cluster()

    if args.action == "cilium":
        return install_cilium()

    if args.action == "deploy":
        run(["kubectl", "config", "use-context", f"kind-{CLUSTER_NAME}"], check=False)
        return deploy_app()

    # Default: up (create + deploy)
    if create_cluster() != 0:
        return 1

    run(["kubectl", "config", "use-context", f"kind-{CLUSTER_NAME}"], check=False)

    if args.cilium:
        if install_cilium() != 0:
            print("WARNING: Cilium installation failed, continuing without NetworkPolicy")

    return deploy_app()


if __name__ == "__main__":
    sys.exit(main())
