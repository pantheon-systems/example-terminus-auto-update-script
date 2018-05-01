#!/bin/bash
echo -e "\nKicking off an update check for ${SITE_NAME} with UUID ${SITE_UUID}..."

# login to Terminus
echo -e "\nLogging into Terminus..."
terminus auth:login --machine-token=${TERMINUS_MACHINE_TOKEN} > /dev/null 2>&1

# Bail on errors
set +ex

# Helper to see if a multidev exists
TERMINUS_DOES_MULTIDEV_EXIST()
{
    # Return 1 if on master since dev always exists
    if [[ ${CIRCLE_BRANCH} == "master" ]]
    then
        return 0;
    fi
    
    # Stash list of Pantheon multidev environments
    PANTHEON_MULTIDEV_LIST="$(terminus multidev:list -n ${SITE_NAME} --format=list --field=Name)"

    while read -r CURRENT_MULTIDEV; do
        if [[ "${CURRENT_MULTIDEV}" == "$1" ]]
        then
            return 0;
        fi
    done <<< "$PANTHEON_MULTIDEV_LIST"

    return 1;
}

if [[ "$RECREATE_MULTIDEV" == "0" ]]
then
	echo -e "\nSkipping deletion and recreation of multidev for ${SITE_NAME}..."
else
	# delete the multidev environment if it exists
	echo -e "\nDeleting the ${MULTIDEV} multidev environment for ${SITE_NAME}..."
	terminus multidev:delete $SITE_UUID.$MULTIDEV --delete-branch --yes
fi

# Create the multidev environment
if ! TERMINUS_DOES_MULTIDEV_EXIST $MULTIDEV
then
    echo -e "\nCreating the ${MULTIDEV} multidev environment for ${SITE_NAME}..."
    terminus multidev:create $SITE_NAME.live $MULTIDEV
fi

# check for upstream updates
echo -e "\nChecking for upstream updates on the ${MULTIDEV} multidev for ${SITE_NAME}..."
# the output goes to stderr, not stdout
UPSTREAM_UPDATES="$(terminus upstream:updates:list ${SITE_UUID}.${MULTIDEV}  --format=list  2>&1)"

UPDATES_APPLIED=false

if [[ ${UPSTREAM_UPDATES} == *"no available updates"* ]]
then
    # no upstream updates available
    echo -e "\nNo upstream updates found on the ${MULTIDEV} multidev for ${SITE_NAME}..."
else
    # making sure the multidev is in git mode
    echo -e "\nSetting the ${MULTIDEV} multidev to git mode"
    terminus connection:set $SITE_UUID.$MULTIDEV git

    # apply WordPress upstream updates
    echo -e "\nApplying upstream updates on the ${MULTIDEV} multidev for ${SITE_NAME}..."
    terminus upstream:updates:apply $SITE_UUID.$MULTIDEV --yes --updatedb --accept-upstream
    UPDATES_APPLIED=true

    if [[ ${CMS_FRAMEWORK} == "wordpress" ]]
    then
        terminus -n wp $SITE_UUID.$MULTIDEV -- core update-db
    fi
    
    if [[ ${CMS_FRAMEWORK} == "drupal" ]]
    then
        terminus -n drush $SITE_UUID.$MULTIDEV -- updatedb
    fi
    
fi

# making sure the multidev is in SFTP mode
echo -e "\nSetting the ${MULTIDEV} multidev to SFTP mode for ${SITE_NAME}..."
terminus connection:set $SITE_UUID.$MULTIDEV sftp

# Wake pantheon SSH
terminus -n wp $SITE_UUID.$MULTIDEV -- cli version

echo -e "\nChecking for ${CMS_CONTRIB} updates on the ${MULTIDEV} multidev for ${SITE_NAME}..."

# check for WordPress plugin updates
if [[ ${CMS_FRAMEWORK} == "wordpress" ]]
then

    PLUGIN_UPDATES=$(terminus -n wp ${SITE_UUID}.${MULTIDEV} -- plugin list --update=available --format=count)

    echo $PLUGIN_UPDATES

    if [[ "$PLUGIN_UPDATES" == "0" ]]
    then
        # no WordPress plugin or Drupal module updates found
        echo -e "\nNo ${CMS_CONTRIB} updates found on the ${MULTIDEV} multidev for $SITE_NAME..."
    else
        # update WordPress plugins or Drupal modules
        echo -e "\nUpdating ${CMS_CONTRIB}s on the ${MULTIDEV} multidev for $SITE_NAME..."
        terminus -n wp $SITE_UUID.$MULTIDEV -- plugin update --all

        # wake the site environment before committing code
        echo -e "\nWaking the ${MULTIDEV} multidev..."
        terminus env:wake $SITE_UUID.$MULTIDEV

        # committing updated WordPress plugins or Drupal modules
        echo -e "\nCommitting ${CMS_CONTRIB} updates on the ${MULTIDEV} multidev for $SITE_NAME..."
        terminus env:commit $SITE_UUID.$MULTIDEV --force --message="update ${CMS_CONTRIB}"
        UPDATES_APPLIED=true
    fi
