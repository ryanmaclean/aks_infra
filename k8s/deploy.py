#!/usr/bin/env python3
"""AKS deployment CLI with Datadog instrumentation.

Sends traces, metrics, and structured logs to Datadog for deployment observability.
"""

import argparse
import json
import logging
import os
import subprocess
import sys
import time
from pathlib import Path

import yaml

# Optional Datadog imports - graceful degradation if not installed
try:
    from ddtrace import tracer, patch_all
    patch_all()
    TRACING_ENABLED = True
except ImportError:
    tracer = None
    TRACING_ENABLED = False

try:
    from datadog import initialize, statsd
    initialize(statsd_host=os.getenv("DD_AGENT_HOST", "localhost"), statsd_port=8125)
    METRICS_ENABLED = True
except ImportError:
    statsd = None
    METRICS_ENABLED = False


SCRIPT_DIR = Path(__file__).parent
SERVICE_NAME = "aks-deploy"

# Helm repositories
HELM_REPOS = {
    "datadog": "https://helm.datadoghq.com",
    "bitnami": "https://charts.bitnami.com/bitnami",
    "azure-samples": "https://azure-samples.github.io/helm-charts",
    "ingress-nginx": "https://kubernetes.github.io/ingress-nginx",
    "jetstack": "https://charts.jetstack.io",
    "prometheus-community": "https://prometheus-community.github.io/helm-charts",
}


# Structured JSON logging
class JsonFormatter(logging.Formatter):
    def format(self, record):
        log_data = {
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "message": record.getMessage(),
            "service": SERVICE_NAME,
            "logger": record.name,
        }
        if hasattr(record, "command"):
            log_data["command"] = record.command
        if hasattr(record, "duration_ms"):
            log_data["duration_ms"] = record.duration_ms
        if hasattr(record, "exit_code"):
            log_data["exit_code"] = record.exit_code
        if record.exc_info:
            log_data["error"] = self.formatException(record.exc_info)
        return json.dumps(log_data)


def setup_logging(verbose: bool = False) -> logging.Logger:
    logger = logging.getLogger(SERVICE_NAME)
    logger.setLevel(logging.DEBUG if verbose else logging.INFO)

    handler = logging.StreamHandler()
    if os.getenv("DD_LOGS_INJECTION") or os.getenv("JSON_LOGS"):
        handler.setFormatter(JsonFormatter())
    else:
        handler.setFormatter(logging.Formatter("%(levelname)s: %(message)s"))

    logger.addHandler(handler)
    return logger


log = setup_logging()


def load_datadog_config() -> dict:
    """Load configuration from datadog-values.yaml."""
    values_file = SCRIPT_DIR / "datadog-values.yaml"
    if values_file.exists():
        with open(values_file) as f:
            values = yaml.safe_load(f)
            return {
                "namespace": "datadog",
                "release": "datadog",
                "chart_version": "3.80.0",
                "agent_version": values.get("agents", {}).get("image", {}).get("tag", "7.60.0"),
                "cluster_name": values.get("datadog", {}).get("clusterName", "aks-cluster"),
                "site": values.get("datadog", {}).get("site", "datadoghq.com"),
                "timeout": "10m",
            }
    return {
        "namespace": "datadog",
        "release": "datadog",
        "chart_version": "3.80.0",
        "agent_version": "7.60.0",
        "cluster_name": "aks-cluster",
        "site": "datadoghq.com",
        "timeout": "10m",
    }


def metric(name: str, value: float = 1, tags: list[str] = None, metric_type: str = "increment"):
    """Send metric to Datadog if available."""
    if not METRICS_ENABLED or not statsd:
        return
    full_name = f"{SERVICE_NAME}.{name}"
    tags = tags or []
    if metric_type == "increment":
        statsd.increment(full_name, value, tags=tags)
    elif metric_type == "histogram":
        statsd.histogram(full_name, value, tags=tags)
    elif metric_type == "gauge":
        statsd.gauge(full_name, value, tags=tags)


