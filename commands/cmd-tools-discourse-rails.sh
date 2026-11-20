#!/usr/bin/env bash

# Installed by the Discourse plugin (plugins.sh --install discourse); __WORKSPACE__ is the workspace it was installed into.
#
# The Rails and the rake of one Discourse forum of this workspace, in its container: say what the forum
# is, run a rails or a rake command, start the forum again, add or cancel the default accounts, put the
# sample data back. Nothing here runs on the host.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="discourse";

ARGPARSE_DESCRIPTION="Run the Rails and rake of a Discourse forum of __WORKSPACE__: status, a rails or rake command, a restart, the default accounts, the sample data"
# The args file comes with the plugin: core/scripts/plugins/discourse/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/discourse/args/arg-discourse-rails.sh || exit 1 ;

shift $#;

discourse_rails_tool ;
