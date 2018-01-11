#!/bin/bash

# Variables
BUILD_DIR=$(pwd)
GITHUB_API_URL="https://api.github.com/repos/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME"

# Check if we are NOT on the master branch and this is a PR
if [[ ${CIRCLE_BRANCH} != "master" && -z ${CIRCLE_PULL_REQUEST+x} ]];
then
	echo -e "\Lighthouse performance test will only run if not on the master branch when making a pull request"
	exit 0
fi

# Make artifacts directory
CIRCLE_ARTIFACTS='artifacts'
CIRCLE_ARTIFACTS_DIR='/tmp/artifacts'
mkdir -p $CIRCLE_ARTIFACTS_DIR

# Set Lighthouse results directory, branch and url
LIGHTHOUSE_BRANCH=$MULTIDEV
LIGHTHOUSE_URL=$MULTIDEV_URL
LIGHTHOUSE_RESULTS_DIR="lighthouse_results/$LIGHTHOUSE_BRANCH"
LIGHTHOUSE_REPORT_NAME="$LIGHTHOUSE_RESULTS_DIR/lighthouse.json"
LIGHTHOUSE_JSON_REPORT="$LIGHTHOUSE_RESULTS_DIR/lighthouse.report.json"
LIGHTHOUSE_HTML_REPORT="$LIGHTHOUSE_RESULTS_DIR/lighthouse.report.html"
LIGHTHOUSE_RESULTS_JSON="$LIGHTHOUSE_RESULTS_DIR/lighthouse.results.json"

# Delete the Lighthouse results directory so we don't keep old results around
if [ -d "$LIGHTHOUSE_RESULTS_DIR" ]; then
  rm -rf $LIGHTHOUSE_RESULTS_DIR
fi

# Create the Lighthouse results directory if it doesn't exist or has been deleted
mkdir -p $LIGHTHOUSE_RESULTS_DIR

# Create the Lighthouse results directory for master if needed
if [ ! -d "lighthouse_results/master" ]; then
	mkdir -p "lighthouse_results/master"
fi

# Stash Circle Artifacts URL
CIRCLE_ARTIFACTS_URL="$CIRCLE_BUILD_URL/artifacts/$CIRCLE_NODE_INDEX/$CIRCLE_ARTIFACTS"

# Ping the Pantheon environment to wake it from sleep and prime the cache
echo -e "\nPinging the ${LIGHTHOUSE_BRANCH} environment to wake it from sleep..."
curl -s -I "$LIGHTHOUSE_URL" >/dev/null

# Run the Lighthouse test
lighthouse --perf --save-artifacts --output json --output html --output-path ${LIGHTHOUSE_REPORT_NAME} --chrome-flags="--headless --disable-gpu --no-sandbox" ${LIGHTHOUSE_URL}

# Check for HTML report file
if [ ! -f $LIGHTHOUSE_HTML_REPORT ]; then
	echo -e "\nLighthouse HTML report file $LIGHTHOUSE_HTML_REPORT not found!"
	exit 1
fi

# Check for JSON report file
if [ ! -f $LIGHTHOUSE_JSON_REPORT ]; then
	echo -e "\nLighthouse JSON report file $LIGHTHOUSE_JSON_REPORT not found!"
	exit 1
fi

# Create tailored results JSON file
cat $LIGHTHOUSE_JSON_REPORT | jq '. | { "total-score": .score, "speed-index": .audits["speed-index-metric"]["score"], "first-meaningful-paint": .audits["first-meaningful-paint"]["score"], "estimated-input-latency": .audits["estimated-input-latency"]["score"], "time-to-first-byte": .audits["time-to-first-byte"]["rawValue"], "first-interactive": .audits["first-interactive"]["score"], "consistently-interactive": .audits["consistently-interactive"]["score"], "critical-request-chains": .audits["critical-request-chains"]["displayValue"], "redirects": .audits["redirects"]["score"], "bootup-time": .audits["bootup-time"]["rawValue"], "uses-long-cache-ttl": .audits["uses-long-cache-ttl"]["score"], "total-byte-weight": .audits["total-byte-weight"]["score"], "offscreen-images": .audits["offscreen-images"]["score"], "uses-webp-images": .audits["uses-webp-images"]["score"], "uses-optimized-images": .audits["uses-optimized-images"]["score"], "uses-request-compression": .audits["uses-request-compression"]["score"], "uses-responsive-images": .audits["uses-responsive-images"]["score"], "dom-size": .audits["dom-size"]["score"], "script-blocking-first-paint": .audits["script-blocking-first-paint"]["score"] }' > $LIGHTHOUSE_RESULTS_JSON

