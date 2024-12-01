#!/bin/bash

RABBIT_CHART_VERSION='7.6.8'
ELASTIC_VERSION='7.9.2'
FLUENTD_TAG='1.11.2-debian-10-r35'

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

shouldDeploy=false
shouldDeployRabbit=false
deployArgs=''
adminUser=admin

# Enable glob
shopt -s extglob
shopt -s globstar

function build () {
    # Copy everything into the out directory (except the out directory and the build scripts)
    local outDir=${scriptDir}/../out
    rm -rf ${outDir}
    mkdir ${outDir}
    cp -R ${scriptDir}/../!(out|build) ${outDir}

    local base64Password=$(echo ${password} | base64)

    # Replace all template params
    for i in ${outDir}/**/*; do
        [[ -f ${i} ]] && sed -i \
            -e "s/{{admin-user}}/${adminUser}/g" \
            -e "s/{{password}}/${password}/g" \
            -e "s/{{password-base64}}/${base64Password}/g" \
            -e "s/{{fluentd-tag}}/${FLUENTD_TAG}/g" \
            -e "s/{{rabbit-chart-version}}/${RABBIT_CHART_VERSION}/g" \
            -e "s/{{elastic-version}}/${ELASTIC_VERSION}/g" \
            ${i}
    done
}

while [ $# -gt 0 ] ; do
    case $1 in
        --user|-u) adminUser=$2; shift 2 ;;
        --password|-p) password=$2; shift 2 ;;
        --deploy|-d) shouldDeploy=true; shift 1 ;;
        --deploy-rabbit|-r) shouldDeployRabbit=true; shift 1 ;;
        --) shift 1;  deployArgs=$@; break ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ -z "${password}" ]]; then
    echo "Please set the admin password"
    exit 1
fi

build
echo "Built deployment"

if ${shouldDeployRabbit}; then
    echo "Calling out/deploy/deploy-rabbit.sh with ${deployArgs} ..."
    "${scriptDir}"/../out/deploy/deploy-rabbit.sh ${deployArgs}
elif ${shouldDeploy}; then
    echo "Calling out/deploy/deploy.sh with ${deployArgs} ..."
    "${scriptDir}"/../out/deploy/deploy.sh ${deployArgs}
fi
