'use strict';

const BackstopReferenceBaseUrl = 'https://auto-update-review-signal-pantheon-elite-test-site.pantheonsite.io/';
const BackstopTestUrl = 'https://live-review-signal-pantheon-elite-test-site.pantheonsite.io/';

const simple_scenarios_paths = [
  // Single pages
  "/contact-us/",
  "/about/",
  "/hipster/",
  "/bacon/",
  // Single post
  "/2016/04/30/hello-world/",
  // Date archive
  "/2016/04/",
  // Category archive
  "/category/uncategorized/",
];

const config = {
  "id": "backstop_default",
  "viewports": [
    {
      "name": "phone",
      "width": 320,
      "height": 480
    },
    {
      "name": "tablet_v",
      "width": 568,
      "height": 1024
    },
    {
      "name": "tablet_h",
      "width": 1024,
      "height": 768
    },
    {
      "name": "desktop",
      "width": 1920,
      "height": 1080
    }
  ],
  "scenarios": [
    {
      "label": "Homepage",
      "url": BackstopTestUrl,
      "referenceUrl": BackstopReferenceBaseUrl,
	  "hideSelectors": [
          ".wp-block-embed.is-provider-vimeo",
      ],
	  "selectors": [
          "document",
      ],
	  "readyEvent": null,
	  "delay": 1500,
	  "misMatchThreshold": 0.1  
    }
  ],
  "paths": {
    "bitmaps_reference": "backstop_data/bitmaps_reference",
    "bitmaps_test": "backstop_data/bitmaps_test",
    "compare_data": "backstop_data/bitmaps_test/compare.json",
    "casper_scripts": "backstop_data/casper_scripts"
  },
  "engine": "chrome",
  "report": [ "CLI" ],
  "casperFlags": [],
  "debug": false,
  "port": 3001
}


const simple_scenarios = simple_scenarios_paths.map(function(path) {

  return {
	"label": path,
    "url": BackstopTestUrl + path,
    "referenceUrl":BackstopReferenceBaseUrl +  path,
	"hideSelectors": [
        ".wp-block-embed.is-provider-vimeo",
    ],
    "selectors": [
        "document",
    ],
	"readyEvent": null,
	"delay": 1500,
	"misMatchThreshold": 0.1 
   }
});

config.scenarios = config.scenarios.concat(simple_scenarios);

module.exports = config;
