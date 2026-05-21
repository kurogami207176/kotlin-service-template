#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STACK_NAME="${STACK_NAME:-kotlin-service-template-bootstrap}"
AWS_REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
ARTIFACT_BUCKET="${ARTIFACT_BUCKET:?Set ARTIFACT_BUCKET to an S3 bucket used for packaging Lambda code.}"
GITHUB_OIDC_PROVIDER_ARN="${GITHUB_OIDC_PROVIDER_ARN:?Set GITHUB_OIDC_PROVIDER_ARN to your token.actions.githubusercontent.com OIDC provider ARN.}"
GITHUB_ORGANIZATION="${GITHUB_ORGANIZATION:-kurogami207176}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-kotlin-service-template}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
ECR_REPOSITORY_NAME="${ECR_REPOSITORY_NAME:-kotlin-service-template}"
SERVICE_STACK_NAME="${SERVICE_STACK_NAME:-kotlin-service-template-service}"
PACKAGED_TEMPLATE="$(mktemp)"

if ! aws s3api head-bucket --bucket "$ARTIFACT_BUCKET" >/dev/null 2>&1; then
  if [[ "$AWS_REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$ARTIFACT_BUCKET" >/dev/null
  else
    aws s3api create-bucket --bucket "$ARTIFACT_BUCKET" --create-bucket-configuration "LocationConstraint=$AWS_REGION" >/dev/null
  fi
fi

aws cloudformation package \
  --region "$AWS_REGION" \
  --template-file "$ROOT_DIR/cf/bootstrap.yaml" \
  --s3-bucket "$ARTIFACT_BUCKET" \
  --output-template-file "$PACKAGED_TEMPLATE"

aws cloudformation deploy \
  --region "$AWS_REGION" \
  --stack-name "$STACK_NAME" \
  --template-file "$PACKAGED_TEMPLATE" \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    GitHubOidcProviderArn="$GITHUB_OIDC_PROVIDER_ARN" \
    GitHubOrganization="$GITHUB_ORGANIZATION" \
    GitHubRepository="$GITHUB_REPOSITORY" \
    GitHubBranch="$GITHUB_BRANCH" \
    EcrRepositoryName="$ECR_REPOSITORY_NAME" \
    ServiceStackName="$SERVICE_STACK_NAME"

aws cloudformation describe-stacks \
  --region "$AWS_REGION" \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs' \
  --output table
