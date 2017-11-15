#!/bin/bash

# login to Terminus
echo -e "\nLogging into Terminus..."
terminus auth:login --machine-token=${TERMINUS_MACHINE_TOKEN}

# Get UUIDS of sites to update
echo -e "\nGet UUIDS of sites to update..."
SITE_UUIDS="$(terminus org:site:list $ORG_UUID --tag=$UPDATE_TAG --fields=id --format=list)"

while read -r SITE_UUID; do
	# Stash site name
	SITE_NAME="$(terminus site:info $SITE_UUID --field=name)"
	
	# Start check_for_updates job via API
	echo -e "\nStarting the check for updates job via API for $SITE_NAME..."
	curl --user ${CIRCLE_TOKEN}: \
				--data build_parameters[CIRCLE_JOB]=check_for_updates \
				--data build_parameters[SITE_NAME]=$SITE_NAME \
				--data build_parameters[SITE_UUID]=$SITE_UUID \
				--data revision=$CIRCLE_SHA1 \
				https://circleci.com/api/v1.1/project/github/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/tree/$CIRCLE_BRANCH  >/dev/null
done <<< "$SITE_UUIDS"

#echo -e "\nVisual regression tests passed! WordPress updates deployed to live..."
#SLACK_MESSAGE="Circle CI update check #${CIRCLE_BUILD_NUM} by ${CIRCLE_PROJECT_USERNAME} Visual regression tests passed! WordPress updates deployed to <https://dashboard.pantheon.io/sites/${SITE_UUID}#live/deploys|the live environment>.  Visual Regression Report: $DIFF_REPORT_URL"
#echo -e "\nSending a message to the ${SLACK_CHANNEL} Slack channel"
#curl -X POST --data "payload={\"channel\": \"${SLACK_CHANNEL}\", \"username\": \"${SLACK_USERNAME}\", \"text\": \"${SLACK_MESSAGE}\"}" $SLACK_HOOK_URL