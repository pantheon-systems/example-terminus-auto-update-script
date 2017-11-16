#!/bin/bash

# Read which sites to update from sites-to-update.json
while IFS= read -r SITE_UUID &&
	IFS= read -r SITE_NAME &&
	IFS= read -r CREATE_BACKUPS &&
	IFS= read -r RECREATE_MULTIDEV &&
	IFS= read -r LIVE_URL; do
	
	# Start check_for_updates job via API
	echo -e "\nStarting the check for updates job via API for $SITE_NAME..."
	if [[ "$CREATE_BACKUPS" == "0" ]]
	then
		echo -e "Skipping backups for $SITE_NAME..."
	fi
	if [[ "$RECREATE_MULTIDEV" == "0" ]]
	then
		echo -e "Skipping recreation of multidev for $SITE_NAME..."
	fi

	curl --user ${CIRCLE_TOKEN}: \
				--data build_parameters[CIRCLE_JOB]=check_for_updates \
				--data build_parameters[SITE_NAME]=$SITE_NAME \
				--data build_parameters[SITE_UUID]=$SITE_UUID \
				--data build_parameters[CREATE_BACKUPS]=$CREATE_BACKUPS \
				--data build_parameters[RECREATE_MULTIDEV]=$RECREATE_MULTIDEV \
				--data build_parameters[LIVE_URL]=$LIVE_URL \
				--data revision=$CIRCLE_SHA1 \
				https://circleci.com/api/v1.1/project/github/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/tree/$CIRCLE_BRANCH  >/dev/null

done < <(jq -r '.[] | (.SITE_UUID, .SITE_NAME, .CREATE_BACKUPS, .RECREATE_MULTIDEV, LIVE_URL)' < "$(dirname "$pwd")/sites-to-auto-update.json")