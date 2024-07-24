#!/usr/bin/env bash
# set -x
shopt -s nocasematch

# Source shared function scripts
source scripts/vm/common-functions.sh
source scripts/common/common-functions.sh

# Set variables for later use, MODE has a default but can be overridden at usage time
# notificationSlackWebhook is used during the function call `auto_shutdown_notification`
MODE=${1:-start}
notificationSlackWebhook=$2

# Catch problems with MODE input, must be one of Start/Stop
if [[ "$MODE" != "start" && "$MODE" != "stop" ]]; then
	echo "Invalid MODE. Please use 'start' or 'stop'."
	exit 1
fi

# Find all subscriptions that are available to the credential used and saved to SUBSCRIPTIONS variable
SUBSCRIPTIONS=$(az account list -o json)

# For each subscription found, start the loop
jq -c '.[]' <<< $SUBSCRIPTIONS | while read subscription
do

	# Function that returns the Subscription Id and Name as variables,
	# sets the subscription as the default then returns a json formatted variable of available VMs with an autoshutdown tag
	get_subscription_vms
	echo "Scanning $SUBSCRIPTION_NAME..."

	# For each App Gateway found in the function `get_subscription_vms` start another loop
	jq -c '.[]' <<<$VMS | while read vm
	do

		# Function that returns the Resource Group, Id and Name of the VMs and its current state as variables
		get_vm_details

        # Setup message output templates for later use
		logMessage="VM: $VM_NAME in Subscription: $SUBSCRIPTION_NAME  ResourceGroup: $RESOURCE_GROUP is $VM_STATE state after $MODE action."
		slackMessage="VM: *$VM_NAME* in Subscription: *$SUBSCRIPTION_NAME*  ResourceGroup: *$RESOURCE_GROUP* is *$VM_STATE* state after *$MODE* action."

		# Check state of the VM and print output as required
        # Depending on the value of MODE a notification will also be sent
        #    - If MODE = Start then a stopped App Gateway is incorrect and we should notify
        #    - If MODE = Stop then a running App Gateway is incorrect and we should notify
        #    - If neither Running or Stopped is found then something else is going on and we should notify
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
