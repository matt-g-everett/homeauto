#!/bin/bash

set -e

RABBIT_CHART_VERSION={{rabbit-chart-version}}

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

namespace=default

shouldClean=0
shouldDeploy=0

function deploy () {
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo up

    kubectl create namespace ${namespace} || true

    # Apply the rabbitmq nodeports
    kubectl -n ${namespace} apply --recursive -f ${scriptDir}/../k8s-auto/rabbitmq/nodeports.yaml

    helm install rabbitmq bitnami/rabbitmq --version ${RABBIT_CHART_VERSION} --namespace ${namespace} --values ${scriptDir}/../helm/values/rabbitmq.yaml
}

function clean () {
    helm del rabbitmq -n ${namespace} || true

    # Remove the k8s resources
    kubectl -n ${namespace} delete --recursive -f ${scriptDir}/../k8s-auto/rabbitmq/nodeports.yaml || true
}

while [ $# -gt 0 ] ; do
    case $1 in
        --clean|-c) shouldClean=1; shift 1 ;;
        --deploy|-d) shouldDeploy=1; shift 1 ;;
        --namespace|-n) namespace=$2; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ shouldClean -eq 1 ]]; then
    echo "Cleaning ..."
    clean
fi

if [[ shouldDeploy -eq 1 ]]; then
    echo "Deploying ..."
    deploy
fi
