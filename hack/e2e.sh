#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

ROOT=$(unset CDPATH && cd $(dirname "${BASH_SOURCE[0]}")/.. && pwd)
cd $ROOT

build=false
while getopts "b" opt; do
    case "$opt" in
        b)
        build=true
        ;;
    esac
done

if [ "${1:-}" == "--" ]; then
    shift
fi

source "$ROOT/hack/env.sh"

if $build; then
    (
        KUBE_ROOT=$GOPATH/src/k8s.io/kubernetes
        cd $KUBE_ROOT
        make WHAT=test/e2e/e2e.test
    )
fi

# gce
kubetest_args+=(
    --provider "gce"
    --gcp-project "$GCP_PROJECT"
    --gcp-zone "$GCP_ZONE"
    --gcp-service-account "$GOOGLE_APPLICATION_CREDENTIALS"
    --deployment "bash"
)

# append extra arguments
kubetest_args+=(
    $@
)

cd $GOPATH/src/k8s.io/kubernetes
go run $GOPATH/src/k8s.io/kubernetes/hack/e2e.go -old 240000h -- \
    "${kubetest_args[@]}"
