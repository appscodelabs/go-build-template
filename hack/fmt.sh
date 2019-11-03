#!/usr/bin/env bash

set -eou pipefail

export CGO_ENABLED=0
export GO111MODULE=on
export GOFLAGS="-mod=vendor"

TARGETS="$@"

if [ -n "$TARGETS" ]; then
    echo "Running reimport.py"
    cmd="reimport3.py ${REPO_PKG} ${TARGETS}"
    $cmd
    echo

    echo "Running goimports:"
    cmd="goimports -w ${TARGETS}"
    echo "$cmd"
    $cmd
    echo

    echo "Running gofmt:"
    cmd="gofmt -s -w ${TARGETS}"
    echo "$cmd"
    $cmd
    echo
fi

echo "Running shfmt:"
cmd="find . -path ./vendor -prune -o -name '*.sh' -exec shfmt -l -w -ci -i 4 {} \;"
echo "$cmd"
eval "$cmd" # xref: https://stackoverflow.com/a/5615748/244009
echo
