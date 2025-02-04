#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

build=false
containerized=false

while getopts "h?bc" opt; do
    case "$opt" in
        h|\?)
            usage
            exit 0
            ;;
        b)
            build=true
            ;;
        c)
            containerized=true ;;
        esac
done

KUBE_ROOT=$GOPATH/src/k8s.io/kubernetes
cd $KUBE_ROOT
VERSION=$(./hack/print-workspace-status.sh | awk '/gitVersion/ {print $2}')
echo "Kubernetes version: $VERSION"

if $containerized; then
    export DOCKERIZE_KUBELET=y
else
    export DOCKERIZE_KUBELET=
fi

if $build; then
    (
        # build
        source "${KUBE_ROOT}/build/common.sh"
        kube::build::verify_prereqs
        kube::build::build_image
        kube::build::run_build_command make WHAT="cmd/hyperkube cmd/kubectl"
        kube::build::copy_output

        # build image if we are going to run kubelet in container
        if [ -n "$DOCKERIZE_KUBELET" ]; then
            ARCH=amd64 REGISTRY=k8s.gcr.io VERSION=latest \
                make -C cluster/images/hyperkube/ build
            docker tag k8s.gcr.io/hyperkube-amd64:latest k8s.gcr.io/kubelet:latest
        fi
    )
fi

export LOG_LEVEL=5
export ALLOW_PRIVILEGED=true
export FEATURE_GATES="${FEATURE_GATES:-}"
# export FEATURE_GATES="BlockVolume=true"
# export FEATURE_GATES="PersistentLocalVolumes=true,VolumeScheduling=true,MountPropagation=true"
export FEATURE_GATES="$FEATURE_GATES,CSINodeInfo=true,CSIDriverRegistry=true"
# export FEATURE_GATES="VolumeScheduling=true,EnableEquivalenceClassCache=true"
export KEEP_TERMINATED_POD_VOLUMES=false
./hack/local-up-cluster.sh -o ./_output/dockerized/bin/linux/amd64