def traced(operation: str):
    """Decorator for tracing functions."""
    def decorator(func):
        def wrapper(*args, **kwargs):
            if TRACING_ENABLED and tracer:
                with tracer.trace(f"{SERVICE_NAME}.{operation}") as span:
                    span.set_tag("operation", operation)
                    return func(*args, **kwargs)
            return func(*args, **kwargs)
        return wrapper
    return decorator


def run(cmd: list[str], check: bool = True, capture: bool = False) -> subprocess.CompletedProcess:
    """Run a command with timing and metrics."""
    cmd_str = " ".join(cmd)
    log.info(f"$ {cmd_str}")

    start = time.time()
    result = subprocess.run(cmd, check=check, capture_output=capture, text=capture)
    duration_ms = (time.time() - start) * 1000

    # Log with structured data
    extra = {"command": cmd[0], "duration_ms": round(duration_ms, 2), "exit_code": result.returncode}
    log.debug("Command completed", extra=extra)

    # Metrics
    tags = [f"command:{cmd[0]}", f"success:{result.returncode == 0}"]
    metric("command.duration", duration_ms, tags=tags, metric_type="histogram")
    metric("command.count", tags=tags)

    return result


@traced("repos")
def cmd_repos(args: argparse.Namespace) -> int:
    """Add and update Helm repositories."""
    log.info("Adding Helm repositories")
    metric("repos.start")
    start = time.time()

    for name, url in HELM_REPOS.items():
        run(["helm", "repo", "add", name, url], check=False)

    log.info("Updating repositories")
    run(["helm", "repo", "update"], check=False)

    log.info("Listing configured repositories")
    run(["helm", "repo", "list"], check=False)

    duration = time.time() - start
    metric("repos.duration", duration * 1000, metric_type="histogram")
    metric("repos.success")
    log.info(f"Helm repositories configured in {duration:.1f}s")
    return 0


@traced("datadog")
def cmd_datadog(args: argparse.Namespace) -> int:
    """Install Datadog via Helm."""
    metric("datadog.start")
    start = time.time()

    api_key = args.api_key or os.environ.get("DD_API_KEY")
    if not api_key:
        log.error("--api-key or DD_API_KEY required")
        metric("datadog.failure", tags=["reason:missing_api_key"])
        return 1

    values_file = SCRIPT_DIR / "datadog-values.yaml"
    if not values_file.exists():
        log.error(f"{values_file} not found")
        metric("datadog.failure", tags=["reason:missing_values"])
        return 1

    cfg = load_datadog_config()
    if args.cluster_name:
        cfg["cluster_name"] = args.cluster_name

    ns = cfg["namespace"]

    # Create namespace
    log.info(f"Creating namespace '{ns}'")
    create = subprocess.run(
        ["kubectl", "create", "namespace", ns, "--dry-run=client", "-o", "yaml"],
        capture_output=True, text=True,
    )
    subprocess.run(["kubectl", "apply", "-f", "-"], input=create.stdout, text=True, check=True)

    # Create secret
    log.info("Creating Datadog secret")
    create = subprocess.run(
        ["kubectl", "create", "secret", "generic", "datadog-secret",
         f"--namespace={ns}", f"--from-literal=api-key={api_key}",
         "--dry-run=client", "-o", "yaml"],
        capture_output=True, text=True,
    )
    subprocess.run(["kubectl", "apply", "-f", "-"], input=create.stdout, text=True, check=True)

    # Install via Helm
    log.info("Installing Datadog via Helm")
    result = run([
        "helm", "upgrade", "--install", cfg["release"], "datadog/datadog",
        f"--namespace={ns}",
        f"--version={cfg['chart_version']}",
        f"--values={values_file}",
        f"--set=datadog.apiKey={api_key}",
        f"--set=datadog.site={cfg['site']}",
        f"--set=datadog.clusterName={cfg['cluster_name']}",
        f"--set=agents.image.tag={cfg['agent_version']}",
        "--set=clusterAgent.enabled=true",
        f"--set=clusterAgent.image.tag={cfg['agent_version']}",
        "--wait",
        f"--timeout={cfg['timeout']}",
    ], check=False)

    duration = time.time() - start
    metric("datadog.duration", duration * 1000, metric_type="histogram")

    if result.returncode == 0:
        log.info(f"Datadog installed in {duration:.1f}s. Verify: kubectl get pods -n {ns}")
        metric("datadog.success")
    else:
        log.error("Datadog installation failed")
        metric("datadog.failure", tags=["reason:helm_error"])

    return result.returncode


