#!/bin/bash
if [[ (${CIRCLE_BRANCH} != "master" && -z ${CIRCLE_PULL_REQUEST+x}) || (${CIRCLE_BRANCH} == "master" && -n ${CIRCLE_PULL_REQUEST+x}) ]];
then
    echo -e "CircleCI will only run Behat tests on Pantheon if on the master branch or creating a pull requests.\n"
    exit 0;
fi

# Bail if required environment varaibles are missing
if [ -z "$SITE_NAME" ] || [ -z "$MULTIDEV" ]
then
    echo 'No test site specified. Set SITE_NAME and MULTIDEV.'
    exit 1
fi

if [ -z "$WORDPRESS_ADMIN_USERNAME" ] || [ -z "$WORDPRESS_ADMIN_PASSWORD" ]
then
    echo "No WordPress credentials specified. Set WORDPRESS_ADMIN_USERNAME and WORDPRESS_ADMIN_PASSWORD."
    exit 1
fi

echo "::::::::::::::::::::::::::::::::::::::::::::::::"
echo "Behat test site: $SITE_NAME.$MULTIDEV"
echo "::::::::::::::::::::::::::::::::::::::::::::::::"
echo

# login to Terminus
echo -e "\nLogging into Terminus..."
terminus auth:login --machine-token=${TERMINUS_MACHINE_TOKEN}

export WORKING_DIR=$(pwd)

# Check for tests to run
if [ ! -d $WORKING_DIR/tests/behat/$SITE_NAME ]; then
    echo -e "\n Behat test directory $WORKING_DIR/tests/behat/$SITE_NAME not found"
    exit 1
fi

# Create a backup before running Behat tests
if [[ "$RECREATE_MULTIDEV" == "0" ]]
then
    echo -e "\n Reacreation of multidev was skipped so making a backup before running Behat tests"
    terminus -n backup:create $SITE_NAME.$MULTIDEV
fi

# Clear site cache
terminus -n env:clear-cache $SITE_NAME.$MULTIDEV

# Check if the WordPress admin user exists
WORDPRESS_ADMIN_USER_LIST="$(terminus -n wp $SITE_NAME.$MULTIDEV -- user list --field=user_login --role=administrator)"

while read -r USER; do
    if [[ "${USER}" == "$WORDPRESS_ADMIN_USERNAME" ]]; then
        terminus -n wp $SITE_NAME.$MULTIDEV -- user delete $WORDPRESS_ADMIN_USERNAME --yes
    fi
done <<< "$WORDPRESS_ADMIN_USER_LIST"

{
terminus -n wp $SITE_NAME.$MULTIDEV -- user create $WORDPRESS_ADMIN_USERNAME no-reply@getpantheon.com --user_pass=$WORDPRESS_ADMIN_PASSWORD --role=administrator
} &> /dev/null

# Set Behat variables from environment variables
export BEHAT_PARAMS='{"extensions":{"Behat\\MinkExtension":{"base_url":"https://'$MULTIDEV'-'$SITE_NAME'.pantheonsite.io"},"PaulGibbs\\WordpressBehatExtension":{"site_url":"https://'$MULTIDEV'-'$SITE_NAME'.pantheonsite.io","users":{"admin":{"username":"'$WORDPRESS_ADMIN_USERNAME'","password":"'$WORDPRESS_ADMIN_PASSWORD'"}},"wpcli":{"binary":"terminus -n wp '$SITE_NAME'.'$MULTIDEV' --"}}}}'

# Wake the multidev environment before running tests
terminus -n env:wake $SITE_NAME.$MULTIDEV

# Ping wp-cli to start ssh with the app server
terminus -n wp $SITE_NAME.$MULTIDEV -- cli version

# Install Composer dependencies
composer install --no-ansi --no-interaction --optimize-autoloader --no-progress

# Run the Behat tests
cd $WORKING_DIR/tests/behat/$SITE_NAME

