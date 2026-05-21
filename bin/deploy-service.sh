#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
BOOTSTRAP_STACK_NAME="${BOOTSTRAP_STACK_NAME:-kotlin-service-template-bootstrap}"

stack_output() {
  local key="$1"
  aws cloudformation describe-stacks \
    --region "$AWS_REGION" \
    --stack-name "$BOOTSTRAP_STACK_NAME" \
    --query "Stacks[0].Outputs[?OutputKey=='${key}'].OutputValue" \
    --output text
}

IMAGE_URI="${IMAGE_URI:?Set IMAGE_URI to the container image to deploy.}"
STACK_NAME="${STACK_NAME:-$(stack_output ServiceStackName)}"
PROVIDER_SERVICE_TOKEN="${PROVIDER_SERVICE_TOKEN:-$(stack_output ProviderServiceToken)}"
EXECUTION_ROLE_ARN="${EXECUTION_ROLE_ARN:-$(stack_output ExecutionRoleArn)}"
INFRASTRUCTURE_ROLE_ARN="${INFRASTRUCTURE_ROLE_ARN:-$(stack_output InfrastructureRoleArn)}"
SERVICE_NAME="${SERVICE_NAME:-kotlin-service-template}"
CLUSTER_NAME="${CLUSTER_NAME:-default}"
CONTAINER_PORT="${CONTAINER_PORT:-8080}"
CPU="${CPU:-512}"
MEMORY="${MEMORY:-1024}"
HEALTH_CHECK_PATH="${HEALTH_CHECK_PATH:-/health}"

aws cloudformation deploy \
  --region "$AWS_REGION" \
  --stack-name "$STACK_NAME" \
  --template-file "$ROOT_DIR/cf/service.yaml" \
  --parameter-overrides \
    ProviderServiceToken="$PROVIDER_SERVICE_TOKEN" \
    ImageUri="$IMAGE_URI" \
    ExecutionRoleArn="$EXECUTION_ROLE_ARN" \
    InfrastructureRoleArn="$INFRASTRUCTURE_ROLE_ARN" \
    ServiceName="$SERVICE_NAME" \
    ClusterName="$CLUSTER_NAME" \
    ContainerPort="$CONTAINER_PORT" \
    Cpu="$CPU" \
    Memory="$MEMORY" \
    HealthCheckPath="$HEALTH_CHECK_PATH"

HELLO_URL="$(aws cloudformation describe-stacks \
  --region "$AWS_REGION" \
  --stack-name "$STACK_NAME" \
  --query "Stacks[0].Outputs[?OutputKey=='HelloUrl'].OutputValue" \
  --output text)"

echo "Hello endpoint: $HELLO_URL"
