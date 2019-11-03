#!/usr/bin/env bash

set -eou pipefail

export CGO_ENABLED=0
export GO111MODULE=on
export GOFLAGS="-mod=vendor"

GINKGO_ARGS=${GINKGO_ARGS:-}
TEST_ARGS=${TEST_ARGS:-}
DOCKER_REGISTRY=${DOCKER_REGISTRY:-}

echo "Running e2e tests:"
cmd="ginkgo -r --v --stream --progress --trace ${GINKGO_ARGS} test -- --v=5 ${TEST_ARGS}"
echo "$cmd"
$cmd
