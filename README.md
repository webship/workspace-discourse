# @webship.co/workspace-discourse

Discourse for the [Webship Workspace](https://github.com/webship/workspace) dashboard: a builder that
makes a real Discourse forum in containers (installed the official way, with the launcher of
`discourse_docker`, and run as a service of the project, with its sample data on request), a tool for
the forum's own Rails and rake, the default accounts, the
[Discourse step pack](https://github.com/webship/discourse-steps) wired into the workspace's testing
setup, and its AI items — two agents, a skill, a command and two prompts — each listed in the
workspace folder of its kind.

The workspace is container-based (DDEV by default): a forum is a row like any other, so the row menus
the core draws (start, stop, launch, clone, remove, tests) work on it unchanged, but for its accounts:
a forum's row has no Users menu, and the test users items of its Tests menu are not for it. See
[The default accounts](#the-default-accounts).

It is made from the reference platform plugin, `@webship.co/workspace-wordpress`, and runs its forum
the way the Odoo plugin runs its server: a generic project, and the platform's own image as a service
of it.

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require @webship.co/workspace-discourse --with-needs   # npm install into the dashboard
bash core/scripts/plugins.sh --activate discourse --with-needs                         # plugins.discourse in settings.yml
bash core/scripts/plugins.sh --install discourse                                       # commands, functions, args, AI items
bash core/scripts/plugins.sh --configure discourse                                     # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is
idempotent. `--uninstall` removes what it placed; an AI item you edited stays.

Everything the plugin carries lands in the folder it belongs to, when that folder is an active
workspace folder:

| What | Lands in |
| --- | --- |
| `cmd-discourse-project.sh`, `cmd-tools-discourse-rails.sh` | every active sites folder: `dev/`, `test/`, `sandboxes/`, `demos/` |
| The agents `discourse-site-builder`, `discourse-tester` | `ai-agents/` |
| The skill `discourse-scenarios` | `ai-skills/` |
| The command `/discourse-test` | `ai-commands/` |
| The prompts `discourse-build-and-test`, `discourse-scenarios-for-an-area` | `ai-prompts/` |

There they are listed like any other item of the folder, and installed into Claude Code from there.

## What it needs

A workspace starts empty, so the manifest says what else this plugin needs (`needs`):

- one sites folder, for the builder and the tool: `dev`, `test`, `sandboxes`, `demos` (`dev` is the one added when none is there). The folder also carries `cmd-tools-testing.sh` and the Users tools this plugin's hooks answer to.
- `ai-agents`, `ai-skills`, `ai-commands` and `ai-prompts`: the AI folders its agents, its skill, its command and its prompts are placed in.

`--require` says so, `--activate` and `--install` stop until the workspace has them, and `--with-needs` adds what is missing first:

```bash
bash core/scripts/plugins.sh --activate discourse --with-needs   # dev and the four AI folders are required, activated and installed first
bash core/scripts/plugins.sh --install discourse
```

Everything the builder runs for a forum runs in containers, through the container tool the workspace
already needs, and git, which clones the launcher: the launcher's bootstrap, the forum's Rails and rake
are the forum's container's. The plugin asks for no command of its own on the machine.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-discourse-project.sh` | The builder, in the Build list as **Discourse (discourse_docker, a forum in a container)**, installed into every sites folder |
| `commands/cmd-tools-discourse-rails.sh` | The forum's Rails and rake for one forum: what the forum is, a rails command, a rake task, a restart, the default accounts, the sample data |
| `scripts/functions/fun-discourse.sh` | The bash functions behind both, sourced by bootstrap once installed; the names the core's tools look for (`set_discourse_users`, `add_discourse_users`, `cancel_discourse_users`, `testing_configure_discourse`) |
| `scripts/args/arg-discourse.sh`, `arg-discourse-rails.sh` | Their argparse; the Build form draws the builder's flags from the first |
| `scripts/discourse-site.rb` | Run by the forum's own Rails in its container: the settings of a test site, the workspace account as the admin, the default accounts, the sample data (the same script the step pack's test forum is built with) |
| `testing/site.feature` | The first feature a forum gets when testing is set up |
| `ai/agents/discourse-site-builder.md` | The agent that builds and maintains forums with these commands |
| `ai/agents/discourse-tester.md` | The agent that writes and runs scenarios with the Discourse step pack |
| `ai/skills/discourse-scenarios/` | The skill: the step pack's phrases by area, the traps found on a real forum, three example features |
| `ai/commands/discourse-test.md` | The slash command `/discourse-test <site>`: set up, match every step, run, report |
| `ai/prompts/discourse-build-and-test.md`, `discourse-scenarios-for-an-area.md` | Two prompts: whole launch commands for a new session |
| `src/index.ts` | `register(api)`: what the assistant is told about Discourse here |
| `features/discourse.feature` | Scenarios for the dashboard's own browser suite |

The `workspacePlugin` block in `package.json` is the manifest the installer reads.

## What is different from a PHP platform

Discourse is a Ruby on Rails app with PostgreSQL, Redis and background jobs, and DDEV has no project
type for it. Its only supported install is the launcher of `discourse_docker`. The plugin keeps the
shape of the reference and changes only this:

| | WordPress (the reference) | Discourse |
| --- | --- | --- |
| Project | `--project-type=wordpress`, nginx and PHP | `--project-type=generic --webserver-type=generic --omit-containers=db`: no web server and no database of the container tool's own; the web container carries the mail catcher and the Node.js of a test suite |
| Recognised by | The DDEV project type | The file `.ddev/config.discourse.yaml` |
| Getting the code | `wp core download` | `discourse_docker` cloned into the project (`discourse_docker/`), and a container definition written from its standalone sample (`discourse_docker/containers/<name>.yml`) |
| Install | `wp core install` | `./launcher bootstrap <name>`: the forum's image from the official base image, with PostgreSQL, Redis and the web server, the database migrated and the assets compiled; the project runs that image as a service (`.ddev/docker-compose.discourse.yaml`, `/sbin/boot`), the router sends the project's address to it |
| Database | The container tool's | The forum's own PostgreSQL, in its container, its data in a volume of the project (`ddev-<name>-discourse-shared`) |
| Mail | The container tool's mail catcher | The same: the forum sends to the web container's Mailpit (`web:1025`), read at `https://<name>.ddev.site:8026` |
| Admin | `wp core install --admin_user` | With `--install`, the workspace account, made with the forum's own task (`rake admin:create`) |
| Accounts | WP-CLI | `scripts/discourse-site.rb`, with the forum's own Rails (`rails runner`) |
| Removing it | `ddev delete` | The same: the forum's image and its volume carry the project's label, so `ddev delete` (and the row's Remove) removes them with the project |
| Users menu of the row | Reads the project type | None (the type is `generic`; the Tests menu's test users items hand it the Webship list): the Rails tool's `--add-users`, or `cmd-tools-add-users.sh <name> discourse` |

No public domain, no certificate of the forum's own, no hosted service and no account anywhere: the
forum answers at `https://<name>.ddev.site` through the container tool's router.

## The commands

Run them from a sites folder. `--help` is safe on both.

### Build a forum

```bash
cd ~/workspace/dev
bash cmd-discourse-project.sh myforum --install --add-users --sample-data
```

| Flag | What it does |
| --- | --- |
| `--install` | Make the workspace account the forum's admin (its password needs 10 characters or more and must not be a common one: the forum's rule) |
| `--add-users` | With `--install`: add the default accounts |
| `--sample-data` | With `--install`: the categories Announcements, Support (with its subcategory Installation) and Off-topic, the tags howto, question, release-notes and backups, seven topics with their replies and likes, and a personal message to the member |
| `--discourse-version <x>` | The release: `release` (the current monthly release, the default), `esr` (the extended support release), `latest`, or a tag such as `v2026.10.2` |
| `--launch` | Open the forum when it is ready |

The forum answers at `https://myforum.ddev.site`; its mail is caught at
`https://myforum.ddev.site:8026`. The settings of a test site are written with `--install`: the title,
no setup wizard, https links, no tips over a first visit, an admin's password of 10 characters or more,
tags on, and the limits one test run meets because it comes from one address (logins, posts and
actions per minute and per day); every limit a person meets stays. A project of the same name is
deleted first, with its forum's container, image and volume.

A build takes about five minutes the first time (the base image is about 1.3 GB; a release of the
forum comes with its assets built) and about 1.5 GB of memory at its peak; the forum then uses about
1 GB. Check the free memory first (`free -g`), and build one forum at a time on a machine others use.

### Work on a forum

```bash
bash cmd-tools-discourse-rails.sh myforum                                   # version, state, accounts
bash cmd-tools-discourse-rails.sh myforum --rails "runner 'puts Topic.count'"
bash cmd-tools-discourse-rails.sh myforum --rake "admin:create"             # the forum's own tasks
bash cmd-tools-discourse-rails.sh myforum --restart                         # start the forum again and wait for it
bash cmd-tools-discourse-rails.sh myforum --add-users                       # the default accounts
bash cmd-tools-discourse-rails.sh myforum --cancel-users                    # delete them and their posts
bash cmd-tools-discourse-rails.sh myforum --sample-data                     # make again what is missing of the sample data
```

The forum's database is its own (PostgreSQL in its container, its data in the project's volume), not
the container tool's: the workspace's database backup does not hold it. The forum's own backups
(Admin, Backups) do.

### The default accounts

| Account | Address | Role | Handle in the tests |
| --- | --- | --- | --- |
| `administrator` | `administrator@example.com` | admin | `administrator` |
| `moderator` | `moderator@example.com` | moderator, trust level 2 | `moderator` |
| `member` | `member@example.com` | trust level 2 ("member") | `member` |
| `newuser` | `newuser@example.com` | trust level 0 ("new user"), for the refusals | `newuser` |

The forum logs in with the username. Each account has the password of the workspace's other default
lists. Their trust levels are locked, so reading in a suite never promotes `newuser`. They are for
local forums and for tests; the forum's admin from `--install` is the workspace account and is never
written into a test.

**Manage them with the Rails tool, not the dashboard's menus.** The dashboard picks a project's
account list by its type, and a forum's type is `generic`: its row has no Users menu, and the
"Add the test users" and "Cancel the test users" items of its Tests menu hand it the list of the
Webship distribution, which starts by adding Drush to the project with Composer. Leave those two items
alone on a forum until the base asks the plugins which list a project takes (webship/workspace#490).
Use:

```bash
bash cmd-tools-discourse-rails.sh myforum --add-users      # add them, or give them back their email, password, role and trust level
bash cmd-tools-discourse-rails.sh myforum --cancel-users   # delete them and their posts
bash cmd-tools-add-users.sh myforum discourse              # the core's tool: the same list
bash cmd-tools-cancel-users.sh myforum discourse
```

### Test a forum

```bash
bash cmd-tools-testing.sh myforum                 # webship-js, the step pack, the users registry, a first feature
bash cmd-tools-testing.sh myforum --run           # run the suite in the container
bash cmd-tools-testing.sh myforum --run --path tests/features/site.feature
```

`cmd-tools-testing.sh` is the workspace's own. For a forum it also adds `@webship-js/discourse-steps`
to `package.json`, lists its step definitions in `cucumber.js` after webship-js's own, writes the users
registry (the handles above, by their usernames, overridable with `DISCOURSE_<HANDLE>_USERNAME` and
`DISCOURSE_<HANDLE>_PASSWORD`), `dataAdmin` (the handle the step pack makes and deletes its test topics
as), the browser messages that are no error of the forum, and the tags that keep the pack's assertions
that must fail out of a normal run, places `tests/features/site.feature` when the project has none, and
makes sure the default accounts are in the forum. Run it again and it adds what is missing and keeps
what you changed.

The suite runs in the project's container, where the network changes of the host (another container
starting) do not cut the browser's requests.

A scenario of your own reads like this one, from the step pack's phrases (the skill
`discourse-scenarios` lists them by area); the topics and replies it makes are deleted after it:

```gherkin
Feature: The member answers a question
  Scenario: A reply to the moderator's topic
    Given there is a topic "A question the readme asks" in "Support" by "moderator"
    And I am a logged in user with the "member" user
    When I open the topic "A question the readme asks"
    And I reply to the topic with "An answer written by the suite for this scenario."
    Then the topic should have 2 posts
    And the last post should be by "member"
```

`tests/features/site.feature` passes on a forum built with `--install --add-users`. The features of the
step pack, and the scenario above, pass on a forum built with `--install --add-users --sample-data`.

## The AI items

`ai/` in the package holds one folder per kind, the manifest's `ai` block names each item, and
`--install` places it in the workspace folder of that kind.

| Kind | Item | Use it to |
| --- | --- | --- |
| Agent | `discourse-site-builder` | Build, maintain or remove a forum with the commands above, in containers only |
| Agent | `discourse-tester` | Set the testing stack up, look at the forum in the Playwright MCP browser first, write scenarios from the pack's steps and run them; it never creates an account in a suite and never writes a platform name into a step phrase |
| Skill | `discourse-scenarios` | Write a scenario from phrases that exist: the pack's steps by area, the handles of the users registry, the test topics, the traps found on a real forum, and three features that pass on a forum with the sample data |
| Command | `/discourse-test <site> [feature or @tag]` | Run the suite of a forum from inside a session: set up when missing, match every step, run, report what failed and why |
| Prompt | `discourse-build-and-test` | Start a session that builds a forum, says what it is, sets the testing stack up and runs the first feature |
| Prompt | `discourse-scenarios-for-an-area` | Start a session that writes and runs the scenarios of one area of the forum |

After `--install` each is in its folder on the dashboard. **Install** there puts an agent, a skill
or a command into Claude Code (`~/.claude/agents`, `~/.claude/skills`, `~/.claude/commands`), or
from the command line:

```bash
cd ~/workspace/ai-agents   && bash cmd-tools-ai-items.sh discourse-tester --install
cd ~/workspace/ai-skills   && bash cmd-tools-ai-items.sh discourse-scenarios --install
cd ~/workspace/ai-commands && bash cmd-tools-ai-items.sh discourse-test --install
```

A prompt is not installed: it is the whole `claude …` launch command of a new session, and the
dashboard's **New screen** form lists it as a template. By hand, fill the placeholders in and run
the command of the file from the folder it names.

The items are written for any AI CLI, with Claude Code as the default shape: the frontmatter and
the file layout are Claude Code's, the body of each item is plain Markdown that names no tool or
feature of one CLI, a command says in words what its arguments are, and the text between the
triple quotes of a prompt can be given to another AI CLI as it is.

Every step phrase the items show is checked against the definitions of the step pack and of
webship-js (`tests/fixtures/step-definitions.txt`), and every command and flag against the
plugin's own.

## Develop it

```bash
npm install     # builds dist/ (TypeScript)
npm run lint
npm test        # the manifest, the commands, the AI items, the functions against a scaffolded project
```

CI runs the same on Node.js 20 and 24, parses every shell script, and runs the plugin's
`features/discourse.feature` against a dashboard with this plugin installed
(`webship/workspace/.github/workflows/plugin-browser-suite.yml`).
