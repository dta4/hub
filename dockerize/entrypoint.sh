#!/bin/sh
set -e

CONTEXT=${INPUT_CONTEXT}
IMAGE=${INPUT_IMAGE}
OWNER=${INPUT_OWNER}
USERNAME=${INPUT_USERNAME:-${GITHUB_ACTOR}}
PUBLISH=${INPUT_PUBLISH}
GITHUBREPO=${INPUT_GITHUB_REPOSITORY}
DOCKERREPO=${INPUT_DOCKER_REPOSITORY}

echo "" # https://github.com/actions/toolkit/issues/168

SHA=${GITHUB_SHA:0:7}
if [ -z "${OWNER}" ]; then
  OWNER=${GITHUB_REPOSITORY%%/*}
fi
if [ -z "${GITHUBREPO}" ]; then
  GITHUBREPO=${GITHUB_REPOSITORY#*/}
fi
if [ -z "${DOCKERREPO}" ]; then
  DOCKERREPO=${GITHUB_REPOSITORY#*/}
fi
if [ -z "${IMAGE}" ]; then
  IMAGE=$(echo ${CONTEXT} | sed -e 's|^[.\/]*||' | sed -e 's|[\.\/]*$||')
fi
if [ -z "${IMAGE}" ]; then
  >&2 echo "::error::Unable to find eval image name. Did you set via context or image?"
  exit 1
fi

ref_tmp=${GITHUB_REF#*/}
# extract the second element of the ref (heads or tags or pull)
ref_type=${ref_tmp%%/*}
# extract the third+ elements of the ref (master or 2019/03/13 or 0.1.0)
ref_value=${ref_tmp#*/}

function uses() {
  [ ! -z "${1}" ]
}
function isMaster() {
  [ "${ref_type}" = "heads" -a "${ref_value}" = "master" ]
}
function isBranch() {
  [ $(echo "${GITHUB_REF}" | sed -e 's|refs\/heads\/||g') != "${GITHUB_REF}" ]
}
function isTag() {
  [ $(echo "${GITHUB_REF}" | sed -e 's|refs\/tags\/||g') != "${GITHUB_REF}" ]
}
function isPull() {
  [ $(echo "${GITHUB_REF}" | sed -e 's|refs\/pull\/||g') != "${GITHUB_REF}" ]
}

if isMaster; then
  TAG="latest"
elif isBranch; then
  TAG=$(echo ${ref_value} | sed -e 's|\/|-|g')
elif isTag; then
  TAG=$(echo ${ref_value} | sed -e 's|\/|-|g')
elif isPull; then
  TAG="${SHA}"
else
  >&2 echo "::warning::Ooops... How to tag?"
  exit 0 # 78 # exit neutral
fi;

# temp credential store outside of mounted volumes...
mkdir -m 0700 /.docker
DOCKER_CMD='docker --config="/.docker"'

if [ -n "${INPUT_DOCKER_TOKEN}" ]; then
  echo "Login to ${INPUT_DOCKER_REGISTRY} as ${USERNAME}..."
  echo ${INPUT_DOCKER_TOKEN} | $DOCKER_CMD login -u ${USERNAME} --password-stdin
fi
if [ -n "${INPUT_GITHUB_TOKEN}" ]; then
  echo "Login to ${INPUT_GITHUB_REGISTRY} as ${USERNAME}..."
  echo ${INPUT_GITHUB_TOKEN} | $DOCKER_CMD login ${INPUT_GITHUB_REGISTRY} -u ${USERNAME} --password-stdin
fi

# Arrrghh.. Naming scheme for different registries:
# GitHub:  docker.pkg.github.com/owner/repo/image:tag
# DockerHub:         [docker.io/]owner/repo:tag[-image]
#
# Convention: GitHub and DockerHub using the same login name
#             GitHub and DockerHub using the same image name and owner scheme

$DOCKER_CMD build -t ${IMAGE} ${CONTEXT}

if [ -n "${INPUT_DOCKER_TOKEN}" ]; then
  if uses "${INPUT_IMAGE_SUFFIXING}"; then
    NAME="${OWNER}/${DOCKERREPO}:${TAG}-${IMAGE}"
  else
    NAME="${OWNER}/${DOCKERREPO}:${TAG}"
  fi
  $DOCKER_CMD tag ${IMAGE} ${NAME}
  if uses "${PUBLISH}"; then
    $DOCKER_CMD push ${NAME}
  fi
  $DOCKER_CMD logout
  echo ::set-output name=docker-tag::"${NAME}"
  echo ::set-env name=DOCKER_TAG::"${NAME}"
fi
if [ -n "${INPUT_GITHUB_TOKEN}" ]; then
  NAME="docker.pkg.github.com/${OWNER}/${GITHUBREPO}/${IMAGE}:${TAG}"
  $DOCKER_CMD tag ${IMAGE} ${NAME}
  if uses "${PUBLISH}"; then
    $DOCKER_CMD push ${NAME}
  fi
  $DOCKER_CMD logout ${INPUT_GITHUB_REGISTRY}
  echo ::set-output name=docker-github-tag::"${NAME}"
  echo ::set-env name=DOCKER_GITHUB_TAG::"${NAME}"
fi

# https://github.com/actions/toolkit/blob/master/docs/commands.md
