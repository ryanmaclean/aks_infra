#!/usr/bin/env python3
"""AKS deployment CLI - Helm repos, Datadog, and sample app deployment."""

import argparse
import os
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent

# Helm repositories
HELM_REPOS = {
    "datadog": "https://helm.datadoghq.com",
    "bitnami": "https://charts.bitnami.com/bitnami",
    "azure-samples": "https://azure-samples.github.io/helm-charts",
    "ingress-nginx": "https://kubernetes.github.io/ingress-nginx",
    "jetstack": "https://charts.jetstack.io",
    "prometheus-community": "https://prometheus-community.github.io/helm-charts",
}

# Datadog configuration
DATADOG_CONFIG = {
    "namespace": "datadog",
    "release": "datadog",
    "chart_version": "3.80.0",
    "agent_version": "7.60.0",
    "cluster_name": "aks-cluster",
    "site": "datadoghq.com",
    "timeout": "10m",
}


def run(cmd: list[str], check: bool = True, capture: bool = False) -> subprocess.CompletedProcess:
    """Run a command and return the result."""
    print(f"  $ {' '.join(cmd)}")
    return subprocess.run(cmd, check=check, capture_output=capture, text=capture)


def cmd_repos(args: argparse.Namespace) -> int:
    """Add and update Helm repositories."""
    print("Adding Helm repositories...")
    for name, url in HELM_REPOS.items():
        run(["helm", "repo", "add", name, url], check=False)

    print("\nUpdating repositories...")
    run(["helm", "repo", "update"], check=False)

    print("\nConfigured repositories:")
    run(["helm", "repo", "list"], check=False)
    return 0


def cmd_datadog(args: argparse.Namespace) -> int:
    """Install Datadog via Helm."""
    api_key = args.api_key or os.environ.get("DD_API_KEY")
    if not api_key:
        print("Error: --api-key or DD_API_KEY required", file=sys.stderr)
        return 1

    values_file = SCRIPT_DIR / "datadog-values.yaml"
    if not values_file.exists():
        print(f"Error: {values_file} not found", file=sys.stderr)
        return 1

    cfg = DATADOG_CONFIG
    ns = cfg["namespace"]

    # Create namespace
    print(f"Creating namespace '{ns}'...")
    create = subprocess.run(
        ["kubectl", "create", "namespace", ns, "--dry-run=client", "-o", "yaml"],
        capture_output=True, text=True,
    )
    subprocess.run(["kubectl", "apply", "-f", "-"], input=create.stdout, text=True, check=True)

    # Create secret
    print("Creating Datadog secret...")
    create = subprocess.run(
        ["kubectl", "create", "secret", "generic", "datadog-secret",
         f"--namespace={ns}", f"--from-literal=api-key={api_key}",
         "--dry-run=client", "-o", "yaml"],
        capture_output=True, text=True,
    )
    subprocess.run(["kubectl", "apply", "-f", "-"], input=create.stdout, text=True, check=True)

    # Install via Helm
    print("\nInstalling Datadog...")
    result = run([
        "helm", "upgrade", "--install", cfg["release"], "datadog/datadog",
        f"--namespace={ns}",
        f"--version={cfg['chart_version']}",
        f"--values={values_file}",
        f"--set=datadog.apiKey={api_key}",
        f"--set=datadog.site={cfg['site']}",
        f"--set=datadog.clusterName={args.cluster_name or cfg['cluster_name']}",
        f"--set=agents.image.tag={cfg['agent_version']}",
        "--set=clusterAgent.enabled=true",
        f"--set=clusterAgent.image.tag={cfg['agent_version']}",
        "--wait",
        f"--timeout={cfg['timeout']}",
    ], check=False)

    if result.returncode == 0:
        print(f"\nDatadog installed. Verify: kubectl get pods -n {ns}")
    return result.returncode


def cmd_app(args: argparse.Namespace) -> int:
    """Deploy AKS Store Demo sample application."""
    manifest = SCRIPT_DIR / "aks-store-demo.yaml"
    if not manifest.exists():
        print(f"Error: {manifest} not found", file=sys.stderr)
        return 1

    ns = "pets"

    print("Deploying AKS Store Demo...")
    if run(["kubectl", "apply", "-f", str(manifest)], check=False).returncode != 0:
        return 1

    print(f"\nWaiting for deployments in '{ns}'...")
    run(["kubectl", "wait", "--for=condition=available", "--timeout=300s",
         "deployment", "--all", "-n", ns], check=False)

    # Get external IP
    result = run(
        ["kubectl", "get", "service", "store-front", "-n", ns,
         "-o", "jsonpath={.status.loadBalancer.ingress[0].ip}"],
        check=False, capture=True,
    )
    if result.returncode == 0 and result.stdout:
        print(f"\nStore URL: http://{result.stdout.strip()}")
    else:
        print(f"\nExternal IP pending. Check: kubectl get svc store-front -n {ns}")

    print(f"\nPods:")
    run(["kubectl", "get", "pods", "-n", ns], check=False)
    return 0


def cmd_all(args: argparse.Namespace) -> int:
    """Run all deployment steps."""
    print("=== Step 1/3: Helm Repositories ===\n")
    if cmd_repos(args) != 0:
        return 1

    print("\n=== Step 2/3: Datadog ===\n")
    if cmd_datadog(args) != 0:
        return 1

    print("\n=== Step 3/3: Sample App ===\n")
    return cmd_app(args)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="AKS deployment CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s repos                      # Add Helm repositories
  %(prog)s datadog --api-key KEY      # Install Datadog
  %(prog)s app                        # Deploy sample app
  %(prog)s all --api-key KEY          # Run all steps
        """,
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    # repos
    subparsers.add_parser("repos", help="Add and update Helm repositories")

    # datadog
    p_dd = subparsers.add_parser("datadog", help="Install Datadog via Helm")
    p_dd.add_argument("--api-key", help="Datadog API key (or set DD_API_KEY)")
    p_dd.add_argument("--cluster-name", help="Cluster name for Datadog tags")

    # app
    subparsers.add_parser("app", help="Deploy AKS Store Demo sample app")

    # all
    p_all = subparsers.add_parser("all", help="Run all deployment steps")
    p_all.add_argument("--api-key", help="Datadog API key (or set DD_API_KEY)")
    p_all.add_argument("--cluster-name", help="Cluster name for Datadog tags")

    args = parser.parse_args()

    commands = {
        "repos": cmd_repos,
        "datadog": cmd_datadog,
        "app": cmd_app,
        "all": cmd_all,
    }

    return commands[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
