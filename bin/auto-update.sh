#!/bin/bash

MULTIDEV="update-wp"

UPDATES_APPLIED=false

# Stash Circle Artifacts URL
CIRCLE_ARTIFACTS_URL="$CIRCLE_BUILD_URL/artifacts/$CIRCLE_NODE_INDEX/$CIRCLE_ARTIFACTS"

# login to Terminus
echo -e "\nLogging into Terminus..."
terminus auth:login --machine-token=${TERMINUS_MACHINE_TOKEN}

# delete the multidev environment
echo -e "\nDeleting the ${MULTIDEV} multidev environment..."
terminus multidev:delete $SITE_UUID.$MULTIDEV --delete-branch --yes

# recreate the multidev environment
echo -e "\nRe-creating the ${MULTIDEV} multidev environment..."
terminus multidev:create $SITE_UUID.live $MULTIDEV

# check for upstream updates
echo -e "\nChecking for upstream updates on the ${MULTIDEV} multidev..."
# the output goes to stderr, not stdout
UPSTREAM_UPDATES="$(terminus upstream:updates:list $SITE_UUID.$MULTIDEV  --format=list  2>&1)"

if [[ ${UPSTREAM_UPDATES} == *"no available updates"* ]]
then
    # no upstream updates available
    echo -e "\nNo upstream updates found on the ${MULTIDEV} multidev..."
else
    # making sure the multidev is in git mode
    echo -e "\nSetting the ${MULTIDEV} multidev to git mode"
    terminus connection:set $SITE_UUID.$MULTIDEV git

    # apply WordPress upstream updates
    echo -e "\nApplying upstream updates on the ${MULTIDEV} multidev..."
    terminus upstream:updates:apply $SITE_UUID.$MULTIDEV --yes --updatedb --accept-upstream
    UPDATES_APPLIED=true

    terminus -n wp $SITE_UUID.$MULTIDEV -- core update-db
fi

# making sure the multidev is in SFTP mode
echo -e "\nSetting the ${MULTIDEV} multidev to SFTP mode"
terminus connection:set $SITE_UUID.$MULTIDEV sftp

# Wake pantheon SSH
terminus -n wp $SITE_UUID.$MULTIDEV -- cli version

# check for WordPress plugin updates
echo -e "\nChecking for WordPress plugin updates on the ${MULTIDEV} multidev..."
PLUGIN_UPDATES=$(terminus -n wp $SITE_UUID.$MULTIDEV -- plugin list --update=available --format=count)
echo $PLUGIN_UPDATES

if [[ "$PLUGIN_UPDATES" == "0" ]]
then
    # no WordPress plugin updates found
    echo -e "\nNo WordPress plugin updates found on the ${MULTIDEV} multidev..."
else
    # update WordPress plugins
    echo -e "\nUpdating WordPress plugins on the ${MULTIDEV} multidev..."
    terminus -n wp $SITE_UUID.$MULTIDEV -- plugin update --all

    # wake the site environment before committing code
    echo -e "\nWaking the ${MULTIDEV} multidev..."
    terminus env:wake $SITE_UUID.$MULTIDEV

    # committing updated WordPress plugins
    echo -e "\nCommitting WordPress plugin updates on the ${MULTIDEV} multidev..."
    terminus env:commit $SITE_UUID.$MULTIDEV --force --message="update WordPress plugins"
    UPDATES_APPLIED=true
fi

# check for WordPress theme updates
echo -e "\nChecking for WordPress theme updates on the ${MULTIDEV} multidev..."
THEME_UPDATES=$(terminus -n wp $SITE_UUID.$MULTIDEV -- theme list --update=available --format=count)
echo $THEME_UPDATES

if [[ "$THEME_UPDATES" == "0" ]]
then
    # no WordPress theme updates found
    echo -e "\nNo WordPress theme updates found on the ${MULTIDEV} multidev..."
