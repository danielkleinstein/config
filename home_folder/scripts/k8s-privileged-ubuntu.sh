#!/bin/bash

NAMESPACE_ARG=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--namespace) NAMESPACE_ARG="--namespace=$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

kubectl run ubuntu --image=ubuntu --overrides='{ "spec": { "hostPID": true, "containers": [ { "name": "ubuntu", "image": "ubuntu", "securityContext": { "privileged": true }, "command": ["sleep", "infinity"] } ] } }'
kubectl exec -it ubuntu -- bash

# nsenter -t 1 -m -u -n -i bash
# ^ Opens up a shell in the host's namespaces

# kubectl run ubuntu --image=ubuntu --overrides='{ "spec": { "hostPID": true, "containers": [ { "name": "ubuntu", "image": "ubuntu", "securityContext": { "privileged": true }, "command": ["sleep", "infinity"] } ] , "nodeSelector": { "kubernetes.io/hostname": "ip-10-0-2-189.ec2.internal" } } }'
# ^ Runs it on a specific node