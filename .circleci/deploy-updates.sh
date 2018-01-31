#!/bin/bash
echo -e "\Deploying updates for $SITE_NAME with UUID $SITE_UUID..."

# login to Terminus
echo -e "\nLogging into Terminus..."
terminus auth:login --machine-token=${TERMINUS_MACHINE_TOKEN}

# enable git mode on dev
echo -e "\nEnabling git mode on the dev environment for $SITE_NAME..."
terminus connection:set $SITE_UUID.dev git

# merge the multidev back to dev
echo -e "\nMerging the ${MULTIDEV} multidev back into the dev environment (master) for $SITE_NAME..."
terminus multidev:merge-to-dev $SITE_UUID.$MULTIDEV

# update WordPress database on dev
echo -e "\nUpdating the WordPress database on the dev environment for $SITE_NAME..."
terminus -n wp $SITE_UUID.dev -- core update-db

# deploy to test
echo -e "\nDeploying the updates from dev to test for $SITE_NAME..."
terminus env:deploy $SITE_UUID.test --sync-content --cc --note="Auto deploy of WordPress updates (core, plugin, themes)"

# update WordPress database on test
echo -e "\nUpdating the WordPress database on the test environment..."
terminus -n wp $SITE_UUID.test -- core update-db

# backup the live site
if [[ "$CREATE_BACKUPS" == "0" ]]
then
	echo -e "\nSkipping backup of the live environment for $SITE_NAME..."
else
	echo -e "\nBacking up the live environment for $SITE_NAME..."
	terminus backup:create $SITE_UUID.live --element=all --keep-for=30
fi

# deploy to live
echo -e "\nDeploying the updates from test to live for $SITE_NAME..."
terminus env:deploy $SITE_UUID.live --cc --note="Auto deploy of WordPress updates (core, plugin, themes)"

# update WordPress database on live
echo -e "\nUpdating the WordPress database on the live environment for $SITE_NAME..."
terminus -n wp $SITE_UUID.live -- core update-db

echo -e "\nTests passed! WordPress updates deployed to live for $SITE_NAME..."
SLACK_MESSAGE="Circle CI update check #${CIRCLE_BUILD_NUM} by ${CIRCLE_PROJECT_USERNAME} on ${SITE_NAME}.  Automated tests passed! WordPress updates deployed to production. View the reports below:"

SLACK_MESSAGE="Automated tests passed for $SITE_NAME! Updates deployed to production. View the test reports below:"

SLACK_ATTACHEMENTS="\"attachments\": [{\"fallback\": \"View the test results in CircleCI artifacts\",\"color\": \"${GREEN_HEX}\",\"actions\": [{\"type\": \"button\",\"text\": \"Lighthouse Report for ${MULTIDEV} (${LIGHTHOUSE_SCORE})\",\"url\":\"${LIGHTHOUSE_HTML_REPORT_URL}\"},{\"type\": \"button\",\"text\": \"Lighthouse Report for Live (${LIGHTHOUSE_PRODUCTION_SCORE})\",\"url\":\"${LIGHTHOUSE_PRODUCTION_HTML_REPORT_URL}\"},{\"type\": \"button\",\"text\": \"BackstopJS Visual Regression Report\",\"url\":\"${DIFF_REPORT_URL}\"},{\"type\": \"button\",\"text\": \"View Site\",\"url\":\"${LIVE_URL}\"},{\"type\": \"button\",\"text\": \"Live environment dashboard\",\"url\":\"https://dashboard.pantheon.io/sites/${SITE_UUID}#live\"}]}]"

# Post the report back to Slack
echo -e "\nSending a message to the ${SLACK_CHANNEL} Slack channel"
curl -X POST --data "payload={\"channel\": \"${SLACK_CHANNEL}\",${SLACK_ATTACHEMENTS}, \"username\": \"${SLACK_USERNAME}\", \"text\": \"${SLACK_MESSAGE}\"}" $SLACK_HOOK_URL