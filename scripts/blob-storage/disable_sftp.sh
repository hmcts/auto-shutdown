#!/usr/bin/env bash
# set -x
shopt -s nocasematch
AMBER='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<<$SUBSCRIPTIONS | while read subscription; do
	SUBSCRIPTION_ID=$(jq -r '.id' <<<$subscription)
	SUBSCRIPTION_NAME=$(jq -r '.name' <<<$subscription)
	az account set -s $SUBSCRIPTION_ID
	APPGS=$(az storage account list --query "[?tags.autoShutdown == 'true' && isSftpEnabled]" -o json)

	jq -c '.[]' <<<$APPGS | while read app; do

		SKIP="false"
		name=$(jq -r '.name' <<<$app)
		rg=$(jq -r '.resourceGroup' <<<$app)

		if [[ $SKIP == "false" ]]; then
			echo -e "${GREEN}Disabling SFTP on $name (rg:$rg) sub:$SUBSCRIPTION_NAME"
			az storage account update -g $rg -n $name --enable-sftp=false || echo Ignoring errors Disabling $name
		else
			echo -e "${AMBER}storage account $name (rg:$rg) sub:$SUBSCRIPTION_NAME has been skipped from todays shutdown schedule"
		fi
	done
done