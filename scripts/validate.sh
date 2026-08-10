#!/usr/bin/env bash

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

for required_command in git perl helm docker; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "Missing required command: $required_command" >&2
    exit 1
  fi
done

echo "Checking Markdown links and fenced code blocks..."
perl scripts/check-docs.pl

echo "Checking whitespace errors..."
git diff --check

echo "Scanning tracked files for common credential formats..."
secret_pattern='-----BEGIN ([A-Z0-9]+ )?PRIVATE KEY-----|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}'
if git grep -nIE -e "$secret_pattern" -- . ':!scripts/validate.sh'; then
  echo "Possible credential found in tracked files." >&2
  exit 1
fi

echo "Linting and rendering the Helm example..."
helm lint examples/04-helm-web

echo "Checking GitHub Actions workflows..."
docker run --rm \
  -v "$PWD:/repo:ro" \
  -w /repo \
  rhysd/actionlint:1.7.12

echo "Validating Kubernetes manifests with kubeconform..."
kubeconform_image='ghcr.io/yannh/kubeconform:v0.8.0'
docker run --rm \
  -v "$PWD:/work:ro" \
  "$kubeconform_image" \
  -strict \
  -summary \
  /work/examples/00-namespace/namespace.yaml \
  /work/examples/01-basic-web/configmap.yaml \
  /work/examples/01-basic-web/deployment.yaml \
  /work/examples/01-basic-web/service.yaml \
  /work/examples/01-basic-web/ingress.yaml \
  /work/examples/02-whoami/whoami.yaml \
  /work/examples/03-storage/pvc.yaml \
  /work/examples/03-storage/deployment.yaml \
  /work/examples/05-custom-image/app.yaml

helm template helm-web examples/04-helm-web -n k8s-study | \
  docker run --rm -i "$kubeconform_image" -strict -summary

echo "All validation checks passed."
