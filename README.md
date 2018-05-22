# Pantheon Example Terminus Auto Update Script

## Description

Scalable automated testing and deployment of upstream (core), plugin and theme updates on [Pantheon](https://pantheon.io) sites. This repository uses these open source tools:
* [Terminus](https://github.com/pantheon-systems/terminus) for interacting with Pantheon on the command line
* [CircleCI](https://circleci.com) for running jobs in the cloud
* [WP-CLI](http://wp-cli.org/) for interacting with WordPress on the command line
* [Drush](https://www.drush.org/) for interacting with Drupal on the command line
* [Behat](http://behat.org/) for integration and acceptance testing
* [WordHat](https://wordhat.info/) for WordPress-specific functionality for common testing scenarios in Behat
* [Google Lighthouse](https://developers.google.com/web/tools/lighthouse/) for performance testing
* [BackstopJS](https://garris.github.io/BackstopJS/) for visual regression testing
* [Slack](https://slack.com/) for communication

## Disclaimer
While this script has worked well for us your mileage may vary. This repository is a proof of concept example of advanced Pantheon platform usage and is provided without warranty or direct support.

Issues and questions may be filed in GitHub but their resolution is not guaranteed.

## The Process

This script will loop through all sites in `sites-to-auto-update.json` and:

1. Authenticate with [Terminus](https://github.com/pantheon-systems/terminus) via machine token
2. Delete the multidev environment `auto-update`
3. Recreate the multidev environment `auto-update`
	* Deletion and recreation is done to clear any existing changes and pull the latest database/files from the live environment
	* This is opt-out per site and should only be disabled if using Solr or multidev creation takes an excessively long time due to large file and database sizes
4. Switch the multidev environment `auto-update` to git mode
5. Check for and apply [Pantheon upstream updates](https://pantheon.io/docs/upstream-updates/)
	* WordPress or Drupal core updates are managed in the default upstream
	* Custom upstream updates will be applied if using a custom upstream
6. Switch the multidev environment `auto-update` to SFTP mode
7. Check for and apply WordPress plugin or Drupal module updates, if available
8. Check for and apply WordPress theme updates, if available
	* If no updates are available the script will stop here
9. Run a visual regression test between the live environment and the multidev environment
	* If the visual regression test fails the script will stop here and post a link to the visual regression report in Slack
10. Merge the multidev environment with the dev environment
11. Deploy the dev environment to the test environment
12. Create a backup of the test environment
	* This is opt-out per site and should only be disabled if backups take an excessively long time due to large file and database sizes **and** you have regularly backups scheduled via another method.
13. Create a backup of the live environment
    * This is opt-out per site and should only be disabled if backups take an excessively long time due to large file and database sizes **and** you have regularly backups scheduled via another method.
14. Deploy the test environment to the live environment
15. Post a success message to Slack
    * Test failures will also be reported to Slack

## Setup
0. Create a new GitHub repository
1. Don't fork this repository, instead clone it and [change the remote URL](https://help.github.com/articles/changing-a-remote-s-url/) to the GitHub repository above and push the code there
2. Update `backstop.template.json` to meet your needs
    * For example, you may want to tweak things like `viewport`
3. Create a [CircleCI](https://circleci.com) project
    * It should be linked to your GitHub repository
4. Add [environment variables to CircleCI](https://circleci.com/docs/environment-variables/) for the following:
	* `MULTIDEV`: The multidev name to use for applying/testing updates. Defaults to `auto-update`
	* `CIRCLE_TOKEN`: A CircleCI API token with access to the CircleCI project created above.
	* `TERMINUS_MACHINE_TOKEN`: A [Pantheon Terminus machine token](https://pantheon.io/docs/machine-tokens/) with access to all the sites you plan to update.
	* `SLACK_HOOK_URL`: The [Slack incoming webhook URL](https://api.slack.com/incoming-webhooks)
	* `SLACK_CHANNEL`: The Slack channel to post notifications to
	* `SLACK_USERNAME`: The username to post to Slack with
5. Add an [SSH key to Pantheon](https://pantheon.io/docs/ssh-keys/) and [to the CircleCI project](https://circleci.com/docs/permissions-and-access-during-deployment/)
6. Edit `sites-to-auto-update.json` and set the following key for each JSON object for sites you wish to auto update. **The order is important** do not change the order of the keys in the object or skip keys.
	* `SITE_UUID`: The site UUID, which can be acquired with `terminus site:list` or is in the dashboard URL for the site.
	* `SITE_NAME`: The site machine name, which can be acquired with `terminus site:list`.
	* `CREATE_BACKUPS`: `0` or `1` to determine if a backup of the site is made before deployment. You may want to disable backups for sites where a backup takes an excessively long time due to large file and database sizes **and** you have regularly backups scheduled via another method.
	* `RECREATE_MULTIDEV`: `0` or `1` to determine if the multidev is deleted and recreated with each run.
	* `LIVE_URL`: The preferred custom domain (full URL) for the live environment to use in automated testing **or** set to `0` to use the default Pantheon hosted URL,

## Know Limitations
* Backups of sites with large a large database or media files are taking too long and timing out on Circle CI
* Sites with a Solr Index fail visual regression tests as the multidev created doesn't have items indexed in Solr
* `backstop-crawl` on sites with many (~100+) URLs are taking too long and timing out on Circle CI.
    * This can be alleviated with a custom `SITE_NAME.backstop.json` or `SITE_NAME.backstop-config.js` file.
* If automated testing fails **and** `RECREATE_MULTIDEV` is set to `0` then a multidev with updates applied will persist causing subsequent update checks to return no updates and prevent automated tests from running again. This cycle will break when there are further updates released to be applied.
* [Composer](https"//getcomposer.org) managed sites are not supported. For Composer managed sites a service like [dependencies.io](https://www.dependencies.io/), which will create pull requests for Composer updates, is useful.

## Configuring Backstop JS
`backstop.template.json` is used as a generic template for `backstop-crawl` when creating `backstop.json` files dynamically.

For each site a custom template in the form of `SITE_NAME.backstop.json` or `SITE_NAME.backstop-config.js`, where `SITE_NAME` is the machine name for the Pantheon site, can be also be created and will take precedence over the template above. The former is a hard coded Backstop JS file and the latter is a JavaScript file that must export valid JSON contents of a Backstop JS file.

The custom templates above are most useful for sites with many URLs where a crawl will timeout. In this case manually specifying which URLs to test is needed.

## Behat Tests
Behat testing is currently only supported for WordPress sites. To have Behat tests run for a site create Behat feature files in the directory `tests/behat/<site-name>/features`, replacing `<site-name>` with the Pantheon site machine name.

## Notes
This workflow assumes that the Dev and Test environments on Pantheon are always in a shippable state as the script will automatically deploy changes from Dev to Test and Live if the visual regression tests of updates pass.

All work that isn't ready for deployment to production should be kept in a [Pantheon multidev environment](https://pantheon.io/docs/multidev/), on a separate git branch.

Scalability relies on the number of CircleCI workers available. If workers are available to process jobs in parallel this script will scale very well.

## Changelog
### `1.0.0`
* Initial release

## License
[GPLv2 or later](http://www.gnu.org/licenses/gpl-2.0.html)
