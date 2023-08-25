#!/usr/bin/env bash
SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<<$SUBSCRIPTIONS | while read subcription; do
	SUBSCRIPTION_ID=$(jq -r '.id' <<<$subcription)
	az account set -s $SUBSCRIPTION_ID
	VMS=$(az resource list --resource-type Microsoft.Compute/virtualMachines --query "[?tags.autoShutdown == 'true']" -o json)
	jq -c '.[]' <<<$VMS | while read vm; do
		ID=$(jq -r '.id' <<<$vm)
		status=$(az vm show -d --ids $ID --query "powerState")
		if [[ "$status" != *"running"* ]]; then
			echo "Starting VM in Subscription: $(az account show --query name)  ResourceGroup: $(jq -r '.resourceGroup' <<<$vm)  Name: $(jq -r '.name' <<<$vm)"
			az vm start --ids $ID --no-wait || echo Ignoring errors Stopping VM
		fi
	done
done
