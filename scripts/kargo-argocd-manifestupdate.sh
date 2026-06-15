#!/bin/bash
set -e

for stage in $(kargo get stages --project kargo-simple -o jsonpath='{.items[*].metadata.name}')
do
	kargo get stage "${stage}" -p kargo-simple -o json | jq --arg stage "${stage}" '.spec.promotionMechanisms.argoCDAppUpdates[0].appName = $stage' | kargo apply -f -
done
