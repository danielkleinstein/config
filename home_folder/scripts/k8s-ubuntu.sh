#!/bin/bash

NAMESPACE_ARG=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -n|--namespace) NAMESPACE_ARG="--namespace=$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

kubectl run ubuntu --image=ubuntu $NAMESPACE_ARG --rm -it -- bash