@traced("app")
def cmd_app(args: argparse.Namespace) -> int:
    """Deploy AKS Store Demo sample application."""
    metric("app.start")
    start = time.time()

    manifest = SCRIPT_DIR / "aks-store-demo.yaml"
    if not manifest.exists():
        log.error(f"{manifest} not found")
        metric("app.failure", tags=["reason:missing_manifest"])
        return 1

    ns = "pets"

    log.info("Deploying AKS Store Demo")
    if run(["kubectl", "apply", "-f", str(manifest)], check=False).returncode != 0:
        metric("app.failure", tags=["reason:apply_error"])
        return 1

    log.info(f"Waiting for deployments in '{ns}'")
    run(["kubectl", "wait", "--for=condition=available", "--timeout=300s",
         "deployment", "--all", "-n", ns], check=False)

    # Get external IP
    result = run(
        ["kubectl", "get", "service", "store-front", "-n", ns,
         "-o", "jsonpath={.status.loadBalancer.ingress[0].ip}"],
        check=False, capture=True,
    )

    duration = time.time() - start
    metric("app.duration", duration * 1000, metric_type="histogram")
    metric("app.success")

    if result.returncode == 0 and result.stdout:
        log.info(f"Store URL: http://{result.stdout.strip()}")
    else:
        log.info(f"External IP pending. Check: kubectl get svc store-front -n {ns}")

    run(["kubectl", "get", "pods", "-n", ns], check=False)
    log.info(f"App deployed in {duration:.1f}s")
    return 0


@traced("all")
def cmd_all(args: argparse.Namespace) -> int:
    """Run all deployment steps."""
    metric("all.start")
    start = time.time()

    log.info("=== Step 1/3: Helm Repositories ===")
    if cmd_repos(args) != 0:
        metric("all.failure", tags=["step:repos"])
        return 1

    log.info("\n=== Step 2/3: Datadog ===")
    if cmd_datadog(args) != 0:
        metric("all.failure", tags=["step:datadog"])
        return 1

    log.info("\n=== Step 3/3: Sample App ===")
    result = cmd_app(args)

    duration = time.time() - start
    metric("all.duration", duration * 1000, metric_type="histogram")
    if result == 0:
        metric("all.success")
        log.info(f"Full deployment completed in {duration:.1f}s")

    return result


def main() -> int:
    parser = argparse.ArgumentParser(
        description="AKS deployment CLI with Datadog instrumentation",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s repos                      # Add Helm repositories
  %(prog)s datadog --api-key KEY      # Install Datadog
  %(prog)s app                        # Deploy sample app
  %(prog)s all --api-key KEY          # Run all steps

Environment:
  DD_API_KEY        Datadog API key (alternative to --api-key)
  DD_AGENT_HOST     Datadog agent host for metrics (default: localhost)
  DD_LOGS_INJECTION Enable JSON structured logging
  JSON_LOGS         Enable JSON structured logging

Instrumentation:
  Install optional dependencies for full observability:
    pip install ddtrace datadog pyyaml
        """,
    )
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
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

    global log
    log = setup_logging(args.verbose)

    # Log instrumentation status
    if args.verbose:
        log.debug(f"Tracing: {'enabled' if TRACING_ENABLED else 'disabled (pip install ddtrace)'}")
        log.debug(f"Metrics: {'enabled' if METRICS_ENABLED else 'disabled (pip install datadog)'}")

    commands = {
        "repos": cmd_repos,
        "datadog": cmd_datadog,
        "app": cmd_app,
        "all": cmd_all,
    }

    return commands[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
