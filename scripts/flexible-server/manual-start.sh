#!/usr/bin/env bash

function ts_echo() {
	date +"%H:%M:%S $(printf "%s " "$@")"
}
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
jq -c '.[]' <<<$SUBSCRIPTIONS | while read subscription; do

	get_subscription_flexible_sql_servers

	if [[ $PROJECT == "SDS" ]] && [[ $SUBSCRIPTION_NAME =~ "DCD-" ]]; then
		continue
	fi
	if [[ $PROJECT == "CFT" ]] && [[ $SUBSCRIPTION_NAME =~ "SHAREDSERVICES" ]]; then
		continue
	fi

	az account set -s $SUBSCRIPTION_ID

	jq -c '.[]' <<<$FLEXIBLE_SERVERS | while read flexibleserver; do

		get_flexible_sql_server_details

		if [[ $SERVER_NAME =~ $SELECTED_ENV ]]; then
			if [[ "$SERVER_STATE" != *"Ready"* ]]; then
				ts_echo "Starting flexible-server: $SERVER_NAME in Subscription: $SUBSCRIPTION_NAME  ResourceGroup: $RESOURCE_GROUP"
				az postgres flexible-server start --ids $SERVER_ID --no-wait || echo Ignoring error starting $NAME
			fi
		fi
	done
done
