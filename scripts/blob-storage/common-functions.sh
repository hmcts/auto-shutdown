#!/bin/bash

# Function that uses the subscription input to get set variables for later use and gather all storage accounts that have SFTP enabled or disabled

function get_sftp_servers() {
  #MS az graph query to find and return a list of all Application Gateways tagged to be included in the auto-shutdown process.
  log "----------------------------------------------"
  log "Running az graph query..."

  if [ -z "$1" ]; then
    env_selector=""
  elif [ "$1" == "untagged" ]; then
    env_selector="| where isnull(tags.environment)"
  else
    env_selector="| where tags.environment == '$1'"
  fi

  if [ "$2" == true ]; then
    env_selector="| where properties.isSftpEnabled == true"
  elif [ "$2" == false ]; then
    env_selector="| where properties.isSftpEnabled == false"
  else
    sftp_selector=""
  fi

  az graph query -q "
    Resources
      | where type == 'microsoft.storage/storageaccounts'
      | where tags['autoShutdown'] == 'true'
      | where tolower(tags.environment) in~ ('staging', 'development', 'demo', 'ithc', 'sandbox', 'ptl')
      $env_selector
      $env_selector
      | project name, id, tags, properties, subscriptionId
    " --first 1000 -o json

  log "az graph query complete"
}

# Function that accepts the app gateway json as input and sets variables for later use to stop or start the SFTP server
function get_sftp_server_details() {
  RESOURCE_GROUP=$(jq -r '.resourceGroup' <<< $sftpserver)
  STORAGE_ACCOUNT_ID=$(jq -r '.id' <<< $sftpserver)
  STORAGE_ACCOUNT_NAME=$(jq -r '.name' <<< $sftpserver)
  SFTP_SERVER_ENABLED=$(jq -r '.properties.isSftpEnabled' <<< $sftpserver)
  SFTP_SERVER_STATE=$(jq -r '.properties.provisioningState' <<< $sftpserver)
  SUBSCRIPTION=$(jq -r '.subscriptionId' <<< $sftpserver)
}

function blob_state_enabled_messages() {
	ts_echo_color GREEN "Enabling SFTP on Storage Account: $STORAGE_ACCOUNT_NAME in Resource Group: $RESOURCE_GROUP and Subscription: $SUBSCRIPTION"
	ts_echo_color GREEN "Command to run: az storage account update -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT_NAME --enable-sftp=true || echo Ignoring errors Enabling $STORAGE_ACCOUNT_NAME"
}

function blob_state_disabled_messages() {
	ts_echo_color GREEN "Disabling SFTP on Storage Account: $STORAGE_ACCOUNT_NAME in Resource Group: $RESOURCE_GROUP and Subscription: $SUBSCRIPTION"
	ts_echo_color GREEN "Command to run: az storage account update -g $RESOURCE_GROUP -n $STORAGE_ACCOUNT_NAME --enable-sftp=false || echo Ignoring errors Disabling $STORAGE_ACCOUNT_NAME"
}