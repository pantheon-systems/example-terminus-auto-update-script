# Pantheon WordPress Auto Update #

## Description ##
Automated testing and deployment of WordPress core, plugin and theme updates on a [Pantheon](https://pantheon.io) site with help from [Terminus](https://github.com/pantheon-systems/terminus), [CircleCI](https://circleci.com), [WP-CLI](http://wp-cli.org/), [BackstopJS](https://garris.github.io/BackstopJS/) and [Slack](https://slack.com/).

This script will:

1. Authenticate with [Terminus](https://github.com/pantheon-systems/terminus) via machine token
2. Delete the multidev environment `update-wp`
3. Recreate the multidev environment `update-wp`
	* Deletion and recreation is done to clear any existing changes and pull the latest database/files from the live environment
4. Switch the multidev environment `update-wp` to git mode
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
1. Don't fork this repository, instead clone it and [change the remote URL](https://help.github.com/articles/changing-a-remote-s-url/) to your own fresh GitHub repository and push the code there
2. Update `backstop.template.json` to meet your needs, tweaking things like `viewport`
3. Create a [CircleCI](https://circleci.com) project
4. Add [environment variables to CircleCI](https://circleci.com/docs/environment-variables/) for the following:
	* `ORG_UUID`: The Pantheon org UUID for the organization containing the sites to update
	* `UPDATE_TAG`: The Pantheon site tag applied in the organization from the step above to sites that need auto updates. Defaults to `auto-update`
	* `MULTIDEV`: The multidev name to use for applying/testing updates. Defaults to `update-wp`
	* `CIRCLE_TOKEN`: A Circle CI API token with access to the project created in step 3.
	* `TERMINUS_MACHINE_TOKEN`: A [Pantheon Terminus machine token](https://pantheon.io/docs/machine-tokens/) with access to the org above.
	* `SLACK_HOOK_URL`: The [Slack incoming webhook URL](https://api.slack.com/incoming-webhooks)
	* `SLACK_CHANNEL`: The Slack channel to post notifications to
	* `SLACK_USERNAME`: The username to post to Slack with
5. Add an [SSH key to Pantheon](https://pantheon.io/docs/ssh-keys/) and [to the CircleCI project](https://circleci.com/docs/permissions-and-access-during-deployment/)

## Notes ##
This workflow assumes that the Dev and Test environments on Pantheon are always in a shippable state as the script will automatically deploy changes from Dev to Test and Live if the visual regression tests of updates pass.

All work that isn't ready for deployment to production should be kept in a [Pantheon multidev environment](https://pantheon.io/docs/multidev/), on a separate git branch.
