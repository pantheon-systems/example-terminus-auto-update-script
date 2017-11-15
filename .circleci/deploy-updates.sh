#!/bin/bash
echo -e "\Deploying updates for $SITE_NAME with UUID $SITE_UUID..."

# login to Terminus
echo -e "\nLogging into Terminus..."
terminus auth:login --machine-token=${TERMINUS_MACHINE_TOKEN}

# enable git mode on dev
echo -e "\nEnabling git mode on the dev environment..."
terminus connection:set $SITE_UUID.dev git

# merge the multidev back to dev
echo -e "\nMerging the ${MULTIDEV} multidev back into the dev environment (master)..."
terminus multidev:merge-to-dev $SITE_UUID.$MULTIDEV

# update WordPress database on dev
echo -e "\nUpdating the WordPress database on the dev environment..."
terminus -n wp $SITE_UUID.dev -- core update-db

# deploy to test
echo -e "\nDeploying the updates from dev to test..."
terminus env:deploy $SITE_UUID.test --sync-content --cc --note="Auto deploy of WordPress updates (core, plugin, themes)"

# update WordPress database on test
echo -e "\nUpdating the WordPress database on the test environment..."
terminus -n wp $SITE_UUID.test -- core update-db

# backup the live site
echo -e "\nBacking up the live environment..."
terminus backup:create $SITE_UUID.live --element=all --keep-for=30

# deploy to live
echo -e "\nDeploying the updates from test to live..."
terminus env:deploy $SITE_UUID.live --cc --note="Auto deploy of WordPress updates (core, plugin, themes)"

# update WordPress database on live
echo -e "\nUpdating the WordPress database on the live environment..."
terminus -n wp $SITE_UUID.live -- core update-db

echo -e "\nVisual regression tests passed! WordPress updates deployed to live..."
SLACK_MESSAGE="Circle CI update check #${CIRCLE_BUILD_NUM} by ${CIRCLE_PROJECT_USERNAME}on ${SITE_NAME}.  Visual regression tests passed! WordPress updates deployed to <https://dashboard.pantheon.io/sites/${SITE_UUID}#live/deploys|the live environment>.  Visual Regression Report: $DIFF_REPORT_URL"
echo -e "\nSending a message to the ${SLACK_CHANNEL} Slack channel"
curl -X POST --data "payload={\"channel\": \"${SLACK_CHANNEL}\", \"username\": \"${SLACK_USERNAME}\", \"text\": \"${SLACK_MESSAGE}\"}" $SLACK_HOOK_URL