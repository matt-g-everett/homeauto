#!/bin/bash

RABBIT_CHART_VERSION='1.29.1'

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [[ ! -z "$1" ]]; then
    password=$1
else
    echo "Please add a password as the first parameter."
    exit 1
fi

# Enable glob
shopt -s extglob
shopt -s globstar

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
