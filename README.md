# Pantheon WordPress Auto Update #

## Description ##
Automated testing and deployment of WordPress core, plugin and theme updates on a [Pantheon](https://pantheon.io) site with help from [Terminus](https://github.com/pantheon-systems/terminus), [CircleCI](https://circleci.com), [WP-CLI](http://wp-cli.org/), [BackstopJS](https://garris.github.io/BackstopJS/) and [Slack](https://slack.com/).

This script will:

1. Authenticate with [Terminus](https://github.com/pantheon-systems/terminus) via machine token
2. Delete the multidev environment `update-wp`
3. Recreate the multidev environment `update-wp`
	* Deletion and recreation is done to clear any existing changes and pull the latest database/files from the live environment
4. Switch the multidev environment `update-wp` to Git mode
5. [Apply Pantheon upstream updates](https://pantheon.io/docs/upstream-updates/)
	* WordPress core updates are managed in the upstream
6. Switch the multidev environment `update-wp` to SFTP mode
7. Check for and apply WordPress plugin updates via [WP-CLI](http://wp-cli.org/), if available
8. Check for and apply WordPress theme updates via [WP-CLI](http://wp-cli.org/), if available
	* If no WordPress updates are available the script will complete and report the Slack
9. Use BackstopJS to run a visual regression test between the live environment and the multidev environment
	* If discrepencies are found the script will fail and link to the report in Slack
10. Merge the multidev environment with the dev environment
11. Deploy the dev environment to the test environment
12. Deploy the test environment to the live environment
13. Post a success message to Slack

## License ##
[GPLv2 or later](http://www.gnu.org/licenses/gpl-2.0.html)

## Setup ##
1. Fork this repository or use this code to create your own
2. Update _scenarios_ in `backstop.js` with URLs for pages you wish to check with visual regression
	* `url` refers to the live URL and `referenceUrl` refers to the same page on the Pantheon multidev environment
3. Create a [CircleCI](https://circleci.com) project
4. Add [environment variables to CircleCI](https://circleci.com/docs/environment-variables/) for the following:
	* `SITE_UUID`: The [Pantheon site UUID](https://pantheon.io/docs/sites/#site-uuid)
	* `TERMINUS_MACHINE_TOKEN`: A [Pantheon Terminus machine token](https://pantheon.io/docs/machine-tokens/) with access to the site
	* `SLACK_HOOK_URL`: The [Slack incoming webhook URL](https://api.slack.com/incoming-webhooks)
	* `SLACK_CHANNEL`: The Slack channel to post notifications to
	* `SLACK_USERNAME`: The username to post to Slack with
5. Add an [SSH key to Pantheon](https://pantheon.io/docs/ssh-keys/) and [to the CircleCI project](https://circleci.com/docs/permissions-and-access-during-deployment/)
6. Ping the [CircleCI API](https://circleci.com/docs/api/) at the desired frequency, e.g. daily, to run the script. You will need to set the `CRON_BUILD` variable, sent as POST data. See the [nightly build doc](https://circleci.com/docs/1.0/nightly-builds/) for details.
	* You can use a free service such as [cron-job.org](https://cron-job.org/en/) with the following configuration:
		* Address: `https://circleci.com/api/v1.1/project/github/[GITHUB-USERNAME]/[PROJECT]?circle-token=[CIRCLECI-PERSONAL-API-TOKEN]` (Get a token at https://circleci.com/account/api)
		* Request method: `POST`
		* You'll need to save the cron job and edit it again before you can add these important settings:
			* Header: `Content-Type`
			* Value: `application/json`
			* Request Body: `{"build_parameters" : {"CRON_BUILD" : "1"}}`

## Notes ##
This workflow assumes that the Dev and Test environments on Pantheon are always in a shippable state as the script will automatically deploy changes from Dev to Test and Live if the tests pass.

All incomplete work should be kept in a [Pantheon multidev environment](https://pantheon.io/docs/multidev/), on a separate Git branch.
