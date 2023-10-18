#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <name-selector> <partial-node-name>"
    exit 1
fi

LABEL_SELECTOR=name=$1
PARTIAL_NODE_NAME=$2

IFS=$'\n' NODE_MATCHES=($(kubectl get nodes --no-headers | awk '{print $1}' | fzf -q "$PARTIAL_NODE_NAME" --select-1 --exit-0))

if [ "${#NODE_MATCHES[@]}" -eq 0 ]; then
    echo "No node found with name matching $PARTIAL_NODE_NAME"
    exit 2
fi

FULL_NODE_NAME="${NODE_MATCHES[0]}"

PODS=$(kubectl get pods -l "$LABEL_SELECTOR" --field-selector=spec.nodeName="$FULL_NODE_NAME" -o=jsonpath='{.items[*].metadata.name}')
NUM_PODS=$(echo "$PODS" | wc -w)

if [ "$NUM_PODS" -eq 0 ]; then
    echo "No pod found running on node $FULL_NODE_NAME"
    exit 4
elif [ "$NUM_PODS" -gt 1 ]; then
    echo "Error: More than one pod found running on node $FULL_NODE_NAME"
    exit 5
fi

POD_NAME=$(echo "$PODS" | awk '{print $1}')

echo "$POD_NAME"