# Categorisation

- Application install sequence
    - Pre-chart K8s YAML (e.g. CRDs)
    - Helm chart
    - Post-chart K8s YAML (e.g. initialisation jobs)
    - kubectl wait conditions

- Application pipelining
  - Terraform
  - remote-exec

- Layers
    - Host (Ansible)
    - K8s (Kubespray)
    - Platform L1 (cert-manager, openebs, istio)
    - Platform L2 (docker registry, chartmuseum, ingress controller, API gateway, LDAP server, IAM server)
    - Platform L3 (elasticsearch, kibana, fluentd)
    - Application (iotd, xmasd)
