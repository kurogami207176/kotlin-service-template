# kotlin-service-template

Minimal Kotlin application template that serves `GET /hello` from Amazon ECS Express mode using CloudFormation deployment templates.

## Repository layout

- `app/` - Kotlin application source, tests, Gradle wrapper, and Docker image definition.
- `cf/` - CloudFormation templates and the Lambda-backed custom resource used to create/update the ECS Express service.
- `bin/` - Shell scripts for bootstrapping AWS infrastructure and deploying the service stack.
- `.github/workflows/deploy.yml` - GitHub Actions workflow that tests, builds, pushes, and deploys the service to AWS.

## Local development

```bash
cd app
./gradlew run
```

The application listens on port `8080` by default.

- `GET /hello` returns `Hello world`
- `GET /health` returns `OK`

## AWS bootstrap

Run the bootstrap stack once with AWS credentials that can create IAM, Lambda, ECR, and CloudFormation resources.

```bash
ARTIFACT_BUCKET=my-cfn-artifacts \
GITHUB_OIDC_PROVIDER_ARN=arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com \
AWS_REGION=us-east-1 \
bin/deploy-bootstrap.sh
```

Important bootstrap outputs:

- `GitHubActionsRoleArn` - store this in the repository secret `AWS_DEPLOY_ROLE_ARN`
- `EcrRepositoryUri`, `ExecutionRoleArn`, `InfrastructureRoleArn`, `ProviderServiceToken` - consumed automatically by `bin/deploy-service.sh`

Also add repository variables:

- `AWS_REGION` - the deployment region
- `AWS_BOOTSTRAP_STACK_NAME` - optional if you keep the default bootstrap stack name of `kotlin-service-template-bootstrap`

## Manual service deployment

After the bootstrap stack exists, deploy an image with:

```bash
AWS_REGION=us-east-1 \
BOOTSTRAP_STACK_NAME=kotlin-service-template-bootstrap \
IMAGE_URI=123456789012.dkr.ecr.us-east-1.amazonaws.com/kotlin-service-template:latest \
bin/deploy-service.sh
```

The script prints the public `/hello` URL once the ECS Express deployment becomes active.

## GitHub Actions CI/CD

The workflow in `.github/workflows/deploy.yml`:

1. runs `./gradlew test` in `app/`
2. assumes the AWS role from `AWS_DEPLOY_ROLE_ARN`
3. builds and pushes the Docker image to the ECR repository from the bootstrap stack
4. deploys `cf/service.yaml`, which provisions the ECS Express service through CloudFormation
