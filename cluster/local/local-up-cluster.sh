#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

build=false

while getopts "h?b" opt; do
    case "$opt" in
        h|\?)
            usage
            exit 0
            ;;
        b)
            build=true
            ;;
        esac
done

KUBE_ROOT=$GOPATH/src/k8s.io/kubernetes
cd $KUBE_ROOT

export LOG_LEVEL=5
export ALLOW_PRIVILEGED=true
export DOCKERIZE_KUBELET=y
export ENABLE_CLUSTER_DNS=true
export DNS_SERVER_IP=10.0.0.10

if $build; then
    (
        # build
        source "${KUBE_ROOT}/build/common.sh"
        kube::build::verify_prereqs
        kube::build::build_image
        kube::build::run_build_command make WHAT=cmd/hyperkube
        kube::build::copy_output

        # build image if we are going to run kubelet in container
        if [ -n "$DOCKERIZE_KUBELET" ]; then
            ARCH=amd64 REGISTRY=k8s.gcr.io VERSION=latest \
                make -C cluster/images/hyperkube/ build
            docker tag k8s.gcr.io/hyperkube-amd64:latest k8s.gcr.io/kubelet:latest
        fi
    )
fi

sysctl -w fs.inotify.max_user_watches=1048576
./hack/local-up-cluster.sh -o ./_output/dockerized/bin/linux/amd64
