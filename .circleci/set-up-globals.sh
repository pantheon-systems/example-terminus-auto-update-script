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

# Check to see if the multidev is already defined in the environment variable. If not, define it now.
if [ -z "$MULTIDEV" ]
then
    echo 'export MULTIDEV=update-wp' >> $BASH_ENV
fi

# Stash site URLs
echo "export MULTIDEV_URL='https://$MULTIDEV-$SITE_NAME.pantheonsite.io/'" >> $BASH_ENV
if [ -z "$LIVE_URL" ]
then
	echo "export LIVE_URL='https://live-$SITE_NAME.pantheonsite.io/'" >> $BASH_ENV
fi

echo 'export PATH=$PATH:$HOME/bin:$HOME/terminus/bin' >> $BASH_ENV

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