LIGHTHOUSE_SCORE=$(cat $LIGHTHOUSE_RESULTS_JSON | jq '.["total-score"] | floor | tonumber')
LIGHTHOUSE_HTML_REPORT_URL="$CIRCLE_ARTIFACTS_URL/$LIGHTHOUSE_HTML_REPORT"

# Rsync files to CIRCLE_ARTIFACTS_DIR
echo -e "\nRsyncing lighthouse_results files to $CIRCLE_ARTIFACTS_DIR..."
rsync -rlvz lighthouse_results $CIRCLE_ARTIFACTS_DIR

LIGHTHOUSE_PRODUCTION_RESULTS_DIR="lighthouse_results/master"
LIGHTHOUSE_PRODUCTION_REPORT_NAME="$LIGHTHOUSE_PRODUCTION_RESULTS_DIR/lighthouse.json"
LIGHTHOUSE_PRODUCTION_JSON_REPORT="$LIGHTHOUSE_PRODUCTION_RESULTS_DIR/lighthouse.report.json"
LIGHTHOUSE_PRODUCTION_HTML_REPORT="$LIGHTHOUSE_PRODUCTION_RESULTS_DIR/lighthouse.report.html"
LIGHTHOUSE_PRODUCTION_RESULTS_JSON="$LIGHTHOUSE_PRODUCTION_RESULTS_DIR/lighthouse.results.json"

# Ping the live environment to wake it from sleep and prime the cache
echo -e "\nPinging the live environment to wake it from sleep..."
curl -s -I "$LIVE_URL" >/dev/null

# Run Lighthouse on the live environment
echo -e "\nRunning Lighthouse on the live environment"
lighthouse --perf --save-artifacts --output json --output html --output-path "$LIGHTHOUSE_PRODUCTION_REPORT_NAME" --chrome-flags="--headless --disable-gpu --no-sandbox" ${LIVE_URL}

# Create tailored results JSON file
cat $LIGHTHOUSE_PRODUCTION_JSON_REPORT | jq '. | { "total-score": .score, "speed-index": .audits["speed-index-metric"]["score"], "first-meaningful-paint": .audits["first-meaningful-paint"]["score"], "estimated-input-latency": .audits["estimated-input-latency"]["score"], "time-to-first-byte": .audits["time-to-first-byte"]["rawValue"], "first-interactive": .audits["first-interactive"]["score"], "consistently-interactive": .audits["consistently-interactive"]["score"], "critical-request-chains": .audits["critical-request-chains"]["displayValue"], "redirects": .audits["redirects"]["score"], "bootup-time": .audits["bootup-time"]["rawValue"], "uses-long-cache-ttl": .audits["uses-long-cache-ttl"]["score"], "total-byte-weight": .audits["total-byte-weight"]["score"], "offscreen-images": .audits["offscreen-images"]["score"], "uses-webp-images": .audits["uses-webp-images"]["score"], "uses-optimized-images": .audits["uses-optimized-images"]["score"], "uses-request-compression": .audits["uses-request-compression"]["score"], "uses-responsive-images": .audits["uses-responsive-images"]["score"], "dom-size": .audits["dom-size"]["score"], "script-blocking-first-paint": .audits["script-blocking-first-paint"]["score"] }' > $LIGHTHOUSE_PRODUCTION_RESULTS_JSON

LIGHTHOUSE_PRODUCTION_SCORE=$(cat $LIGHTHOUSE_PRODUCTION_RESULTS_JSON | jq '.["total-score"] | floor | tonumber')

# Rsync files to CIRCLE_ARTIFACTS_DIR again now that we have master results
echo -e "\nRsyncing lighthouse_results files to $CIRCLE_ARTIFACTS_DIR..."
rsync -rlvz lighthouse_results $CIRCLE_ARTIFACTS_DIR

echo -e "\nMaster score of $LIGHTHOUSE_PRODUCTION_SCORE recorded"

LIGHTHOUSE_PRODUCTION_HTML_REPORT_URL="$CIRCLE_ARTIFACTS_URL/$LIGHTHOUSE_PRODUCTION_HTML_REPORT"
REPORT_LINK="<$LIGHTHOUSE_HTML_REPORT_URL|Lighthouse performance report for \`$CIRCLE_BRANCH\`> and compare it to the <$LIGHTHOUSE_PRODUCTION_HTML_REPORT_URL|Lighthouse performance report for the \`master\` branch>"

