#!/bin/bash

MULTIDEV="update-wp"

SITE_UUID="02854fa0-b6e4-4349-932a-8aa7d9cab884"

# login to Terminus
echo -e "\nlogging into Terminus..."
terminus auth login

# ping the multidev environment to wake it from sleep
echo -e "\npinging the ${MULTIDEV} multidev environment to wake it from sleep..."
curl -I https://update-wp-wp-microsite.pantheonsite.io/

# delete the multidev environment
echo -e "\ndeleting the ${MULTIDEV} multidev environment..."
terminus site delete-env --site=${SITE_UUID} --env=${MULTIDEV} --remove-branch --yes

# recreate the multidev environment
echo -e "\nre-creating the ${MULTIDEV} multidev environment..."
terminus site create-env --site=${SITE_UUID} --from-env=dev --to-env=${MULTIDEV}

# making sure the multidev is in git mode
echo -e "\nsetting the ${MULTIDEV} multidev to git mode"
terminus site set-connection-mode --site=${SITE_UUID} --env=${MULTIDEV} --mode=git

# apply upstream updates, if applicable
echo -e "\napplying upstream updates to the ${MULTIDEV} multidev..."
terminus site upstream-updates apply --site=${SITE_UUID} --env=${MULTIDEV}

# making sure the multidev is in SFTP mode
echo -e "\nsetting the ${MULTIDEV} multidev to SFTP mode"
terminus site set-connection-mode --site=${SITE_UUID} --env=${MULTIDEV} --mode=sftp

# check for WordPress core updates
#echo -e "\nchecking for WordPress core updates on the ${MULTIDEV} multidev..."
#CORE_UPDATES=$(terminus wp "core check-update" --site=${SITE_UUID} --env=${MULTIDEV} --format=bash)
#
#if [[ ${CORE_UPDATES} == *"WordPress is at the latest version"* ]]
#then
#    # no WordPress core updates found
#    echo -e "\nno WordPress core updates found on the ${MULTIDEV} multidev..."
#else
#    # update WordPress core
#    echo -e "\nupdating WordPress core on the ${MULTIDEV} multidev..."
#    terminus wp "core update" --site=${SITE_UUID} --env=${MULTIDEV}
#
#    # committing updated WordPress core
#    echo -e "\ncommitting WordPress core updates on the ${MULTIDEV} multidev..."
#    terminus site code commit --site=${SITE_UUID} --env=${MULTIDEV} --message="update WordPress core" --yes
#fi

# check for WordPress plugin updates
echo -e "\nchecking for WordPress plugin updates on the ${MULTIDEV} multidev..."
PLUGIN_UPDATES=$(terminus wp "plugin list --field=update" --site=${SITE_UUID} --env=${MULTIDEV} --format=bash)

if [[ ${PLUGIN_UPDATES} == *"available"* ]]
then
    # update WordPress plugins
    echo -e "\nupdating WordPress plugins on the ${MULTIDEV} multidev..."
    terminus wp "plugin update --all" --site=${SITE_UUID} --env=${MULTIDEV}

    # committing updated WordPress plugins
    echo -e "\ncommitting WordPress plugin updates on the ${MULTIDEV} multidev..."
    terminus site code commit --site=${SITE_UUID} --env=${MULTIDEV} --message="update WordPress plugins" --yes
else
    # no WordPress plugin updates found
    echo -e "\nno WordPress plugin updates found on the ${MULTIDEV} multidev..."
fi

# check for WordPress theme updates
echo -e "\nchecking for WordPress theme updates on the ${MULTIDEV} multidev..."
THEME_UPDATES=$(terminus wp "theme list --field=update" --site=${SITE_UUID} --env=${MULTIDEV} --format=bash)

if [[ ${THEME_UPDATES} == *"available"* ]]
then
    # update WordPress themes
    echo -e "\nupdating WordPress plugins on the ${MULTIDEV} multidev..."
    terminus wp "theme update --all" --site=${SITE_UUID} --env=${MULTIDEV}

    # committing updated WordPress themes
    echo -e "\ncommitting WordPress theme updates on the ${MULTIDEV} multidev..."
    terminus site code commit --site=${SITE_UUID} --env=${MULTIDEV} --message="update WordPress themes" --yes
else
    # no WordPress theme updates found
    echo -e "\nno WordPress theme updates found on the ${MULTIDEV} multidev..."
fi

# visual regression with Bactrack
# echo -e "\nstarting visual regression test between live and the ${MULTIDEV} multidev..."
# curl --header 'x-api-key: b0d82d371962671ebb02c5080a8f0a59' --request POST https://backtrac.io/api/project/24520/compare_prod_dev

# install node dependencies
echo -e "\nrunning npm install..."
npm install

# backstop visual regression
echo -e "\nrunning BackstopJS tests..."

cd node_modules/backstopjs

npm run reference
# npm run test

VISUAL_REGRESSION_RESULTS=$(npm run test)

echo "${VISUAL_REGRESSION_RESULTS}"

cd -

if [[ ${VISUAL_REGRESSION_RESULTS} == *"Mismatch errors found"* ]]
then
    # visual regression failed
    echo -e "\nVisual regression tests failed! Please manually check the ${MULTIDEV} multidev..."
    exit 1
else
    # visual regression passed
    echo -e "\nVisual regression tests passed. Merging the ${MULTIDEV} multidev back into master..."
fi