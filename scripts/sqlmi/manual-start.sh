#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/sqlmi/common-functions.sh
source scripts/common/common-functions.sh

MODE=${1:-start}
notificationSlackWebhook=$2

if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
    echo "Invalid MODE. Please use 'start' or 'stop'."
    exit 1
fi

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

SUBSCRIPTIONS=$(az account list -o json)

jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do

	get_sql_mi_servers

	if [[ $PROJECT == "SDS" ]] && [[ $SUBSCRIPTION_NAME =~ "DCD-" ]]; then
		continue
	fi
	if [[ $PROJECT == "CFT" ]] && [[ $SUBSCRIPTION_NAME =~ "SHAREDSERVICES" ]]; then
		continue
	fi

	jq -c '.[]' <<< $MI_SQL_SERVERS | while read server; do

		get_sql_mi_server_details
		
		if [[ $SERVER_NAME =~ $SELECTED_ENV ]]; then
			if [[ "$SERVER_STATE" != *"Ready"* ]]; then
				ts_echo "Starting SQL managed-instance: $SERVER_NAME in Subscription: $SUBSCRIPTION_NAME  ResourceGroup: $RESOURCE_GROUP  Name: $SERVER_NAME"
				az sql mi start --ids $SERVER_ID --no-wait || echo Ignoring error starting $SERVER_NAME
			fi
		fi
	done
done