fi

# check for Drupal module updates
if [[ ${CMS_FRAMEWORK} == "drupal" ]]
then

    PLUGIN_UPDATES=$(terminus drush ${SITE_UUID}.${TERMINUS_ENV} -- pm-updatestatus --format=list --check-disabled | grep -v ok)

    echo $PLUGIN_UPDATES

    if [[ "$PLUGIN_UPDATES" == "" ]]
    then
        # no WordPress plugin or Drupal module updates found
        echo -e "\nNo ${CMS_CONTRIB} updates found on the ${MULTIDEV} multidev for $SITE_NAME..."
    else
        # update WordPress plugins or Drupal modules
        echo -e "\nUpdating ${CMS_CONTRIB}s on the ${MULTIDEV} multidev for $SITE_NAME..."
        terminus -n drush $SITE_UUID.$MULTIDEV -- pm-updatecode --no-core --yes

        # wake the site environment before committing code
        echo -e "\nWaking the ${MULTIDEV} multidev..."
        terminus env:wake $SITE_UUID.$MULTIDEV

        # committing updated WordPress plugins or Drupal modules
        echo -e "\nCommitting ${CMS_CONTRIB} updates on the ${MULTIDEV} multidev for $SITE_NAME..."
        terminus env:commit $SITE_UUID.$MULTIDEV --force --message="update ${CMS_CONTRIB}"
        UPDATES_APPLIED=true
    fi
fi

# check for WordPress theme updates
if [[ ${CMS_FRAMEWORK} == "wordpress" ]]
then
    echo -e "\nChecking for ${CMS_NAME} theme updates on the ${MULTIDEV} multidev for ${SITE_NAME}..."
    THEME_UPDATES=$(terminus -n wp ${SITE_UUID}.${MULTIDEV} -- theme list --update=available --format=count)
    echo $THEME_UPDATES

    if [[ "$THEME_UPDATES" == "0" ]]
    then
        # no WordPress theme updates found
        echo -e "\nNo WordPress theme updates found on the ${MULTIDEV} multidev for $SITE_NAME..."
    else
        # update WordPress themes
        echo -e "\nUpdating WordPress themes on the ${MULTIDEV} multidev for $SITE_NAME..."
        terminus -n wp $SITE_UUID.$MULTIDEV -- theme update --all

        # wake the site environment before committing code
        echo -e "\nWaking the ${MULTIDEV} multidev..."
        terminus env:wake $SITE_UUID.$MULTIDEV

        # committing updated WordPress themes
        echo -e "\nCommitting WordPress theme updates on the ${MULTIDEV} multidev for $SITE_NAME..."
        terminus env:commit $SITE_UUID.$MULTIDEV --force --message="update WordPress themes"
        UPDATES_APPLIED=true
    fi
fi

if [[ "${UPDATES_APPLIED}" = false ]]
then
    # no updates applied
    echo -e "\nNo updates to apply for $SITE_NAME..."
    #SLACK_MESSAGE="Circle CI update check #${CIRCLE_BUILD_NUM} by ${CIRCLE_PROJECT_USERNAME} on site ${SITE_NAME}. No updates to apply, nothing deployed."
    #echo -e "\nSending a message to the ${SLACK_CHANNEL} Slack channel"
    #curl -X POST --data "payload={\"channel\": \"${SLACK_CHANNEL}\", \"username\": \"${SLACK_USERNAME}\", \"text\": \"${SLACK_MESSAGE}\"}" $SLACK_HOOK_URL
else
    # Run visual regression tests
	echo -e "\nUpdates applied, starting the visual regression testing job via API for $SITE_NAME..."
	curl --user ${CIRCLE_TOKEN}: \
                --data build_parameters[CIRCLE_JOB]=visual_regression_test \
				--data build_parameters[SITE_NAME]=$SITE_NAME \
				--data build_parameters[SITE_UUID]=$SITE_UUID \
				--data build_parameters[CREATE_BACKUPS]=$CREATE_BACKUPS \
				--data build_parameters[RECREATE_MULTIDEV]=$RECREATE_MULTIDEV \
				--data build_parameters[LIVE_URL]=$LIVE_URL \
                --data revision=$CIRCLE_SHA1 \
                https://circleci.com/api/v1.1/project/github/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/tree/$CIRCLE_BRANCH  >/dev/null
fi
