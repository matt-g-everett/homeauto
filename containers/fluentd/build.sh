#!/bin/bash

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

docker build ${SCRIPT_DIR} -t matteverett/fluentd:{{fluentd-tag}}
