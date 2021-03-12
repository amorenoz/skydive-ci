#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

OS=linux
ARCH=amd64
TARGET_DIR=/usr/bin

KIND_VERSION="v0.10.0"
KIND_URL="https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"

K8S_VERSION="v1.20.2"
KUBECTL_URL="https://storage.googleapis.com/kubernetes-release/release/$K8S_VERSION/bin/$OS/$ARCH/kubectl"

OVNKUBE_VERSION=47f858766e1da035aabc136de55612d89c88f492
OVNKUBE_URL=https://github.com/ovn-org/ovn-kubernetes/archive/${OVNKUBE_VERSION}.zip
OVNKUBE_PATH=ovn-kubernetes-${OVNKUBE_VERSION}

install_binary() {
        local prog=$1
        local url=$2

        wget --no-check-certificate -O $prog $url
        if [ $? != 0 ]; then
                echo "failed to download $url"
                exit 1
        fi

        chmod a+x $prog
        sudo mv $prog $TARGET_DIR/$prog
}

uninstall_binary() {
        local prog=$1
        sudo rm -f $TARGET_DIR/$prog
}

install() {
    install_binary kind ${KIND_URL}
    install_binary kubectl ${KUBECTL_URL}

    curl -Lo ovnkube.zip ${OVNKUBE_URL}
    unzip ovnkube.zip
}

uninstall() {
    uninstall_binary kind
    uninstall_binary kubectl

    rm -rf ovn-kubernetes-${OVNKUBE_VERSION}
    rm -rf ovnkube.zip

}

start() {
    # According to https://github.com/ovn-org/ovn-kubernetes/blob/47f858766e1da035aabc136de55612d89c88f492/docs/kind.md we need to open this port
    sudo firewall-cmd --permanent --add-port=11337/tcp; sudo firewall-cmd --reload || true
    ( cd $OVNKUBE_PATH
    pushd go-controller
      make
    popd
    pushd dist/images
    ## Use quay.io instead of default docker hub to avoid hitting the maximum allowed pulls
      sed -i 's/FROM fedora:33/FROM quay.io\/fedora\/fedora:33-x86_64/' Dockerfile.fedora
      make fedora
    popd
    pushd contrib
      export K8S_VERSION
      ./kind.sh
    popd
    )
    mkdir -p $HOME/.kube
    cp $HOME/admin.conf $HOME/.kube/config
}

stop() {
    ( cd $OVNKUBE_PATH
    pushd contrib
      ./kind.sh --delete
    popd
    )

    rm $HOME/.kube/config
    
}

case "$1" in
        install)
                install
                ;;
        uninstall)
                uninstall
                ;;
        start)
                start
                ;;
        stop)
                stop
                ;;
        status)
                status
                ;;
        *)
                echo "$0 [install|uninstall|start|stop|status]"
                exit 1
                ;;
esac
