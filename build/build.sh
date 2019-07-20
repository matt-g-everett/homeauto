#!/bin/bash

RABBIT_CHART_VERSION='1.29.1'

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

shouldDeploy=0

if [[ ! -z "$1" ]]; then
    password=$1
else
    echo "Please add a password as the first parameter."
    exit 1
fi

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
        [[ -f $i ]] && sed -i -e "s/{{password}}/${password}/g" \
        -e "s/{{rabbit-chart-version}}/${RABBIT_CHART_VERSION}/g" \
        $i
    done
}

while [ $# -gt 0 ] ; do
    case $1 in
        --deploy|-d) shouldDeploy=1; shift 1 ;;
        --password|-p) password=$2; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

echo "Building ..."
build
echo "Built"

if [[ shouldDeploy -eq 1 ]]; then
    echo "Calling out/deploy/deploy.sh ..."
    ${scriptDir}/../out/deploy/deploy.sh
fi
