#!/bin/bash
source scripts/common/common-functions.sh

# Define Bash variables
request_url_link="*<$REQUEST_URL|$CHANGE_JIRA_ID>*"
request_title_link="*<$REQUEST_URL|$ISSUE_TITLE>*"
current_date=$(get_current_date)
environment_field=$(echo "$ENVIRONMENT" | sed 's/\[//; s/\]//; s/"//g')
slack_username=$(get_slack_displayname_from_github_username $REQUESTER $SLACK_TOKEN)

# Use jq with variables
jq --arg issue_url "$request_url_link" \
   --arg issue_title "$request_title_link" \
   --arg business_area "$BUSINESS_AREA_ENTRY" \
   --arg environment "$environment_field" \
   --arg start_date "$START_DATE" \
   --arg end_date "$END_DATE" \
   --arg requester "$slack_username" \
   --arg current_date "$current_date" \
   --arg cost_value "£$COST_DETAILS_FORMATTED" \
   --arg status "$APPROVAL_COMMENT" \
   --arg raw_issue_url "$REQUEST_URL" \
   '.blocks[0].text.text |= $issue_title | 
    .blocks[1].fields[0].text |= "*Business Area:*\n\($business_area)" |
    .blocks[1].fields[1].text |= "*Environment:*\n\($environment)" |
    .blocks[1].fields[2].text |= "*Start Date:*\n\($start_date)" |
    .blocks[1].fields[3].text |= "*End Date:*\n\($end_date)" |
    .blocks[1].fields[4].text |= "*Requester:*\n\($requester)" |
    .blocks[1].fields[5].text |= "*Submitted:*\n\($current_date)" |
    .blocks[1].fields[6].text |= "*Value:*\n\($cost_value)" |
    .blocks[1].fields[7].text |= "*Status:*\n\($status)" |
    .blocks[2].elements[0].text.text |= "Review Request" |
    .blocks[2].elements[0].url |= $raw_issue_url' scripts/aks/message-template.json > slack-payload.json

MESSAGE=$(< slack-payload.json)

curl -X POST -H 'Content-type: application/json' --data "${MESSAGE}" ${SLACK_WEBHOOK}