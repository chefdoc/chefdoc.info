# Chefdoc.info: YARD Doc Server for Chef cookbooks

Chefdoc.info is a modern Chef cookbook documentation server. It is using yard-chefdoc https://github.com/chefdoc to generate cookbook documentation on the fly. Currently supported cookbook storage backends are:
* The official Chef supermarket (https://supermarket.chef.io) and private supermarket instances.
* Any Chef Server version 12.6 or newer.

More backends like GIT are planned.

The public service is hosted at http://chefdoc.info.

Chefdoc.info is an open source community project and not affiliated with Chef Software Inc. ("Chef").

## Developing

Check out the rake tasks for running chefdoc.info and building the Docker image.

## Running a local copy in Docker

The official docker image is published at https://hub.docker.com/u/chefdoc/. Check out the config/config.sample.yml for necessary configuration and lib/configuration.rb for default values.

There are also several environment variables that you can set to configure the service:
* REDIS_HOST: The FQDN of your Redis database.
* REDIS_PORT: The port of your Redis database, defaults to 6379.
* REDIS_DB:   The Redis database to use, defaults to 1.
* G_ANALYTICS_ID: Google Analytis ID if you want to use it.

The volume containing all data is attached to /data.

More documentation on how to run chefdoc can be found in the wiki at https://github.com/chefdoc/chefdoc.info/wiki.

# Thanks

Chefdoc.info was originally a fork of RubyDoc.info which was created by Loren Segal (YARD) and Nick Plante (rdoc.info) and is a project of DOCMETA, LLC. Special thanks go out to them for providing this great project as an open source solution.

(c) 2016 Jörg Herzinger. This code is distributed under the MIT license, see LICENSE for details.<br>
(c) 2015 DOCMETA LLC. This code is distributed under the MIT license.
