#!/usr/bin/env bash

# Script that allows users to manual start environments via GitHub workflows and accepts inputs from the workflow

# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/appgateway/common-functions.sh
source scripts/common/common-functions.sh

# Set the SELECTED_ENV and SUBSCRIPTION based on inputs from workflow supplied by the user triggering the workflow via GitHub UI
if [[ $SELECTED_ENV == "sbox" ]]; then
	SELECTED_ENV="box"
fi
if [[ $SELECTED_ENV == "test/perftest" ]] && [[ $PROJECT == "CFT" ]]; then
	SELECTED_ENV="perftest"
elif [[ $SELECTED_ENV == "test/perftest" ]] && [[ $PROJECT == "SDS" ]]; then
	SELECTED_ENV="test"
elif [[ $SELECTED_ENV == "preview/dev" ]] && [[ $PROJECT == "SDS" ]]; then
	SELECTED_ENV="dev"
elif [[ $SELECTED_ENV == "preview/dev" ]] && [[ $PROJECT == "CFT" ]]; then
	SELECTED_ENV="preview"
elif [[ $SELECTED_ENV == "aat/staging" ]] && [[ $PROJECT == "SDS" ]]; then
	SELECTED_ENV="stg"
elif [[ $SELECTED_ENV == "aat/staging" ]] && [[ $PROJECT == "CFT" ]]; then
	SELECTED_ENV="aat"
fi

# Find all subscriptions that are available to the credential used and saved to SUBSCRIPTIONS variable
SUBSCRIPTIONS=$(az account list -o json)

# For each subscription found, start the loop
jq -c '.[]' <<<$SUBSCRIPTIONS | while read subscription; do

    # Function that returns the Subscription Id and Name as variables, sets the subscription as 
    # the default then returns a json formatted variable of available App Gateways with an autoshutdown tag
	get_subscription_flexible_sql_servers
    echo "Scanning $SUBSCRIPTION_NAME..."

	if [[ $PROJECT == "SDS" ]] && [[ $SUBSCRIPTION_NAME =~ "DCD-" ]]; then
		continue
	fi
	if [[ $PROJECT == "CFT" ]] && [[ $SUBSCRIPTION_NAME =~ "SHAREDSERVICES" ]]; then
		continue
	fi

    # For each App Gateway found in the function `get_subscription_flexible_sql_servers` start another loop
	jq -c '.[]' <<<$FLEXIBLE_SERVERS | while read flexibleserver; do

        # Function that returns the Resource Group, Id and Name of the Flexible SQL Server and its current state as variables
		get_flexible_sql_server_details

		# If SERVER_NAME matches the regex of the SELECTED_ENV then continue
		# If SERVER_STATE is not Ready then start the flexible server 
		if [[ $SERVER_NAME =~ $SELECTED_ENV ]]; then
			if [[ "$SERVER_STATE" != *"Ready"* ]]; then
				ts_echo "Starting flexible-server: $SERVER_NAME in Subscription: $SUBSCRIPTION_NAME  ResourceGroup: $RESOURCE_GROUP"
				az postgres flexible-server start --ids $SERVER_ID --no-wait || echo Ignoring error starting $NAME
			fi
		fi
	done
done
