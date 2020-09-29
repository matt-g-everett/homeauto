#!/usr/bin/env python

import argparse

import yaml

def main():
    parser = argparse.ArgumentParser(description='Convert application deployment config into commands.')
    parser.add_argument('--config', '-c', dest='config', help='YAML config file')
    parser.add_argument('--namespace', '-n', dest='namespace', default='default', help='K8s namespace')
    args = parser.parse_args()

    with open(args.config, 'r') as f:
        config = yaml.load(f, Loader=yaml.FullLoader)

    namespace = args.namespace

    for action in config['actions']:
        if action['type'] == 'kube-resource':
            if 'dir' in action:
                location = action['dir']
                recursive = ' --recursive'
            else:
                location = action['file']
                recursive = ''

            cmd = f'kubectl -n {namespace} apply{recursive} -f {location}'
        elif action['type'] == 'chart':
            wait = ' --wait' if action.get('wait', False) else ''
            values = f' --values {action["values"]}' if 'values' in action else ''
            cmd = f'helm install {action["chartName"]}{wait} --version {action["version"]} --name {action["chartName"]} --namespace {namespace}{values}'
        elif action['type'] == 'kube-wait':
            timeout = f' --timeout {action["timeout"]}' if 'timeout' in action else ''
            cmd = f'kubectl wait{timeout} --for={action["condition"]} {action["resource"]}'
        else:
            cmd = ''

        print(cmd)

if __name__ == '__main__':
    main()
