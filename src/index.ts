/**
 * Discourse for Webship Workspace: a platform plugin.
 *
 * What the package carries is placed by the installer from the manifest: the builder and the forum's
 * Rails and rake tool in the sites folders, their functions and argparse under
 * core/scripts/plugins/discourse/ (with discourse-site.rb, which the builder runs with the forum's own
 * Rails), and its AI items (ai/ in this package) in the folder of their kind: the agents in AI Agents,
 * the skill in AI Skills, the command in AI Commands, the prompts in AI Prompts. The dashboard needs
 * nothing drawn for it: the builder is in the Build list because it is a cmd-*-project.sh, the row
 * menus are the core's, the AI items are listed like any other. What register() adds is what the
 * assistant is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the
 * dashboard's own files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';

/** The plugin's name. A Discourse forum is a generic DDEV project: the plugin knows it by .ddev/config.discourse.yaml. */
export const PLATFORM = 'discourse';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-discourse-project.sh', 'cmd-tools-discourse-rails.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['discourse-site-builder', 'discourse-tester'];

/** The skill the installer places in the AI Skills folder (a folder each, with its SKILL.md). */
export const SKILLS = ['discourse-scenarios'];

/** The slash command the installer places in the AI Commands folder. */
export const AI_COMMANDS = ['discourse-test'];

/** The prompts the installer places in the AI Prompts folder: each a whole launch command for a new session. */
export const PROMPTS = ['discourse-build-and-test', 'discourse-scenarios-for-an-area'];

/** What the assistant is told about Discourse in this workspace. */
export function assistantContext(): string {
  return [
    'Discourse (a plugin, @webship.co/workspace-discourse): a forum is built with',
    '`bash cmd-discourse-project.sh <name> --install --add-users --sample-data` from a sites folder (dev, test, sandboxes, demos):',
    'the forum installed the official way, with the launcher of discourse_docker (its standalone template: PostgreSQL, Redis and the web server in one container),',
    'run as a service of a generic DDEV project, at https://<name>.ddev.site, its mail caught by the project\'s mail catcher (https://<name>.ddev.site:8026);',
    '`--install` makes the workspace account its admin, `--add-users` adds the default accounts (administrator, moderator, member at trust level 2, newuser at trust level 0),',
    '`--sample-data` the categories, tags, topics, replies and a message the step pack\'s features read; `--discourse-version` takes release (the default), esr, latest or a tag.',
    'A build takes about five minutes and 1.5 GB of memory at its peak; the forum then uses about 1 GB.',
    '`bash cmd-tools-discourse-rails.sh <name>` says what the forum is; `--rails "<command>"` and `--rake "<task>"` run the forum\'s own Rails and rake in its container,',
    '`--restart` starts the forum again, `--add-users` and `--cancel-users` manage the default accounts, `--sample-data` puts the sample data back.',
    'The row\'s Users menu does not apply to a forum (its project type is generic): use the Rails tool for the accounts.',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the Discourse step pack; `--run` runs the suite.',
    `For Discourse work, hand over to the agents ${AGENTS.map((a) => `\`${a}\``).join(' and ')}.`,
    `The plugin also places the skill ${SKILLS.map((a) => `\`${a}\``).join(', ')} (the step pack's phrases, by area) in ai-skills/,`,
    `the command ${AI_COMMANDS.map((a) => `\`/${a} <site>\``).join(', ')} in ai-commands/ and the prompts ${PROMPTS.map((a) => `\`${a}\``).join(' and ')} in ai-prompts/.`,
    'Never run the launcher, rails or rake on the host for a project; removing the project removes the forum\'s image and data volume too.',
  ].join(' ');
}

export function register(api: PluginApi): void {
  api.addAssistantContext(assistantContext);
}
