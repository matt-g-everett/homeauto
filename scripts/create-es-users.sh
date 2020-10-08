#!/bin/bash

SECRET_NAME=eck-es-homeauto-filerealm

dockerId=$(docker run --rm -d docker.elastic.co/elasticsearch/elasticsearch:{{elastic-version}} bash -c 'while true; do sleep 10; done')
docker exec -it ${dockerId} elasticsearch-users useradd homeauto -p {{password}} -r superuser
docker exec -it ${dockerId} elasticsearch-users useradd {{admin-user}} -p {{password}} -r superuser

usersFile=$(mktemp)
docker exec -it ${dockerId} cat /usr/share/elasticsearch/config/users > ${usersFile}

rolesFile=$(mktemp)
docker exec -it ${dockerId} cat /usr/share/elasticsearch/config/users_roles > ${rolesFile}

kubectl create secret generic ${SECRET_NAME} --from-file=users=${usersFile} --from-file=users_roles=${rolesFile}

rm ${usersFile}
rm ${rolesFile}
docker stop ${dockerId} 1>/dev/null
