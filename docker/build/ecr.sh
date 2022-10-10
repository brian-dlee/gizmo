#!/bin/bash

set -e

function abort() {
  echo "$@" >&2
  exit 1
}

AWS_ECR_ORG=${AWS_ECR_ORG}
AWS_REGION=${AWS_REGION:-${AWS_DEFAULT_REGION}}

OPT_DOCKER_CONTEXT_PATH="."
OPT_PUSH=0
OPT_ADD_TS=1
OPT_TAG=latest

args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --push|-p) OPT_PUSH=1;;
    --no-ts) OPT_ADD_TS=0;;
    --tag|-t) OPT_TAG=$2; shift;;
    --tag=*) OPT_TAG=${$2#--*=}; shift;;
    --context-path|-c) OPT_DOCKER_CONTEXT_PATH=$2; shift;;
    --context-path=*) OPT_DOCKER_CONTEXT_PATH=${$2#--*=}; shift;;
    --*|-*) echo "Unknown option supplied: $1"; exit 1;;
    *) args+=("$1");;
  esac
  shift
done

if [[ "${#args[@]}" -eq 0 ]]; then
  echo "No image name supplied" >&2
  exit 1
fi

image_name=${args[0]}
image_registry=""
tag_ts=$(date "+%Y%m%d-%H%M")

if [[ "${OPT_ADD_TS}" -eq 1 ]]; then
  echo "Building Docker image $image_name (tag: $OPT_TAG, ts=$tag_ts)"
else
  echo "Building Docker image $image_name (tag: $OPT_TAG, ts=[DISABLED])"
fi

echo

if [[ -z "$AWS_ACCESS_KEY_ID" ]]; then
  echo "AWS_ACCESS_KEY_ID is not defined. Attempting to detect variable using the AWS CLI." >&2
  AWS_ACCESS_KEY_ID=$(aws configure get "aws_access_key_id" || true)
fi

if [[ -z "$AWS_SECRET_ACCESS_KEY" ]]; then
  echo "AWS_SECRET_ACCESS_KEY is not defined. Attempting to detect variable using the AWS CLI." >&2
  AWS_SECRET_ACCESS_KEY=$(aws configure get "aws_secret_access_key" || true)
fi

if [[ -z "$AWS_REGION" ]]; then
  echo "AWS_REGION is not defined. Attempting to detect variable using the AWS CLI." >&2
  AWS_REGION=$(aws configure get "region" || true)
fi

if [[ -n "$AWS_ECR_ORG" ]]; then
  test [[ "$OPT_PUSH" == 1 && -z "$AWS_ACCESS_KEY_ID" ]] && echo "warning: AWS_ACCESS_KEY_ID is not defined, but an ECR org ($AWS_ECR_ORG) and --push was supplied." >&2
  test [[ "$OPT_PUSH" == 1 && -z "$AWS_SECRET_ACCESS_KEY" ]] && echo "warning: AWS_SECRET_ACCESS_KEY is not defined, but an ECR org ($AWS_ECR_ORG) and --push was supplied." >&2
  test [[ -z "$AWS_REGION" ]] && echo "warning: AWS_REGION is not defined, but an ECR org ($AWS_ECR_ORG) was supplied." >&2
fi

if [[ -n "$AWS_REGION" && -n "$AWS_ECR_ORG" ]]; then
  image_registry="$AWS_ECR_ORG.dkr.ecr.$AWS_REGION.amazonaws.com/"
fi

echo

test -n "$AWS_ACCESS_KEY_ID" || abort "AWS_ACCESS_KEY_ID could not be determined"
echo "AWS Access Key ID:     ${AWS_ACCESS_KEY_ID:0:4}***"

test -n "$AWS_SECRET_ACCESS_KEY" || abort "AWS_SECRET_ACCESS_KEY could not be determined"
echo "AWS Secret Access Key: $(test -z "${AWS_SECRET_ACCESS_KEY}" && echo "[NOT SET]" || echo "[SET]")"

test -n "$AWS_REGION" || abort "AWS_REGION could not be determined"
echo "AWS Region:            ${AWS_REGION}"

echo "Image:                 ${image_registry}${image_name}"

echo

echo "Building $image_name from $OPT_DOCKER_CONTEXT_PATH"
docker build -t "$image_name" \
  --build-arg AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
  --build-arg AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
  --build-arg AWS_REGION="${AWS_REGION}" \
  "${OPT_DOCKER_CONTEXT_PATH}"

echo "Tagging $image_name -> $image_registry$image_name:$OPT_TAG"
docker tag "$image_name" "$image_registry$image_name:$OPT_TAG"

if [[ "${OPT_ADD_TS}" -eq 1 ]]; then
  echo "Tagging $image_name -> $image_registry$image_name:$OPT_TAG-$tag_ts"
  docker tag "$image_name" "$image_registry$image_name:$OPT_TAG-$tag_ts"
fi

if [[ "$OPT_PUSH" -eq 1 ]]; then
  echo "Pushing $image_registry$image_name:$OPT_TAG"
  docker push "$image_registry$image_name:$OPT_TAG"

  if [[ "${OPT_ADD_TS}" -eq 1 ]]; then
    echo "Pushing $image_registry$image_name:$OPT_TAG-$tag_ts"
    docker push "$image_registry$image_name:$OPT_TAG-$tag_ts"
  fi
fi

