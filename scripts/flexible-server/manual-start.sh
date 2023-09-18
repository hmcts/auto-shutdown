#!/usr/bin/env bash

function ts_echo() {
	date +"%H:%M:%S $(printf "%s " "$@")"
}

SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<<$SUBSCRIPTIONS | while read subcription; do
	SUBSCRIPTION_ID=$(jq -r '.id' <<<$subcription)
	SUBSCRIPTION_NAME=$(jq -r '.name' <<<$subcription)
	if [[ $PROJECT == "SDS" ]] && [[ $SUBSCRIPTION_NAME =~ "DCD-" ]]; then
		continue
	fi
	if [[ $PROJECT == "CFT" ]] && [[ $SUBSCRIPTION_NAME =~ "SHAREDSERVICES" ]]; then
		continue
	fi
	az account set -s $SUBSCRIPTION_ID
    if [[ $SELECTED_ENV == "sbox" ]]; then
        SELECTED_ENV="box"
    fi
	SERVERS=$(az resource list --resource-type Microsoft.DBforPostgreSQL/flexibleServers --query "[?tags.autoShutdown == 'true']" -o json)
	jq -c '.[]' <<<$SERVERS | while read server; do
		ID=$(jq -r '.id' <<<$server)
		NAME=$(jq -r '.name' <<<$server)
		if [[ $NAME =~ $SELECTED_ENV ]]; then
			status=$(az postgres flexible-server show --ids $ID --query "state")
			if [[ "$status" != *"Ready"* ]]; then
				ts_echo "Starting flexible-server show  in Subscription: $(az account show --query name)  ResourceGroup: $(jq -r '.resourceGroup' <<<$server)  Name: $NAME"
				az postgres flexible-server start --ids $ID --no-wait || echo Ignoring error starting $NAME
			fi
		fi
	done
done
