#!/bin/bash

# Variables
BUILD_DIR=$(pwd)
GITHUB_API_URL="https://api.github.com/repos/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME"

# Stash site URLs
MULTIDEV_SITE_URL="https://$MULTIDEV-$TERMINUS_SITE.pantheonsite.io/"
LIVE_SITE_URL="https://live-$TERMINUS_SITE.pantheonsite.io/"

# Make artifacts directories
CIRCLE_ARTIFACTS='artifacts'
mkdir -p $CIRCLE_ARTIFACTS
CIRCLE_ARTIFACTS_DIR='/tmp/artifacts'
mkdir -p $CIRCLE_ARTIFACTS_DIR

# Stash Circle Artifacts URL
CIRCLE_ARTIFACTS_URL="$CIRCLE_BUILD_URL/artifacts/$CIRCLE_NODE_INDEX/$CIRCLE_ARTIFACTS"

# Ping the multidev environment to wake it from sleep
echo -e "\nPinging the ${MULTIDEV} multidev environment to wake it from sleep..."
curl -I "$MULTIDEV_URL" >/dev/null

# Ping the live environment to wake it from sleep
echo -e "\nPinging the live environment to wake it from sleep..."
curl -I "$LIVE_URL" >/dev/null

# Check for custom backstop.json
if [ ! -f backstop.json ]; then
	# Create Backstop config file with dynamic URLs
	echo -e "\nCreating backstop.js config file with backstop-crawl..."
	backstop-crawl $LIVE_URL --referenceUrl="$MULTIDEV_URL"
fi

# Backstop visual regression
echo -e "\nRunning backstop reference..."

backstop reference

echo -e "\nRunning backstop test..."
VISUAL_REGRESSION_RESULTS=$(backstop test || echo 'true')

echo "${VISUAL_REGRESSION_RESULTS}"

# Rsync files to CIRCLE_ARTIFACTS
echo -e "\nRsyncing backstop_data files to $CIRCLE_ARTIFACTS..."
rsync -rlvz backstop_data $CIRCLE_ARTIFACTS

DIFF_REPORT="$CIRCLE_ARTIFACTS/backstop_data/html_report/index.html"

if [ ! -f $DIFF_REPORT ]; then
	echo -e "\nDiff report file $DIFF_REPORT not found!"
	exit 1
fi

DIFF_REPORT_URL="$CIRCLE_ARTIFACTS_URL/backstop_data/html_report/index.html"

if [[ ${VISUAL_REGRESSION_RESULTS} == *"Mismatch errors found"* ]]
then
	# visual regression failed
	echo -e "\nVisual regression tests failed! Please manually check the ${MULTIDEV} multidev..."
	SLACK_MESSAGE="Circle CI update check #${CIRCLE_BUILD_NUM} by ${CIRCLE_PROJECT_USERNAME} on ${SITE_NAME}. Visual regression tests failed on <https://dashboard.pantheon.io/sites/${SITE_UUID}#${MULTIDEV}/code|the ${MULTIDEV} environment>! Please test manually. Visual Regression Report: $DIFF_REPORT_URL"
	echo -e "\nSending a message to the ${SLACK_CHANNEL} Slack channel"
	curl -X POST --data "payload={\"channel\": \"${SLACK_CHANNEL}\", \"username\": \"${SLACK_USERNAME}\", \"text\": \"${SLACK_MESSAGE}\"}" $SLACK_HOOK_URL
else
	# visual regression passed
	echo -e "\nVisual regression tests passed between the ${MULTIDEV} multidev and live."

	# Deploy updates
	echo -e "\nStarting the deploy job via API..."
	curl --user ${CIRCLE_TOKEN}: \
                --data build_parameters[CIRCLE_JOB]=deploy_updates \
                --data build_parameters[DIFF_REPORT_URL]=$DIFF_REPORT_URL \
				--data build_parameters[SITE_NAME]=$SITE_NAME \
				--data build_parameters[SITE_UUID]=$SITE_UUID \
                --data revision=$CIRCLE_SHA1 \
                https://circleci.com/api/v1.1/project/github/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/tree/$CIRCLE_BRANCH  >/dev/null
fi