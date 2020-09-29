#!/bin/bash

scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

config="${scriptDir}/../es-actions.yaml"
cmds="$(python ${scriptDir}/actions-to-cmds.py --config ${config})"

while read cmd; do
    echo ${cmd}
done <<< "${cmds}"
