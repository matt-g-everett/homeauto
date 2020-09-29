#!/bin/bash

RABBIT_CHART_VERSION='7.6.8'
FLUENTD_TAG='1.11.2-debian-10-r35'

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

shouldDeploy=false
deployArgs=''

# Enable glob
shopt -s extglob
shopt -s globstar

function build () {
    # Copy everything into the out directory (except the out directory and the build scripts)
    outDir=${scriptDir}/../out
    rm -rf ${outDir}
    mkdir ${outDir}
    cp -R ${scriptDir}/../!(out|build) ${outDir}

    # Replace all template params
    for i in ${outDir}/**/*; do
        [[ -f $i ]] && sed -i \
            -e "s/{{password}}/${password}/g" \
            -e "s/{{fluentd-tag}}/${FLUENTD_TAG}/g" \
            -e "s/{{rabbit-chart-version}}/${RABBIT_CHART_VERSION}/g" \
            $i
    done
}

while [ $# -gt 0 ] ; do
    case $1 in
        --password|-p) password=$2; shift 2 ;;
        --deploy|-d) shouldDeploy=true; shift 1 ;;
        --) shift 1;  deployArgs=$@; break ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

build
echo "Built deployment"

if ${shouldDeploy}; then
    echo "Calling out/deploy/deploy.sh with ${deployArgs} ..."
    ${scriptDir}/../out/deploy/deploy.sh ${deployArgs}
fi