else
    # update WordPress themes
    echo -e "\nUpdating WordPress themes on the ${MULTIDEV} multidev..."
    terminus -n wp $SITE_UUID.$MULTIDEV -- theme update --all

    # wake the site environment before committing code
    echo -e "\nWaking the ${MULTIDEV} multidev..."
    terminus env:wake $SITE_UUID.$MULTIDEV

    # committing updated WordPress themes
    echo -e "\nCommitting WordPress theme updates on the ${MULTIDEV} multidev..."
    terminus env:commit $SITE_UUID.$MULTIDEV --force --message="update WordPress themes"
    UPDATES_APPLIED=true
fi

if [[ "${UPDATES_APPLIED}" = false ]]
then
    # no updates applied
    echo -e "\nNo updates to apply..."
    SLACK_MESSAGE="Circle CI update check #${CIRCLE_BUILD_NUM} by ${CIRCLE_PROJECT_USERNAME}. No updates to apply, nothing deployed."
    echo -e "\nSending a message to the ${SLACK_CHANNEL} Slack channel"
    curl -X POST --data "payload={\"channel\": \"${SLACK_CHANNEL}\", \"username\": \"${SLACK_USERNAME}\", \"text\": \"${SLACK_MESSAGE}\"}" $SLACK_HOOK_URL
else
    # updates applied, carry on

    # ping the multidev environment to wake it from sleep
    echo -e "\nPinging the ${MULTIDEV} multidev environment to wake it from sleep..."
    curl -I "https://$MULTIDEV-wp-microsite.pantheonsite.io/"

    # backstop visual regression
    echo -e "\nRunning BackstopJS tests..."

    # Backstop visual regression
    echo -e "\nRunning backstop reference..."

    backstop reference

    echo -e "\nRunning backstop test..."
    VISUAL_REGRESSION_RESULTS=$(backstop test || echo 'true')

    echo "${VISUAL_REGRESSION_RESULTS}"

    # Rsync files to CIRCLE_ARTIFACTS
    echo -e "\nRsyincing backstop_data files to $CIRCLE_ARTIFACTS..."
    rsync -rlvz backstop_data $CIRCLE_ARTIFACTS

    DIFF_REPORT="$CIRCLE_ARTIFACTS/backstop_data/html_report/index.html"
    if [ ! -f $DIFF_REPORT ]; then
        echo -e "\nDiff report file $DIFF_REPORT not found!"
        exit 1
    fi
    DIFF_REPORT_URL="$CIRCLE_ARTIFACTS_URL/backstop_data/html_report/index.html"

    cd -
    if [[ ${VISUAL_REGRESSION_RESULTS} == *"Mismatch errors found"* ]]
    then
        # visual regression failed
        echo -e "\nVisual regression tests failed! Please manually check the ${MULTIDEV} multidev..."
        SLACK_MESSAGE="Circle CI update check #${CIRCLE_BUILD_NUM} by ${CIRCLE_PROJECT_USERNAME}. Visual regression tests failed on <https://dashboard.pantheon.io/sites/${SITE_UUID}#${MULTIDEV}/code|the ${MULTIDEV} environment>! Please test manually. Visual Regression Report: $DIFF_REPORT_URL"
        echo -e "\nSending a message to the ${SLACK_CHANNEL} Slack channel"
        curl -X POST --data "payload={\"channel\": \"${SLACK_CHANNEL}\", \"username\": \"${SLACK_USERNAME}\", \"text\": \"${SLACK_MESSAGE}\"}" $SLACK_HOOK_URL
    else
        # visual regression passed
        echo -e "\nVisual regression tests passed between the ${MULTIDEV} multidev and live."

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
        SLACK_MESSAGE="Circle CI update check #${CIRCLE_BUILD_NUM} by ${CIRCLE_PROJECT_USERNAME} Visual regression tests passed! WordPress updates deployed to <https://dashboard.pantheon.io/sites/${SITE_UUID}#live/deploys|the live environment>.  Visual Regression Report: $DIFF_REPORT_URL"
        echo -e "\nSending a message to the ${SLACK_CHANNEL} Slack channel"
        curl -X POST --data "payload={\"channel\": \"${SLACK_CHANNEL}\", \"username\": \"${SLACK_USERNAME}\", \"text\": \"${SLACK_MESSAGE}\"}" $SLACK_HOOK_URL
    fi
fi
