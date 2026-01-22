#!/usr/bin/env python3
"""Deploy AKS Store Demo sample application.

Source: https://github.com/Azure-Samples/aks-store-demo
"""

import subprocess
import sys
from pathlib import Path

NAMESPACE = "pets"
TIMEOUT = "300s"


def run(cmd: list[str], check: bool = True, capture: bool = False) -> subprocess.CompletedProcess:
    """Run a command and return the result."""
    print(f"  $ {' '.join(cmd)}")
    return subprocess.run(cmd, check=check, capture_output=capture, text=capture)


def deploy_manifest(manifest: Path) -> bool:
    """Deploy the application manifest."""
    print("Deploying AKS Store Demo application...")
    result = run(["kubectl", "apply", "-f", str(manifest)], check=False)
    return result.returncode == 0


def wait_for_deployments() -> bool:
    """Wait for all deployments to be ready."""
    print(f"\nWaiting for deployments in '{NAMESPACE}' namespace...")
    result = run(
        ["kubectl", "wait", "--for=condition=available", f"--timeout={TIMEOUT}",
         "deployment", "--all", "-n", NAMESPACE],
        check=False,
    )
    return result.returncode == 0


def get_external_ip() -> str | None:
    """Get the store-front service external IP."""
    result = run(
        ["kubectl", "get", "service", "store-front", "-n", NAMESPACE,
         "-o", "jsonpath={.status.loadBalancer.ingress[0].ip}"],
        check=False,
        capture=True,
    )
    if result.returncode == 0 and result.stdout:
        return result.stdout.strip()
    return None


def show_pods() -> None:
    """Show all pods in the namespace."""
    print(f"\nPods in '{NAMESPACE}' namespace:")
    run(["kubectl", "get", "pods", "-n", NAMESPACE], check=False)


def main() -> int:
    # Find manifest relative to script location
    script_dir = Path(__file__).parent
    manifest = script_dir / "aks-store-demo.yaml"

    if not manifest.exists():
        print(f"Error: {manifest} not found", file=sys.stderr)
        return 1

    if not deploy_manifest(manifest):
        print("Deployment failed", file=sys.stderr)
        return 1

    if not wait_for_deployments():
        print("Warning: Timed out waiting for deployments", file=sys.stderr)

    print("\nDeployment complete!")

    ip = get_external_ip()
    if ip:
        print(f"\nStore Front URL: http://{ip}")
    else:
        print("\nExternal IP not yet assigned. Check with:")
        print(f"  kubectl get service store-front -n {NAMESPACE}")

    show_pods()
    return 0


if __name__ == "__main__":
    sys.exit(main())
