#!/bin/bash

echo "Running Test Environment"

export SLACK_WEBHOOK="https://webhook.site/2e1bcfb8-03cb-4d13-8995-5bce322b2fd3"
export REQUEST_URL="https://fake-url.com"
export CHANGE_JIRA_ID="FAKE-123"
export ISSUE_TITLE="Title"
export ENVIRONMENT="Test"
export APPROVAL_COMMENT="Approved By"
export JUSTIFICATION="Justified"
export BUSINESS_AREA_ENTRY="The Business Factory"
export TEAM_NAME="Team Name"
export START_DATE="2025-11-18"
export END_DATE="2025-11-30"

bash ./scripts/aks/send-slack-message.sh