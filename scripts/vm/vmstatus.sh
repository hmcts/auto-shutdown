#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/vm/common-functions.sh
source scripts/common/common-functions.sh

MODE=${1:-start}
notificationSlackWebhook=$2

if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
	echo "Invalid MODE. Please use 'start' or 'stop'."
	exit 1
fi

SUBSCRIPTIONS=$(az account list -o json)
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription; do

	get_subscription_vms
	echo "Scanning $SUBSCRIPTION_NAME..."

	jq -c '.[]' <<<$VMS | while read vm; do

		get_vm_details
		
		logMessage="VM: $VM_NAME in Subscription: $SUBSCRIPTION_NAME  ResourceGroup: $RESOURCE_GROUP is $VM_STATE state after $MODE action."
		slackMessage="VM: *$VM_NAME* in Subscription: *$SUBSCRIPTION_NAME*  ResourceGroup: *$RESOURCE_GROUP* is *$VM_STATE* state after *$MODE* action."

		if [[ "$VM_STATE" =~ .*"running".* ]]; then
			ts_echo_color $( [[ $MODE == "start" ]] && echo GREEN || echo RED ) "$logMessage"
			if [[ $MODE == "stop" ]]; then
				auto_shutdown_notification ":red_circle: $slackMessage"
			fi   
		elif [[  "$VM_STATE" =~ .*"deallocated".* ]]; then
			ts_echo_color $( [[ $MODE == "start" ]] && echo RED || echo GREEN ) "$logMessage"
			if [[ $MODE == "start" ]]; then
				auto_shutdown_notification ":red_circle: $slackMessage"
			fi   
		else
			ts_echo_color ${AMBER} "$logMessage" 
			auto_shutdown_notification ":yellow_circle: $slackMessage"
		fi
		
	done
done
