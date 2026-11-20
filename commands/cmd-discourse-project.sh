#!/usr/bin/env bash

# workspace-name: Discourse (discourse_docker, a forum in a container)

# Installed by the Discourse plugin (plugins.sh --install discourse); __WORKSPACE__ is the workspace it was installed into.
#
# Build a Discourse forum in a container: the forum's current release, installed the official way with
# discourse_docker's launcher (its standalone template: PostgreSQL, Redis and the web server in one
# container), run as a service of the project, at https://<name>.ddev.site, its mail caught by the
# project's mail catcher. With --install the workspace account becomes its admin; with --add-users it
# also gets the default accounts; with --sample-data categories, tags, topics, replies and a message.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="discourse";
distribution_title="Discourse";
distribution_webroot="";

ARGPARSE_DESCRIPTION="Build a ${distribution_title} project in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/discourse/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/discourse/args/arg-discourse.sh || exit 1 ;

shift $#;

discourse_build ;
