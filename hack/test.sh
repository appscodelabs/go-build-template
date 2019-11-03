#!/usr/bin/env bash

set -eou pipefail

export CGO_ENABLED=0
export GO111MODULE=on
export GOFLAGS="-mod=vendor"

TARGETS=$(for d in "$@"; do echo ./$d/...; done)

echo "Running tests:"
go test -installsuffix "static" ${TARGETS}
echo
