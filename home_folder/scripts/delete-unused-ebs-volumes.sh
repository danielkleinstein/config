#!/bin/bash

VOLUMES=$(aws ec2 describe-volumes --filters Name=status,Values=available --query "Volumes[*].[VolumeId]" --output text)

for VOL in $VOLUMES; do
    echo "Deleting volume: $VOL"
    aws ec2 delete-volume --volume-id $VOL
done