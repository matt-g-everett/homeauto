#!/bin/bash

RABBIT_CHART_VERSION={{rabbit-chart-version}}
FLUENTD_CHART_VERSION='1.10.0'

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

namespace='default'

function clean () {
    helm del --purge rabbitmq-ha
    helm del --purge fluentd
    kubectl delete --recursive -f ${scriptDir}/../k8s
}

function deploy() {
    kubectl apply --recursive -f ${scriptDir}/../k8s
    helm install stable/rabbitmq-ha --name rabbitmq-ha --version ${RABBIT_CHART_VERSION} --namespace ${namespace} --values ${scriptDir}/../helm/values/rabbitmq-ha.yaml
    helm install stable/fluentd --name fluentd --version ${FLUENTD_CHART_VERSION} --namespace ${namespace}
}

clean
deploy