# Level of tolerance for score decline	
LIGHTHOUSE_ACCEPTABLE_THRESHOLD=5
LIGHTHOUSE_ACCEPTABLE_SCORE=$((LIGHTHOUSE_PRODUCTION_SCORE-LIGHTHOUSE_ACCEPTABLE_THRESHOLD))
if [ $LIGHTHOUSE_SCORE -lt $LIGHTHOUSE_ACCEPTABLE_SCORE ]; then
	# Lighthouse test failed! The score is less than the acceptable score
	echo -e "\nLighthouse test failed! The score of $LIGHTHOUSE_SCORE is less than the acceptable score of $LIGHTHOUSE_ACCEPTABLE_SCORE ($LIGHTHOUSE_ACCEPTABLE_THRESHOLD less the score of $LIGHTHOUSE_PRODUCTION_SCORE on the master branch)"
	SLACK_MESSAGE="Lighthouse test failed! The score of \`$LIGHTHOUSE_SCORE\` is less than the acceptable score of \`$LIGHTHOUSE_ACCEPTABLE_SCORE\` (\`$LIGHTHOUSE_ACCEPTABLE_THRESHOLD\` less than the score of \`$LIGHTHOUSE_PRODUCTION_SCORE\` on the master branch)"

	SLACK_MESSAGE="$SLACK_MESSAGE"
    SLACK_ATTACHEMENTS="\"attachments\": [{\"fallback\": \"View the reports in CircleCI artifacts\",\"actions\": [{\"type\": \"button\",\"text\": \"${MULTIDEV} (${LIGHTHOUSE_SCORE})\",\"url\":\"${LIGHTHOUSE_HTML_REPORT_URL}\"},{\"type\": \"button\",\"text\": \"Live (${LIGHTHOUSE_PRODUCTION_SCORE})\",\"url\":\"${LIGHTHOUSE_PRODUCTION_HTML_REPORT_URL}\"}]}]"

	# Post the report back to Slack
	echo -e "\nSending a message to the ${SLACK_CHANNEL} Slack channel"
	curl -X POST --data "payload={\"channel\": \"${SLACK_CHANNEL}\",${SLACK_ATTACHEMENTS}, \"username\": \"${SLACK_USERNAME}\", \"text\": \"${SLACK_MESSAGE}\"}" $SLACK_HOOK_URL

	exit 1
else
	# Lighthouse test passed! The score isn't less than the acceptable score
	echo -e "\nLighthouse test passed! The score of $LIGHTHOUSE_SCORE isn't less than the acceptable score of $LIGHTHOUSE_ACCEPTABLE_SCORE ($LIGHTHOUSE_ACCEPTABLE_THRESHOLD less than the score of $LIGHTHOUSE_PRODUCTION_SCORE on the master branch)"
	SLACK_MESSAGE="Lighthouse test passed! The score of \`$LIGHTHOUSE_SCORE\` isn't less than the acceptable score of \`$LIGHTHOUSE_ACCEPTABLE_SCORE\` (\`$LIGHTHOUSE_ACCEPTABLE_THRESHOLD\` less than the score of \`$LIGHTHOUSE_PRODUCTION_SCORE\` on the master branch)"

	SLACK_MESSAGE="$SLACK_MESSAGE"
    SLACK_ATTACHEMENTS="\"attachments\": [{\"fallback\": \"View the reports in CircleCI artifacts\",\"actions\": [{\"type\": \"button\",\"text\": \"${MULTIDEV} (${LIGHTHOUSE_SCORE})\",\"url\":\"${LIGHTHOUSE_HTML_REPORT_URL}\"},{\"type\": \"button\",\"text\": \"Live (${LIGHTHOUSE_PRODUCTION_SCORE})\",\"url\":\"${LIGHTHOUSE_PRODUCTION_HTML_REPORT_URL}\"}]}]"

	# Post the report back to Slack
	echo -e "\nSending a message to the ${SLACK_CHANNEL} Slack channel"
	curl -X POST --data "payload={\"channel\": \"${SLACK_CHANNEL}\",${SLACK_ATTACHEMENTS}, \"username\": \"${SLACK_USERNAME}\", \"text\": \"${SLACK_MESSAGE}\"}" $SLACK_HOOK_URL

    exit 0

	# Deploy updates
	echo -e "\nStarting the deploy job via API for $SITE_NAME..."
	curl --user ${CIRCLE_TOKEN}: \
                --data build_parameters[CIRCLE_JOB]=deploy_updates \
                --data build_parameters[DIFF_REPORT_URL]=$DIFF_REPORT_URL \
				--data build_parameters[SITE_NAME]=$SITE_NAME \
				--data build_parameters[SITE_UUID]=$SITE_UUID \
				--data build_parameters[CREATE_BACKUPS]=$CREATE_BACKUPS \
				--data build_parameters[RECREATE_MULTIDEV]=$RECREATE_MULTIDEV \
				--data build_parameters[LIVE_URL]=$LIVE_URL \
                --data revision=$CIRCLE_SHA1 \
                https://circleci.com/api/v1.1/project/github/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/tree/$CIRCLE_BRANCH  >/dev/null
fi
