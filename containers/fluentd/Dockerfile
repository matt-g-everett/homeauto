FROM bitnami/fluentd:{{fluentd-tag}}
LABEL maintainer "Bitnami <containers@bitnami.com>"

## Install custom Fluentd plugins
RUN fluent-gem install 'fluent-plugin-rabbitmq'
