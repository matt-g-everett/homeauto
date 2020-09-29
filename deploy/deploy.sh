#!/bin/bash

set -e

CERTMAN_CHART_VERSION='v1.0.2'
OPENEBS_CHART_VERSION='1.12.3'
RABBIT_CHART_VERSION={{rabbit-chart-version}}
FLUENTD_CHART_VERSION='2.2.2'
ELASTICSEARCH_CHART_VERSION='7.6.0'
KIBANA_CHART_VERSION='7.6.0'

declare -A PV_GROUPS
PV_GROUPS[elasticsearch-master-elasticsearch-master-0]=noncore

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

namespace=default
certmanNamespace=cert-manager
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
    kubectl create namespace ${certmanNamespace} 2>/dev/null || true
    kubectl --namespace ${certmanNamespace} delete secret ${issuerSecretName} 2>/dev/null || true
    kubectl --namespace ${certmanNamespace} create secret tls ${issuerSecretName} --cert ${tempCertDir}/ca.crt --key ${tempCertDir}/ca.key

    # Copy the CA certificate into the central store
    sudo cp ${tempCertDir}/ca.crt /usr/local/share/ca-certificates/issuer-tls.crt
    sudo update-ca-certificates

    rm -rf ${tempCertDir}
}

function clean_core () {
    kubectl -n ${namespace} delete -f ${scriptDir}/../triggered/openebs/sc-retain.yaml || true
    helm del openebs -n ${namespace} || true
    kubectl delete -f ${scriptDir}/../triggered/cert-manager/issuer.yaml || true
    helm del cert-manager -n ${certmanNamespace} || true
}

function clean_pvc () {
    kubectl -n ${namespace} delete pvc elasticsearch-master-elasticsearch-master-0 || true
}

function clean_core_pvc () {
    : # No core PVCs yet
}

function delete_group () {
    pv_info=$(kubectl get pv -o go-template="{{- range .items -}}{{ printf \"%s %s %s\n\" .metadata.name .spec.claimRef.name .spec.local.path }}{{ end }}")
    while read -r name claim path; do
        if [[ ! -z "${name}" && "${PV_GROUPS[${claim}]}" == "$1" ]]; then
            echo "Deleting PV ${name} for PVC ${claim} at ${path}"
            kubectl delete pv ${name}
            sudo rm -rf "${path}"
        fi
    done <<< ${pv_info}
}

function clean_pv () {
    delete_group noncore
}

function clean_core_pv () {
    delete_group core
}

function clean () {
    helm del rabbitmq -n ${namespace} || true
    helm del fluentd -n ${namespace} || true
    kubectl -n ${namespace} delete job es-set-templates || true
    helm del elasticsearch -n ${namespace} || true
    helm del kibana -n ${namespace} || true

    kubectl -n ${namespace} delete --recursive -f ${scriptDir}/../k8s || true
}

function deploy_core () {
    helm repo add jetstack https://charts.jetstack.io
    helm repo add openebs https://openebs.github.io/charts
    helm repo up

    kubectl create namespace ${certmanNamespace} || true
    kubectl create namespace ${namespace} || true

    # These installs can be done in parallel
    (
    helm install cert-manager jetstack/cert-manager --wait --version ${CERTMAN_CHART_VERSION} --namespace ${certmanNamespace} --values ${scriptDir}/../helm/values/cert-manager.yaml
    while ! kubectl apply -f ${scriptDir}/../triggered/cert-manager/issuer.yaml 2>/dev/null; do
        echo "Retrying issuer creation..."
        sleep 10
    done
    echo "Created issuer"
    ) &

    (
    helm install openebs openebs/openebs --wait --version ${OPENEBS_CHART_VERSION} --namespace ${namespace} --values ${scriptDir}/../helm/values/openebs.yaml
    kubectl -n ${namespace} apply -f ${scriptDir}/../triggered/openebs/sc-retain.yaml
    ) &

    wait
}

function deploy () {
    helm repo add elastic https://helm.elastic.co
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo up

    kubectl -n ${namespace} apply --recursive -f ${scriptDir}/../k8s

    (
    echo "Installing elasticsearch ..."
    helm install elasticsearch elastic/elasticsearch --wait --version ${ELASTICSEARCH_CHART_VERSION} --namespace ${namespace} --values ${scriptDir}/../helm/values/elasticsearch.yaml
    echo "Creating elasticsearch index job ..."
    kubectl -n ${namespace} apply -f ${scriptDir}/../triggered/elasticsearch/index-job.yaml
    echo "Waiting for elasticsearch index to be set ..."
    kubectl -n ${namespace} wait --timeout 300s --for=condition=complete job/es-set-templates
    echo "Deleting index job"
    kubectl -n ${namespace} delete job es-set-templates
    helm install kibana elastic/kibana --version ${KIBANA_CHART_VERSION} --namespace ${namespace} --values ${scriptDir}/../helm/values/kibana.yaml
    ) &

    helm install rabbitmq bitnami/rabbitmq --version ${RABBIT_CHART_VERSION} --namespace ${namespace} --values ${scriptDir}/../helm/values/rabbitmq.yaml
    helm install fluentd bitnami/fluentd --version ${FLUENTD_CHART_VERSION} --namespace ${namespace} --values ${scriptDir}/../helm/values/fluentd.yaml

    wait
}

while [ $# -gt 0 ] ; do
    case $1 in
        --clean|-c) shouldClean=1; instructionProvided=1; shift 1 ;;
        --deploy|-d) shouldDeploy=1; instructionProvided=1; shift 1 ;;
        --core) includeCore=1; shift 1 ;;
        --pvc) includePVC=1; shift 1 ;;
        --pv) includePV=1; includePVC=1; shift 1 ;;
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
        if [[ includePVC -eq 1 && includeCore -eq 1 ]]; then
            echo "Cleaning core PVCs ..."
            clean_core_pvc
        fi

        if [[ includePV -eq 1 ]]; then
            echo "Cleaning PVs ..."
            clean_pv
        fi
        if [[ includePV -eq 1 && includeCore -eq 1 ]]; then
            echo "Cleaning core PVs ..."
            clean_core_pv
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
