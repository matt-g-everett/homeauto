#!/bin/bash

RABBIT_CHART_VERSION={{rabbit-chart-version}}
FLUENTD_CHART_VERSION='1.10.0'
ELASTICSEARCH_CHART_VERSION='7.2.1-0'
KIBANA_CHART_VERSION='7.2.1-0'

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

namespace='default'
shouldClean=0
shouldDeploy=1

function clean () {
    helm del --purge rabbitmq-ha
    helm del --purge fluentd
    helm del --purge elasticsearch
    helm del --purge kibana
    kubectl delete --recursive -f ${scriptDir}/../k8s
}

function deploy() {
    helm repo add elastic https://helm.elastic.co

    kubectl apply --recursive -f ${scriptDir}/../k8s
    helm install stable/rabbitmq-ha --name rabbitmq-ha --version ${RABBIT_CHART_VERSION} --namespace ${namespace} --values ${scriptDir}/../helm/values/rabbitmq-ha.yaml
    helm install stable/fluentd --name fluentd --version ${FLUENTD_CHART_VERSION} --namespace ${namespace} --values ${scriptDir}/../helm/values/fluentd.yaml
    helm install elastic/elasticsearch --name elasticsearch --version ${ELASTICSEARCH_CHART_VERSION} --namespace ${namespace} --values ${scriptDir}/../helm/values/elasticsearch.yaml
    helm install elastic/kibana --name kibana --version ${KIBANA_CHART_VERSION} --namespace ${namespace} --values ${scriptDir}/../helm/values/kibana.yaml
}

instructionProvided=0
while [ $# -gt 0 ] ; do
    case $1 in
        --clean|-c) shouldClean=1; instructionProvided=1 ; shift 1 ;;
        --deploy|-d) shouldDeploy=1; instructionProvided=1 ; shift 1 ;;
        --namespace|-n) namespace=$2; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done


if [[ instructionProvided -eq 0 || shouldClean -eq 1 ]]; then
    echo "Cleaning ..."
    clean
fi

if [[ instructionProvided -eq 0 || shouldDeploy -eq 1 ]]; then
    echo "Deploying ..."
    deploy
fi
