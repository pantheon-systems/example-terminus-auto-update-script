#!/bin/bash

set -ex

#=========================================================================
# Commands below this line would not be transferable to a docker container
#=========================================================================

#=====================================================================================================================
# Start EXPORTing needed environment variables
# Circle CI 2.0 does not yet expand environment variables so they have to be manually EXPORTed
# Once environment variables can be expanded this section can be removed
# See: https://discuss.circleci.com/t/unclear-how-to-work-with-user-variables-circleci-provided-env-variables/12810/11
# See: https://discuss.circleci.com/t/environment-variable-expansion-in-working-directory/11322
# See: https://discuss.circleci.com/t/circle-2-0-global-environment-variables/8681
#=====================================================================================================================

echo 'export PATH=$PATH:$HOME/bin:$HOME/terminus/bin' >> $BASH_ENV

source $BASH_ENV

# Check to see if the multidev is already defined in the environment variable. If not, define it now.
if [ -z "$MULTIDEV" ]
then
    echo 'export MULTIDEV=update-wp' >> $BASH_ENV
fi

if [ -z "$UPDATE_TAG" ]
then
    echo 'export UPDATE_TAG=auto-update' >> $BASH_ENV
fi

PANTHEON_FRAMEWORK="$(terminus site:info ${SITE_NAME} --field=framework)"

if [[ ${PANTHEON_FRAMEWORK} == "wordpress" ]]
then
    echo 'export CMS_FRAMEWORK="wordpress"' >> $BASH_ENV
    echo 'export CMS_NAME="WordPress"' >> $BASH_ENV
    echo 'export CMS_CONTRIB="WordPress plugins"' >> $BASH_ENV
fi

if [[ ${PANTHEON_FRAMEWORK} == "drupal" || ${PANTHEON_FRAMEWORK} == "drupal8" ]]
then
    echo 'export CMS_FRAMEWORK="drupal"' >> $BASH_ENV
    echo 'export CMS_NAME="Drupal"' >> $BASH_ENV
    echo 'export CMS_CONTRIB="Drupal modules"' >> $BASH_ENV
fi

echo 'export GREEN_HEX="008000"' >> $BASH_ENV
echo 'export RED_HEX="FF0000"' >> $BASH_ENV
RANDOM_PASS=$(openssl rand -hex 8)
echo "export CMS_ADMIN_USERNAME='pantheon'" >> $BASH_ENV
echo "export CMS_ADMIN_PASSWORD='$RANDOM_PASS'" >> $BASH_ENV

# Stash site URLs
echo "export MULTIDEV_URL='https://$MULTIDEV-$SITE_NAME.pantheonsite.io/'" >> $BASH_ENV
if [ -z "$LIVE_URL" ] || [ "$LIVE_URL" == "0" ]
then
	echo "export LIVE_URL='https://live-$SITE_NAME.pantheonsite.io/'" >> $BASH_ENV
else
	echo "using existing LIVE_URL $LIVE_URL for $SITE_NAME"
fi

source $BASH_ENV

#===========================================
# End EXPORTing needed environment variables
#===========================================

# Bail on errors
set +ex

# Disable host checking
if [ ! -d $HOME/.ssh ]
then
	mkdir -p $HOME/.ssh
fi
touch $HOME/.ssh/config
echo "StrictHostKeyChecking no" >> "$HOME/.ssh/config"