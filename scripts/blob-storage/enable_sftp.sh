#!/usr/bin/env bash
# set -x
SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<<$SUBSCRIPTIONS | while read subscription; do
	SUBSCRIPTION_ID=$(jq -r '.id' <<<$subscription)
	SUBSCRIPTION_NAME=$(jq -r '.name' <<<$subscription)
	az account set -s $SUBSCRIPTION_ID
	APPGS=$(az storage account list --query "[?tags.autoShutdown == 'true' && !isSftpEnabled]" -o json)

	jq -c '.[]' <<<$APPGS | while read app; do

		SKIP="false"
		name=$(jq -r '.name' <<<$app)
		rg=$(jq -r '.resourceGroup' <<<$app)

		if [[ $SKIP == "false" ]]; then
			echo -e "${GREEN}Enabling SFTP on $name (rg:$rg) sub:$SUBSCRIPTION_NAME"
			az storage account update -g $rg -n $name --enable-sftp=true || echo Ignoring errors Enabling $name
		fi
	done
done