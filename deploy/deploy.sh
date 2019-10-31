#!/bin/bash

CERTMAN_CHART_VERSION='v0.11.0'
OPENEBS_CHART_VERSION='1.3.1'
DOCKER_REGISTRY_VERSION='1.8.3'
RABBIT_CHART_VERSION={{rabbit-chart-version}}
FLUENTD_CHART_VERSION='1.10.0'
ELASTICSEARCH_CHART_VERSION='7.2.1-0'
KIBANA_CHART_VERSION='7.2.1-0'

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

namespace=default
certmanNamespace=certman
issuerSecretName=issuer-tls

instructionProvided=0
shouldClean=0
shouldDeploy=0
initialiseCA=0
includeCore=0
includePVC=0
includePV=0

function create_ca () {
    # Create the root CA cert for the issuer
    tempCertDir=$(mktemp -d)
    openssl genrsa -out ${tempCertDir}/ca.key 2048
    openssl req -x509 -new -nodes -key ${tempCertDir}/ca.key -subj '/CN=standardnerd.io' -days 3650 -reqexts v3_req -extensions v3_ca -out ${tempCertDir}/ca.crt
    kubectl create namespace ${namespace} 2>/dev/null || true
    kubectl create secret tls ${issuerSecretName} --cert ${tempCertDir}/ca.crt --key ${tempCertDir}/ca.key --namespace ${namespace}
    rm -rf ${tempCertDir}
}

function clean_core () {
    helm del --purge docker-registry
    helm del --purge openebs
    kubectl -n ${namespace} delete -f ${scriptDir}/../core/cert-manager/issuer.yaml
    helm del --purge cert-manager
    kubectl -n ${namespace} delete -f ${scriptDir}/../core/cert-manager/00-crds.yaml
}

function clean_pvc () {
    kubectl -n ${namespace} delete pvc elasticsearch-master-elasticsearch-master-0
    kubectl -n ${namespace} delete pvc docker-registry
}

function clean_pv () {
    # Delete all openebs hostpath PVs
    kubectl delete pv -l openebs.io/cas-type=local-hostpath
    sudo rm -rf /var/openebs/local/pvc-*
}

function clean () {
    helm del --purge rabbitmq-ha
    helm del --purge fluentd
    helm del --purge elasticsearch
    helm del --purge kibana

    kubectl -n ${namespace} delete --recursive -f ${scriptDir}/../k8s
    kubectl -n ${namespace} delete secret docker-registry-tls
    kubectl -n ${namespace} delete --recursive -f ${scriptDir}/../crds
}

function deploy_core () {
    helm repo add jetstack https://charts.jetstack.io
    helm repo up

    kubectl -n ${namespace} apply -f ${scriptDir}/../core/cert-manager/00-crds.yaml
    helm install jetstack/cert-manager --wait --name cert-manager --version ${CERTMAN_CHART_VERSION} --namespace ${certmanNamespace} --values ${scriptDir}/../helm/values/cert-manager.yaml
    kubectl -n ${namespace} apply -f ${scriptDir}/../core/cert-manager/issuer.yaml

    helm install stable/openebs --wait --name openebs --version ${OPENEBS_CHART_VERSION} --namespace ${namespace} --values ${scriptDir}/../helm/values/openebs.yaml
    
    kubectl -n ${namespace} apply -f ${scriptDir}/../core/docker-registry/tls-certificate.yaml
    sleep 5
    helm install stable/docker-registry --wait --name docker-registry --version ${DOCKER_REGISTRY_VERSION} --namespace ${namespace} --values ${scriptDir}/../helm/values/docker-registry.yaml
}

function deploy () {
    helm repo add elastic https://helm.elastic.co
    helm repo up

    #kubectl -n ${namespace} apply --recursive -f ${scriptDir}/../crds
    kubectl -n ${namespace} apply --recursive -f ${scriptDir}/../k8s
    helm install stable/rabbitmq-ha --name rabbitmq-ha --version ${RABBIT_CHART_VERSION} --namespace ${namespace} --values ${scriptDir}/../helm/values/rabbitmq-ha.yaml
    helm install stable/fluentd --name fluentd --version ${FLUENTD_CHART_VERSION} --namespace ${namespace} --values ${scriptDir}/../helm/values/fluentd.yaml
    helm install elastic/elasticsearch --name elasticsearch --version ${ELASTICSEARCH_CHART_VERSION} --namespace ${namespace} --values ${scriptDir}/../helm/values/elasticsearch.yaml
    helm install elastic/kibana --name kibana --version ${KIBANA_CHART_VERSION} --namespace ${namespace} --values ${scriptDir}/../helm/values/kibana.yaml
}

while [ $# -gt 0 ] ; do
    case $1 in
        --clean|-c) shouldClean=1; instructionProvided=1; shift 1 ;;
        --deploy|-d) shouldDeploy=1; instructionProvided=1; shift 1 ;;
        --core) includeCore=1; shift 1 ;;
        --pvc) includePVC=1; shift 1 ;;
        --pv) includePV=1; includePVC=1; shift ;;
        --ca) initialiseCA=1; shift 1 ;;
        --namespace|-n) namespace=$2; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ initialiseCA -eq 1 ]]; then
    echo "Initialising CA ..."
    create_ca
else
    if [[ instructionProvided -eq 0 || shouldClean -eq 1 ]]; then
        echo "Cleaning ..."
        clean
        
        if [[ includeCore -eq 1 ]]; then
            echo "Cleaning core ..."
            clean_core
        fi

        if [[ includePVC -eq 1 ]]; then
            echo "Cleaning PVCs ..."
            clean_pvc
        fi

        if [[ includePV -eq 1 ]]; then
            echo "Cleaning PVs ..."
            clean_pv
        fi
    fi

    if [[ instructionProvided -eq 0 || shouldDeploy -eq 1 ]]; then
        if [[ includeCore -eq 1 ]]; then
            echo "Deploying core ..."
            deploy_core
        fi
        
        echo "Deploying ..."
        deploy
    fi
fi
