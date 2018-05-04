#!/bin/bash

# login to Terminus
echo -e "\nLogging into Terminus..."
terminus auth:login --machine-token=${TERMINUS_MACHINE_TOKEN} > /dev/null 2>&1

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

source $BASH_ENV