# Stash the Behat results
echo -e "\n Running Behat..."
BEHAT_RESULTS=$($WORKING_DIR/vendor/bin/behat --config=$WORKING_DIR/tests/behat/behat-pantheon.yml --strict "$@" || echo 'true' )

# Output
echo "$BEHAT_RESULTS"

# Change back into working directory
cd $WORKING_DIR

# Restore the backup made before testing
if [[ "$RECREATE_MULTIDEV" == "0" ]]
then
    echo -e "\n Reacreation of multidev was skipped so restoring the backup made before running Behat tests"
    terminus -n backup:restore $SITE_NAME.$MULTIDEV --element=database --yes
fi

if [[ ${BEHAT_RESULTS} == *"Failed scenarios"* ]]
then
	# Behat failed
    SLACK_MESSAGE="Behat tests failed for $SITE_NAME! Halting deployment. Please check the logs for more details."
    SLACK_ATTACHEMENTS="\"attachments\": [{\"fallback\": \"View the Behat log in CircleCI\",\"color\": \"${RED_HEX}\",\"actions\": [{\"type\": \"button\",\"text\": \"Behat test logs\",\"url\":\"${CIRCLE_BUILD_URL}\"}]}]"
else
    SLACK_MESSAGE="Behat tests passed for $SITE_NAME! Proceeding with deployment."
    SLACK_ATTACHEMENTS="\"attachments\": [{\"fallback\": \"View the Behat log in CircleCI\",\"color\": \"${GREEN_HEX}\",\"actions\": [{\"type\": \"button\",\"text\": \"Behat test logs\",\"url\":\"${CIRCLE_BUILD_URL}\"}]}]"
fi

echo -e "\n$SLACK_MESSAGE"

# Post the report back to Slack
echo -e "\nSending a message to the ${SLACK_CHANNEL} Slack channel"
curl -X POST --data "payload={\"channel\": \"${SLACK_CHANNEL}\",${SLACK_ATTACHEMENTS}, \"username\": \"${SLACK_USERNAME}\", \"text\": \"${SLACK_MESSAGE}\"}" $SLACK_HOOK_URL

if [[ ${BEHAT_RESULTS} == *"Failed scenarios"* ]]
then
	# Behat failed
    exit 1
fi


# Deploy updates
echo -e "\nStarting the deploy job via API for $SITE_NAME..."
#curl --user ${CIRCLE_TOKEN}: \
#            --data build_parameters[CIRCLE_JOB]=deploy_updates \
#            --data build_parameters[SITE_NAME]=$SITE_NAME \
#            --data build_parameters[VISUAL_REGRESSION_HTML_REPORT_URL]=$VISUAL_REGRESSION_HTML_REPORT_URL \
#            --data build_parameters[LIGHTHOUSE_SCORE]=$LIGHTHOUSE_SCORE \
#            --data build_parameters[LIGHTHOUSE_HTML_REPORT_URL]=$LIGHTHOUSE_HTML_REPORT_URL \
#            --data build_parameters[LIGHTHOUSE_PRODUCTION_SCORE]=$LIGHTHOUSE_PRODUCTION_SCORE \
#            --data build_parameters[LIGHTHOUSE_PRODUCTION_HTML_REPORT_URL]=$LIGHTHOUSE_PRODUCTION_HTML_REPORT_URL \
#            --data build_parameters[LIGHTHOUSE_ACCEPTABLE_THRESHOLD]=$LIGHTHOUSE_ACCEPTABLE_THRESHOLD \
#            --data build_parameters[BEHAT_LOG_URL]=$CIRCLE_BUILD_URL \
#            --data build_parameters[SITE_UUID]=$SITE_UUID \
#            --data build_parameters[CREATE_BACKUPS]=$CREATE_BACKUPS \
#            --data build_parameters[RECREATE_MULTIDEV]=$RECREATE_MULTIDEV \
#            --data build_parameters[LIVE_URL]=$LIVE_URL \
#            --data revision=$CIRCLE_SHA1 \
#            https://circleci.com/api/v1.1/project/github/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/tree/$CIRCLE_BRANCH  >/dev/null
