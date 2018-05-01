#!/bin/bash

# Bail on errors
set +ex

echo -e "\nRunning visual regression tests for $SITE_NAME with UUID $SITE_UUID..."

# Variables
BUILD_DIR=$(pwd)
GITHUB_API_URL="https://api.github.com/repos/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME"

# Make artifacts directories
CIRCLE_ARTIFACTS='artifacts'
CIRCLE_ARTIFACTS_DIR='/tmp/artifacts'
mkdir -p $CIRCLE_ARTIFACTS_DIR

# Stash Circle Artifacts URL
CIRCLE_ARTIFACTS_URL="$CIRCLE_BUILD_URL/artifacts/$CIRCLE_NODE_INDEX/$CIRCLE_ARTIFACTS"

# Ping the multidev environment to wake it from sleep
echo -e "\nPinging the ${MULTIDEV} multidev environment to wake it from sleep for $SITE_NAME..."
curl -I "$MULTIDEV_URL" >/dev/null

# Ping the live environment to wake it from sleep
echo -e "\nPinging the live environment to wake it from sleep for $SITE_NAME..."
curl -I "$LIVE_URL" >/dev/null

# Check for custom backstop.json for the specific site
if [ -f "$SITE_NAME.backstop.json" ] || [ -f "$SITE_NAME.backstop-config.js" ]; then

	echo -e "\nCustom Backstop template $SITE_NAME.backstop.json or $SITE_NAME.backstop-config.js found for $SITE_NAME, skipping URL crawl..."
	
	if [ -f "$SITE_NAME.backstop.json" ]; then
		cp "$SITE_NAME.backstop.json" backstop.json
	fi

else
	# Otherwise create Backstop config file dynamically by crawling site URLs
	echo -e "\nCreating backstop.js config file with backstop-crawl for $SITE_NAME..."
	backstop-crawl $LIVE_URL --referenceUrl="$MULTIDEV_URL" --ignore-robots --limit-similar=1
fi

# Backstop visual regression
echo -e "\nRunning backstop reference for $SITE_NAME against the $MULTIDEV_URL..."

if [ -f "$SITE_NAME.backstop-config.js" ]; then
	backstop reference --config="$SITE_NAME.backstop-config.js"
else
	backstop reference
fi

echo -e "\nRunning backstop test for $SITE_NAME against the $LIVE_URL..."

if [ -f "$SITE_NAME.backstop-config.js" ]; then
	VISUAL_REGRESSION_RESULTS="$(backstop test --config=$SITE_NAME.backstop-config.js || echo 'true' )"
else
	VISUAL_REGRESSION_RESULTS=$(backstop test || echo 'true')
fi

echo "${VISUAL_REGRESSION_RESULTS}"

# Rsync files to CIRCLE_ARTIFACTS_DIR
echo -e "\nRsyncing backstop_data files to $CIRCLE_ARTIFACTS_DIR for $SITE_NAME..."
rsync -rlvz backstop_data $CIRCLE_ARTIFACTS_DIR

DIFF_REPORT="$CIRCLE_ARTIFACTS_DIR/backstop_data/html_report/index.html"

if [ ! -f $DIFF_REPORT ]; then
	echo -e "\nDiff report file $DIFF_REPORT not found for $SITE_NAME!"
	exit 1
fi

VISUAL_REGRESSION_HTML_REPORT_URL="$CIRCLE_ARTIFACTS_URL/backstop_data/html_report/index.html"

if [[ ${VISUAL_REGRESSION_RESULTS} == *"Mismatch errors found"* ]]
then
	# visual regression failed
	echo -e "\nVisual regression tests failed! Please manually check the ${MULTIDEV} multidev for $SITE_NAME..."
	SLACK_MESSAGE="Circle CI update check #${CIRCLE_BUILD_NUM} by ${CIRCLE_PROJECT_USERNAME} on ${SITE_NAME}. Visual regression tests failed on the ${MULTIDEV} environment! Please test manually."

    SLACK_ATTACHEMENTS="\"attachments\": [{\"fallback\": \"View the visual regression report in CircleCI artifacts\",\"color\": \"${RED_HEX}\",\"actions\": [{\"type\": \"button\",\"text\": \"BackstopJS Report\",\"url\":\"${VISUAL_REGRESSION_HTML_REPORT_URL}\"},{\"type\": \"button\",\"text\": \"${MULTIDEV} Site\",\"url\":\"${MULTIDEV_URL}\"},{\"type\": \"button\",\"text\": \"${MULTIDEV} Dashboard\",\"url\":\"https://dashboard.pantheon.io/sites/${SITE_UUID}#${MULTIDEV}/code\"}]}]"

	echo -e "\nSending a message to the ${SLACK_CHANNEL} Slack channel"
	curl -X POST --data "payload={\"channel\": \"${SLACK_CHANNEL}\",${SLACK_ATTACHEMENTS}, \"username\": \"${SLACK_USERNAME}\", \"text\": \"${SLACK_MESSAGE}\"}" $SLACK_HOOK_URL
else
	# visual regression passed
	echo -e "\nVisual regression tests passed between the ${MULTIDEV} multidev and live for $SITE_NAME."

	# Lighthouse performance testing
	echo -e "\nStarting the Lighthouse performance testing job via API for $SITE_NAME..."
	curl --user ${CIRCLE_TOKEN}: \
                --data build_parameters[CIRCLE_JOB]=lighthouse_performance_test \
                --data build_parameters[VISUAL_REGRESSION_HTML_REPORT_URL]=$VISUAL_REGRESSION_HTML_REPORT_URL \
				--data build_parameters[SITE_NAME]=$SITE_NAME \
				--data build_parameters[SITE_UUID]=$SITE_UUID \
				--data build_parameters[CREATE_BACKUPS]=$CREATE_BACKUPS \
				--data build_parameters[RECREATE_MULTIDEV]=$RECREATE_MULTIDEV \
				--data build_parameters[LIVE_URL]=$LIVE_URL \
                --data revision=$CIRCLE_SHA1 \
                https://circleci.com/api/v1.1/project/github/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/tree/$CIRCLE_BRANCH  >/dev/null
fi