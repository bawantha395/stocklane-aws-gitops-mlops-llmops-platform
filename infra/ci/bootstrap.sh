#!/usr/bin/env bash
# One-time foundation for an environment, run in AWS CloudShell. Creates two CloudFormation stacks
# (the private Terraform state bucket and the CI identity) and prints what to put into GitHub.
# Without EXECUTE=1 it only creates change sets so you can review them first.
#
#   REPOSITORY=owner/repo EXPECTED_ACCOUNT=123456789012 HOSTED_ZONE_ID=Z... API_DOMAIN=api.stocklane.example.com \
#     bash infra/ci/bootstrap.sh                      # review the change sets
#   ... EXECUTE=1 CREATE_ACCESS_KEY=1 bash infra/ci/bootstrap.sh   # first real run (access key ONLY once)
set -euo pipefail

: "${REPOSITORY:?owner/repo}" "${EXPECTED_ACCOUNT:?12-digit account id}" "${HOSTED_ZONE_ID:?Route 53 zone id}" "${API_DOMAIN:?api hostname}"
REGION="${AWS_REGION:-ap-southeast-2}"
PROJECT_NAME="${PROJECT_NAME:-stocklane-dev}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AUTH_MODE="${AUTH_MODE:-access-key}"
export AWS_DEFAULT_REGION="$REGION"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
[ "$ACCOUNT" = "$EXPECTED_ACCOUNT" ] || { echo "Signed in to $ACCOUNT, expected $EXPECTED_ACCOUNT" >&2; exit 1; }

STATE_BUCKET="${PROJECT_NAME}-tfstate-${ACCOUNT}-${REGION}"
ZONE_NAME="$(aws route53 get-hosted-zone --id "$HOSTED_ZONE_ID" --query HostedZone.Name --output text)"
ZONE_NAME="${ZONE_NAME%.}"
repo_json="$(curl -fsSL "https://api.github.com/repos/${REPOSITORY}")"
OWNER_ID="$(jq -r .owner.id <<<"$repo_json")"
REPO_ID="$(jq -r .id <<<"$repo_json")"
OIDC_ARN="arn:aws:iam::${ACCOUNT}:oidc-provider/token.actions.githubusercontent.com"
aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null 2>&1 || OIDC_ARN=""

deploy() { # stack template parameter-overrides...
  local stack="$1" template="$2"; shift 2
  local flags=(--no-fail-on-empty-changeset --capabilities CAPABILITY_NAMED_IAM)
  [ "${EXECUTE:-}" = "1" ] || flags+=(--no-execute-changeset)
  aws cloudformation deploy --stack-name "$stack" --template-file "$template" "${flags[@]}" --parameter-overrides "$@"
}

deploy "${PROJECT_NAME}-state" "$HERE/state.json" BucketName="$STATE_BUCKET" ProjectName="$PROJECT_NAME"
if [ "${EXECUTE:-}" != "1" ]; then
  echo "Change set created for the state stack. Review it, then re-run with EXECUTE=1."
  exit 0
fi
deploy "${PROJECT_NAME}-identity" "$HERE/identity.json" \
  ProjectName="$PROJECT_NAME" Environment="$ENVIRONMENT" GitHubRepository="$REPOSITORY" \
  GitHubOwnerId="$OWNER_ID" GitHubRepositoryId="$REPO_ID" StateBucketName="$STATE_BUCKET" \
  HostedZoneId="$HOSTED_ZONE_ID" ApiDomain="$API_DOMAIN" PublicZoneName="$ZONE_NAME" \
  AuthMode="$AUTH_MODE" ExistingOidcProviderArn="$OIDC_ARN"

# Service-linked roles the environment needs; they already exist on most accounts.
for service in eks.amazonaws.com eks-nodegroup.amazonaws.com elasticloadbalancing.amazonaws.com \
               rds.amazonaws.com elasticache.amazonaws.com autoscaling.amazonaws.com; do
  aws iam create-service-linked-role --aws-service-name "$service" >/dev/null 2>&1 || true
done

output() { aws cloudformation describe-stacks --stack-name "${PROJECT_NAME}-identity" \
  --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text; }
OUT="$HERE/../../deploy/generated"; mkdir -p "$OUT"; umask 077
if [ "${CREATE_ACCESS_KEY:-}" = "1" ] && [ "$AUTH_MODE" = "access-key" ]; then
  user="$(output PipelineUserArn)"; user="${user##*/}"
  aws iam create-access-key --user-name "$user" --query AccessKey > "$OUT/github-credentials.json"
  echo "Access key written to deploy/generated/github-credentials.json (private, shown once, git-ignored)."
fi

echo
echo "GitHub variables:  AWS_ACCOUNT_ID=$ACCOUNT   AWS_AUTH_MODE=$AUTH_MODE"
[ "$AUTH_MODE" = "access-key" ] && echo "GitHub secrets:    AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY (from github-credentials.json), TFVARS_JSON"
echo "TFVARS_JSON starting point (see README.md, Run it from zero):"
jq -n --arg a "arn:aws:iam::${ACCOUNT}:role/<your-operator-role>" --arg z "$HOSTED_ZONE_ID" --arg d "$API_DOMAIN" --arg m "$AUTH_MODE" \
  '{administrator_arn:$a, route53_zone_id:$z, api_domain:$d, github_auth_mode:$m}' | tee "$OUT/github-setup.json"
