#!/usr/bin/env bash

kubectl create deployment nginx-deployment --image=nginx:1.14.2 --replicas=3 --port=80
kubectl label deployment nginx-deployment app=nginx

# kubectl create deployment nginx-deployment --image=nginx:1.14.2 --replicas=3 --port=80 --dry-run=client -o yaml | kubectl apply -f -