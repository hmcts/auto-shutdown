#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/appgateway/common-functions.sh
source scripts/common/common-functions.sh

function subscription() {
	if [[ $SELECTED_ENV == "test/perftest" && $PROJECT == "SDS" ]]; then
		SELECTED_ENV="test"
		SUBSCRIPTION='DTS-SHAREDSERVICES-'$SELECTED_ENV
	elif [[ $SELECTED_ENV == "test/perftest" && $PROJECT == "CFT" ]]; then
		SELECTED_ENV="perftest"
		SUBSCRIPTION='DCD-CFTAPPS-TEST'
	elif [[ $SELECTED_ENV == "preview/dev" && $PROJECT == "SDS" ]]; then
		SELECTED_ENV="DEV"
		SUBSCRIPTION='DTS-SHAREDSERVICES-'$SELECTED_ENV
	elif [[ $SELECTED_ENV == "preview/dev" && $PROJECT == "CFT" ]]; then
		SELECTED_ENV="DEV"
		SUBSCRIPTION='DCD-CFTAPPS-'$SELECTED_ENV
	elif [[ $SELECTED_ENV == "aat/staging" && $PROJECT == "SDS" ]]; then
		SELECTED_ENV="stg"
		SUBSCRIPTION='DTS-SHAREDSERVICES-'$SELECTED_ENV
	elif [[ $SELECTED_ENV == "aat/staging" && $PROJECT == "CFT" ]]; then
		SELECTED_ENV="stg"
		SUBSCRIPTION='DCD-CFTAPPS-'$SELECTED_ENV
	elif [[ $SELECTED_ENV == "ptlsbox" && $PROJECT == "SDS" ]]; then
		SUBSCRIPTION='DTS-SHAREDSERVICESPTL-SBOX'
	elif [[ $SELECTED_ENV == "ptlsbox" && $PROJECT == "CFT" ]]; then
		SUBSCRIPTION='DTS-CFTSBOX-INTSVC'
	elif [[ $SELECTED_ENV == "ptl" && $PROJECT == "CFT" ]]; then
		SUBSCRIPTION='DTS-CFTPTL-INTSVC'
	elif [[ $SELECTED_ENV == "ptl" && $PROJECT == "SDS" ]]; then
		SUBSCRIPTION='DTS-SHAREDSERVICESPTL'
	elif [[ $SELECTED_ENV != "test/perftest" && $SELECTED_ENV != "preview/dev" && $SELECTED_ENV != "aat/staging" && $SELECTED_ENV != "ptl" && $SELECTED_ENV != "ptlsbox" && $PROJECT == "SDS" ]]; then
		SUBSCRIPTION='DTS-SHAREDSERVICES-'$SELECTED_ENV
	elif [[ $SELECTED_ENV != "test/perftest" && $SELECTED_ENV != "preview/dev" && $SELECTED_ENV != "aat/staging" && $SELECTED_ENV != "ptl" && $SELECTED_ENV != "ptlsbox" && $PROJECT == "CFT" ]]; then
		SUBSCRIPTION='DCD-CFTAPPS-'$SELECTED_ENV
	fi
	az account set -n $SUBSCRIPTION
	ts_echo $SUBSCRIPTION selected
}

subscription
APPLICATION_GATEWAYS=$(az resource list --resource-type Microsoft.Network/applicationGateways --query "[?tags.autoShutdown == 'true']" -o json)

jq -c '.[]'<<< $APPLICATION_GATEWAYS | while read application_gateway; do
	
	# Function that returns the Resource Group, Id and Name of the Application Gateway and its current state as variables
	get_application_gateways_details
	
	if [[ "$APPLICATION_GATEWAY_STATE" != *"Running"* ]]; then
		ts_echo "Starting APP Gateway in Subscription: $(az account show --query name) and ResourceGroup: $RESOURCE_GROUP  Name: $APPLICATION_GATEWAY_NAME"
		az network application-gateway start --ids $APPLICATION_GATEWAY_ID --no-wait || echo Ignoring errors Stopping appgateway
	fi
done
