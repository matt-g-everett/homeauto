#!/bin/bash

secretName=$1
certFileName=$2

kubectl get secrets ${secretName} -o go-template="{{ index .data \"${certFileName}\" }}" | base64 --decode | openssl x509 -in - -text -noout
