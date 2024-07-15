#!/usr/bin/env bash

# Create the Service
kubectl create service clusterip nginx --tcp=80:80 --dry-run=client -o yaml | kubectl apply -f -

# Create the StatefulSet
kubectl create statefulset web --image=registry.k8s.io/nginx-slim:0.24 --replicas=3 --service=nginx --port=80 --dry-run=client -o yaml | kubectl apply -f -

# Patch the StatefulSet to add additional settings
kubectl patch statefulset web --type='json' -p='[
  {"op": "add", "path": "/spec/minReadySeconds", "value": 10},
  {"op": "add", "path": "/spec/template/spec/terminationGracePeriodSeconds", "value": 10},
  {"op": "add", "path": "/spec/template/spec/containers/0/volumeMounts", "value": [{"name": "www", "mountPath": "/usr/share/nginx/html"}]},
  {"op": "add", "path": "/spec/volumeClaimTemplates", "value": [
    {
      "metadata": {
        "name": "www"
      },
      "spec": {
        "accessModes": ["ReadWriteOnce"],
        "storageClassName": "my-storage-class",
        "resources": {
          "requests": {
            "storage": "1Gi"
          }
        }
      }
    }
  ]}
]'
