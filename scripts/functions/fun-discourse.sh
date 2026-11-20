#!/usr/bin/env bash

# Discourse for the Webship Workspace: build a forum, run its Rails and rake, add its default accounts,
# and wire its step pack into the testing setup.
#
# Placed by `plugins.sh --install discourse` in core/scripts/plugins/discourse/functions/, where
# bootstrap sources it after the core's own functions. Everything runs in containers (DDEV by default),
# never on the host: the forum is installed the official way, with the launcher of discourse_docker
# (its standalone template: PostgreSQL, Redis and the web server in one container), and runs as a
# service of the project; the router serves it at the project's address; the project's web container
# serves nothing of its own and carries the mail catcher the forum sends its mail to. The forum's image
# and its data volume carry the project's label, so removing the project removes them too. No public
# domain, no certificate of its own, no hosted service and no account anywhere.
#
# DDEV has no project type for Discourse, so a forum of this plugin is recognised by a file
# (.ddev/config.discourse.yaml, written by the builder), and four names are the ones the core's tools
# look for:
#   set_discourse_users          the default accounts                (cmd-tools-add-users.sh <project> discourse)
#   add_discourse_users          create them with the forum's Rails  (the same tool, and --add-users of the builder)
#   cancel_discourse_users       delete them                         (cmd-tools-cancel-users.sh <project> discourse)
#   testing_configure_discourse  the step pack in the testing stack  (cmd-tools-testing.sh <project>)

# The step pack a Discourse forum is tested with, and the release line it is required at.
readonly DISCOURSE_STEPS_PACKAGE='@webship-js/discourse-steps';
readonly DISCOURSE_STEPS_VERSION='^2.0.0';

# The launcher's repository, and the release the builder installs when none is asked for: the current
# monthly release (a channel of the forum: release, esr or latest; or a tag such as v2026.10.2).
readonly DISCOURSE_DOCKER_REPOSITORY='https://github.com/discourse/discourse_docker.git';
readonly DISCOURSE_DEFAULT_VERSION='release';

# The default accounts, the ones a scenario logs in as: an admin, a moderator, a member (trust level 2)
# and a new user (trust level 0, for the refusals). Accounts are configuration, created once on the
# forum; a test suite never creates or deletes one. The admin the builder creates with --install is the
# workspace account and is not in this list.
function set_discourse_users() {
  users=(administrator moderator member newuser);
  local user ;
  for user in "${users[@]}" ; do
    printf -v "user_${user}_name" '%s' "${user}" ;
    printf -v "user_${user}_mail" '%s' "${user}@example.com" ;
    printf -v "user_${user}_password" '%s' 'dD.123123ddd' ;
  done
  user_administrator_role='admin' ;
  user_moderator_role='moderator' ;
  user_member_role='member' ;
  user_newuser_role='newuser' ;
}

# Is this folder a Discourse forum of this plugin? The builder leaves .ddev/config.discourse.yaml in it.
function discourse_is_project() {
  local project_path="$1";
  [ -f "${project_path}/.ddev/config.discourse.yaml" ] ;
}

# Go to the project a tool was asked about, or say why not.
function discourse_enter_project() {
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}";
  if [ ! -d "${project_path}" ] ; then
    echo "No project ${PROJECT_NAME} in ${WORKSPACE_ROOT}/${doc_name}." ;
    return 1 ;
  fi
  if ! discourse_is_project "${project_path}" ; then
    echo "${doc_name}/${PROJECT_NAME} is not a Discourse project of this plugin (it has no .ddev/config.discourse.yaml)." ;
    return 1 ;
  fi
  cd "${project_path}" || return 1 ;
}

# The names the forum's image and data volume take: the launcher names the image local_discourse/<container>.
function discourse_image() { echo "local_discourse/$1" ; }
function discourse_volume() { echo "ddev-$1-discourse-shared" ; }

# What the container tool and the launcher are told about the forum: the launcher's container definition
# (the standalone template without the host's ports, without the rate limits of its web server, without
# the upgrade plugin), and the project's service that runs the image the launcher bootstraps.
function discourse_write_config() {
  local project_path="$1" name="$2" version="$3" developer_mail="$4" ;
  local host="${name}.ddev.site" image volume ;
  image="$(discourse_image "${name}")" ;
  volume="$(discourse_volume "${name}")" ;
  mkdir -p "${project_path}/.ddev" "${project_path}/discourse_docker/containers" || return 1 ;
  cat > "${project_path}/discourse_docker/containers/${name}.yml" <<YAMLEOF
## The forum of the DDEV project ${name}. Written by the Discourse builder of the workspace; build again
## rather than editing by hand.
templates:
  - "templates/postgres.template.yml"
  - "templates/redis.template.yml"
  - "templates/web.template.yml"

expose: []

docker_args: "--label com.docker.compose.project=ddev-${name}"

params:
  db_default_text_search_config: "pg_catalog.english"
  db_shared_buffers: "256MB"
  version: ${version}

env:
  LC_ALL: en_US.UTF-8
  LANG: en_US.UTF-8
  LANGUAGE: en_US.UTF-8
  UNICORN_WORKERS: 2
  DISCOURSE_HOSTNAME: "${host}"
  DISCOURSE_DEVELOPER_EMAILS: "${developer_mail}"
  DISCOURSE_SMTP_ADDRESS: web
  DISCOURSE_SMTP_PORT: 1025
  DISCOURSE_SMTP_ENABLE_START_TLS: false
  DISCOURSE_NOTIFICATION_EMAIL: noreply@example.com
  DISCOURSE_MAX_REQS_PER_IP_MODE: none

volumes:
  - volume:
      host: ${volume}
      guest: /shared
YAMLEOF
  chmod o-rwx "${project_path}/discourse_docker/containers/${name}.yml" ;
  cat > "${project_path}/.ddev/config.discourse.yaml" <<YAMLEOF
# Discourse in this project: a service of its own (docker-compose.discourse.yaml). Written by the
# Discourse builder of the workspace; build again rather than editing by hand.
web_environment:
  - DISCOURSE_VERSION=${version}
YAMLEOF
  cat > "${project_path}/.ddev/docker-compose.discourse.yaml" <<YAMLEOF
## The forum, as a service of this project: the image discourse_docker's launcher bootstrapped
## (${image}), started the way the launcher starts it (/sbin/boot), its data in the project's volume.
## The router sends the project's address to its web server. Written by the Discourse builder of the
## workspace; build again rather than editing by hand.
services:
  discourse:
    container_name: ddev-\${DDEV_SITENAME}-discourse
    image: ${image}
    restart: "no"
    command: /sbin/boot
    shm_size: 512m
    labels:
      com.ddev.site-name: \${DDEV_SITENAME}
      com.ddev.approot: \${DDEV_APPROOT}
    environment:
      - VIRTUAL_HOST=\$DDEV_HOSTNAME
      - HTTP_EXPOSE=80:80
      - HTTPS_EXPOSE=443:80
      - DISCOURSE_HOSTNAME=${host}
      - DISCOURSE_SMTP_ADDRESS=web
      - DISCOURSE_SMTP_PORT=1025
      - DISCOURSE_SMTP_ENABLE_START_TLS=false
    expose:
      - "80"
    volumes:
      - discourse-shared:/shared
volumes:
  discourse-shared:
    name: ${volume}
YAMLEOF
}

# Wait until the forum answers its health check (/srv/status) in its container.
function discourse_wait() {
  local attempt status ;
  for attempt in $(seq 1 150) ; do
    status="$(ddev exec -s discourse "curl -s http://127.0.0.1/srv/status" < /dev/null 2>/dev/null | tr -d '\r')" ;
    [ "${status}" == 'ok' ] && return 0 ;
    sleep 2 ;
  done
  echo "The forum did not start; the end of its log:" ;
  ddev logs -s discourse --tail 60 < /dev/null 2>/dev/null ;
  return 1 ;
}

# The forum's rails and rake, in its container (their own wrappers run them as the forum's user).
function discourse_rails() {
  ddev exec -s discourse "rails $*" < /dev/null ;
}
function discourse_rake() {
  ddev exec -s discourse "rake $*" < /dev/null ;
}

# The release the forum runs.
function discourse_version() {
  ddev exec -s discourse "sudo -u discourse git -C /var/www/discourse describe --tags" < /dev/null 2>/dev/null | tr -d '\r' | tail -n 1 ;
}

# Run verbs of discourse-site.rb (settings, accounts, cancel, list, seed) with the forum's Rails, in its
# container. The script goes in on the standard input, and the accounts travel as base64 of a JSON object
# on its first line, so no password is written into a file of the project and no quoting can break a value.
function discourse_site() {
  local script="${WORKSPACE_SCRIPTS}/plugins/discourse/discourse-site.rb" rows="" user name mail password role payload ;
  if [ ! -f "${script}" ] ; then
    echo "discourse-site.rb is not in ${WORKSPACE_SCRIPTS}/plugins/discourse: install the plugin (plugins.sh --install discourse)." ;
    return 1 ;
  fi
  for user in "${users[@]}" ; do
    name="user_${user}_name"; mail="user_${user}_mail"; password="user_${user}_password"; role="user_${user}_role";
    rows="${rows}${!name}"$'\x1f'"${!mail}"$'\x1f'"${!password}"$'\x1f'"${!role}"$'\x1e' ;
  done
  payload="$(DISCOURSE_OWNER_NAME="${account_name}" DISCOURSE_OWNER_MAIL="${account_mail}" DISCOURSE_OWNER_PASS="${account_pass}" \
    DISCOURSE_ROWS="${rows}" python3 -c '
import base64, json, os
levels = {"admin": 4, "moderator": 2, "member": 2, "newuser": 0}
roles = {"admin": "admin", "moderator": "moderator", "member": "member", "newuser": "member"}
def account(row):
    handle, email, password, role = row.split("\x1f")
    return {"handle": handle, "username": handle, "name": handle.capitalize() + " Webship", "email": email, "password": password, "role": roles.get(role, "member"), "trust_level": levels.get(role, 1)}
accounts = [account(row) for row in os.environ["DISCOURSE_ROWS"].split("\x1e") if row]
owner = {"handle": "owner", "username": os.environ["DISCOURSE_OWNER_NAME"], "name": os.environ["DISCOURSE_OWNER_NAME"], "email": os.environ["DISCOURSE_OWNER_MAIL"], "password": os.environ["DISCOURSE_OWNER_PASS"], "role": "admin", "trust_level": 4}
print(base64.b64encode(json.dumps({"owner": owner, "accounts": accounts}).encode()).decode())')" || return 1 ;
  { printf "\$discourse_site_accounts = '%s'\n" "${payload}"; cat "${script}"; } \
    | ddev exec -s discourse "DISCOURSE_SITE_VERBS='$*' rails runner -" ;
}

# Make the workspace account the forum's admin: the forum's own task (rake admin:create), with a random
# password it sets, then the account's own password, username and name with the site script.
function discourse_owner() {
  local requirement ;
  requirement="$(ddev exec -s discourse "rails runner 'print SiteSetting.full_name_requirement'" < /dev/null 2>/dev/null | tr -d '\r' | tail -n 1)" ;
  if [ "${requirement}" == 'required_at_signup' ] ; then
    printf '%s\n%s\nY\n' "${account_mail}" "${account_name}" | ddev exec -s discourse "RANDOM_PASSWORD=1 rake admin:create" > /dev/null || return 1 ;
  else
    printf '%s\nY\n' "${account_mail}" | ddev exec -s discourse "RANDOM_PASSWORD=1 rake admin:create" > /dev/null || return 1 ;
  fi
  users=() ;
  discourse_site owner ;
}

# Build a Discourse forum from nothing: the project, the launcher's bootstrap of the forum's image, the
# service started, and with --install its admin (the workspace account), with --add-users the default
# accounts, with --sample-data the sample data.
function discourse_build() {
  trim_project_name ;
  local base_url="https://${PROJECT_NAME}.ddev.site" ;
  local version="${DISCOURSE_VERSION:-${site_discourse_version:-${DISCOURSE_DEFAULT_VERSION}}}" ;
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}" ;

  if ! [[ "${version}" =~ ^(release|esr|latest|v[0-9]{4}\.[0-9]+\.[0-9]+(-latest(\.[0-9]+)?)?)$ ]] ; then
    echo "--discourse-version takes a channel (release, esr, latest) or a tag (v2026.10.2), not ${version}. Nothing was changed." ;
    exit 1 ;
  fi
  if [ "${ADD_USERS}" == 'yes' ] && [ "${INSTALL}" != 'yes' ] ; then
    echo "--add-users needs --install: the default accounts are added once the forum has its admin, the workspace account." ;
    exit 1 ;
  fi
  if [ "${SAMPLE_DATA}" == 'yes' ] && [ "${INSTALL}" != 'yes' ] ; then
    echo "--sample-data needs --install: the sample data is written by the forum's admin, the workspace account." ;
    exit 1 ;
  fi
  if [ ${#PROJECT_NAME} -gt 40 ] || ! [[ "${PROJECT_NAME}" =~ ^[a-z0-9][a-z0-9-]*$ ]] ; then
    echo "The project name ${PROJECT_NAME} must be small letters, digits and dashes (the forum's container and image take it). Nothing was changed." ;
    exit 1 ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name} || exit 1 ;

  # A project of the same name goes first, with its forum's container, image and volume (they carry
  # the project's label, so the container tool removes them with it).
  drop_database ;
  rm -rf "${PROJECT_NAME}" ;
  mkdir -p "${PROJECT_NAME}" ;
  cd "${project_path}" || exit 1 ;

  # A generic project: no web server and no database of the container tool's own (the forum has its
  # PostgreSQL and its Redis in its container), the Node.js of the workspace for a test suite.
  ddev config --project-type=generic --webserver-type=generic --docroot="" --project-name=${PROJECT_NAME} \
    --omit-containers=db --nodejs-version=$(ddev_nodejs_version) || exit 1 ;

  echo "Getting discourse_docker, the forum's official launcher." ;
  git clone --quiet --depth 1 "${DISCOURSE_DOCKER_REPOSITORY}" discourse_docker || { echo "discourse_docker could not be cloned." ; exit 1 ; } ;
  discourse_write_config "${project_path}" "${PROJECT_NAME}" "${version}" "${account_mail}" || exit 1 ;

  local volume image ;
  volume="$(discourse_volume "${PROJECT_NAME}")" ;
  image="$(discourse_image "${PROJECT_NAME}")" ;
  docker volume rm "${volume}" > /dev/null 2>&1 ;
  docker volume create --label "com.docker.compose.project=ddev-${PROJECT_NAME}" --label "com.docker.compose.volume=discourse-shared" "${volume}" > /dev/null || exit 1 ;
  docker image rm "${image}" > /dev/null 2>&1 ;

  echo "Bootstrapping the forum's image (${version}) with the launcher: the code, its packages, the database and the assets. A few minutes; about 1.5 GB of memory." ;
  ( cd discourse_docker && ./launcher bootstrap "${PROJECT_NAME}" < /dev/null ) || { echo "The launcher's bootstrap failed (its log is above)." ; exit 1 ; } ;

  ddev_up start -y || exit 1 ;
  discourse_wait || exit 1 ;

  if [ "${INSTALL}" == 'yes' ] ; then
    users=() ;
    discourse_site settings || exit 1 ;
    echo "Making the workspace account the forum's admin (rake admin:create)." ;
    discourse_owner || { echo "The forum's admin could not be created (the forum asks a password of 10 characters or more that is not a common one)." ; exit 1 ; } ;
    local verbs="" ;
    if [ "${ADD_USERS}" == 'yes' ] ; then
      set_discourse_users ;
      verbs="accounts" ;
    fi
    if [ "${SAMPLE_DATA}" == 'yes' ] ; then
      verbs="${verbs} seed" ;
    fi
    if [ -n "${verbs}" ] ; then
      discourse_site ${verbs} || exit 1 ;
    fi
    users=() ;

    echo "${doc_name} ${PROJECT_NAME} has been installed: Discourse $(discourse_version).";
    echo "Go to ${base_url}/login and log in as ${account_name} (${account_mail}); its mail is caught at ${base_url}:8026";
  else
    echo "${doc_name} ${PROJECT_NAME} is ready, without an admin: Discourse $(discourse_version).";
    echo "Sign up at ${base_url} with ${account_mail} (the forum makes that address its admin), or: bash cmd-tools-discourse-rails.sh ${PROJECT_NAME} --rake admin:create";
  fi

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch "${base_url}" ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Create the default accounts with the forum's Rails. An account that is already there gets its email,
# name, password, role and trust level back. The list is loaded by the caller (set_discourse_users):
# the core's add_users, the builder, the tool.
function add_discourse_users() {
  discourse_enter_project || return 1 ;
  local user user_name user_mail user_password user_role ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    user_password="user_${user}_password"; user_role="user_${user}_role";

    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo "  User password: ${!user_password}";
    echo "      User role: ${!user_role}";
    echo " ================================================================= ";
  done
  discourse_site accounts ;
  local status=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# Delete the default accounts and their posts (never the workspace account).
function cancel_discourse_users() {
  discourse_enter_project || return 1 ;
  local user user_name ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo " ================================================================= ";
  done
  discourse_site cancel ;
  local status=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# What cmd-tools-discourse-rails.sh does: the first of --rails, --rake, --restart, --add-users,
# --cancel-users, --sample-data that was asked for; with none of them, what the forum is.
function discourse_rails_tool() {
  trim_project_name ;
  discourse_enter_project || exit 1 ;

  if ! ddev describe -j 2>/dev/null | grep -q '"status":"running"' ; then
    ddev start -y < /dev/null || exit 1 ;
    discourse_wait || exit 1 ;
  fi

  if [ ! "${RAILS}" == '_none_' ] ; then
    discourse_rails "${RAILS}" ;
    exit $? ;
  fi
  if [ ! "${RAKE}" == '_none_' ] ; then
    discourse_rake "${RAKE}" ;
    exit $? ;
  fi

  if [ "${RESTART}" == 'yes' ] ; then
    docker restart "ddev-${PROJECT_NAME}-discourse" > /dev/null || exit 1 ;
    discourse_wait || exit 1 ;
    echo "Discourse $(discourse_version) is running at https://${PROJECT_NAME}.ddev.site" ;
  elif [ "${ADD_USERS}" == 'yes' ] ; then
    set_discourse_users ;
    add_discourse_users ;
  elif [ "${CANCEL_USERS}" == 'yes' ] ; then
    set_discourse_users ;
    cancel_discourse_users ;
  elif [ "${SAMPLE_DATA}" == 'yes' ] ; then
    users=() ;
    discourse_site seed ;
  else
    echo "${doc_name}/${PROJECT_NAME}: Discourse $(discourse_version) at https://${PROJECT_NAME}.ddev.site (mail: https://${PROJECT_NAME}.ddev.site:8026)" ;
    echo "" ;
    if [ "$(ddev exec -s discourse "curl -s http://127.0.0.1/srv/status" < /dev/null 2>/dev/null | tr -d '\r')" == 'ok' ] ; then
      echo "Forum: running" ;
    else
      echo "Forum: not answering; start it again with --restart" ;
    fi
    echo "" ; echo "Accounts:" ;
    set_discourse_users ;
    discourse_site list ;
  fi
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# The step pack in the testing stack of a Discourse forum. The core's testing_configure calls this in the
# project folder once webship-js is scaffolded and before the dependencies are installed; for a project
# that is not one of this plugin's it changes nothing.
#
# It adds the pack to package.json, lists its step definitions in cucumber.js after webship-js's own,
# gives cucumber.js the tags that keep the pack's assertions that must fail out of a normal run, the
# handle the test-data steps work as (dataAdmin), the browser messages that are no error of the forum,
# and the users registry of the default accounts (a handle a scenario reads, mapped to an account; never
# the workspace account), and writes a first feature when the project has none of its own. Every part is
# skipped when it is already there, so a second run adds what the first missed and never resets a suite.
function testing_configure_discourse() {
  local project_path="$1";
  discourse_is_project "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  Discourse: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi

  echo "Adding the Discourse step pack (${DISCOURSE_STEPS_PACKAGE} ${DISCOURSE_STEPS_VERSION}).";
  set_discourse_users ;
  local registry="" user user_name user_mail user_password ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail"; user_password="user_${user}_password";
    registry="${registry}${user}|${!user_name}|${!user_mail}|${!user_password}"$'\n' ;
  done

  python3 - "${project_path}" "${DISCOURSE_STEPS_PACKAGE}" "${DISCOURSE_STEPS_VERSION}" 'DISCOURSE' "${registry}" <<'PYEOF' || return 1
import json, re, sys

project, pack, version, prefix, registry = sys.argv[1:6]

# package.json: the pack as a dev dependency, at the release line this plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
if pack not in pkg.get('dependencies', {}) and pack not in pkg.get('devDependencies', {}):
    pkg.setdefault('devDependencies', {})[pack] = version
    open(pkg_file, 'w').write(json.dumps(pkg, indent=4) + '\n')
    print('  package.json: %s %s' % (pack, version))

# cucumber.js: the pack's step definitions after webship-js's own, the tags of the pack's lane, and in
# worldParameters the test-data account, the browser messages to ignore and the users registry.
cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/**/*.js'," % pack
    core = re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if core:
        src = src[:core.end()] + '\n' + core.group(1) + line + src[core.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

if not re.search(r"^[ \t]*tags:", src, re.M):
    default = re.search(r"^([ \t]*)default:[ \t]*\{[ \t]*$", src, re.M)
    if default:
        pad = default.group(1) + '  '
        block = [
            pad + "// The pack's assertions that must fail are no part of a normal run.",
            pad + "tags: process.env.CUCUMBER_TAGS || 'not @wip and not @must-fail',",
        ]
        src = src[:default.end()] + '\n' + '\n'.join(block) + src[default.end():]
        print('  cucumber.js: the tags that keep the assertions that must fail out of a normal run')

world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
if not world:
    sys.exit("  cucumber.js has no worldParameters block to add the users registry to.")
pad = world.group(1) + '  '
additions = []
if not re.search(r"^[ \t]*dataAdmin:", src, re.M):
    additions += [
        pad + "// The account the test-data steps make and delete the test topics, replies and messages as: an admin of `users`.",
        pad + "dataAdmin: process.env.DATA_ADMIN || 'administrator',",
    ]
if not re.search(r"^[ \t]*javascript:", src, re.M):
    additions += [
        pad + "// Browser messages that are no error of the forum: the passkey the login page asks a headless browser for,",
        pad + "// and a request lost when the network of the machine changed.",
        pad + "javascript: { mode: process.env.WEBSHIP_JS_ERROR_MODE || 'warn', levels: ['error'], ignore: \"Resident credentials or empty 'allowCredentials' lists are not supported|net::ERR_NETWORK_CHANGED\", beforeScenario: false, afterScenario: true },",
    ]
if not re.search(r"^[ \t]*users:[ \t]*\{", src, re.M):
    rows = [r.split('|') for r in registry.splitlines() if r.strip()]
    additions += [
        pad + "// The users registry: a handle a scenario reads, mapped to an account of this forum (the default",
        pad + "// accounts: cmd-tools-discourse-rails.sh --add-users). The forum logs in with the username. Override",
        pad + "// one with %s_<HANDLE>_USERNAME and %s_<HANDLE>_PASSWORD." % (prefix, prefix),
        pad + "users: {",
    ]
    for handle, username, email, password in rows:
        env = '%s_%s' % (prefix, handle.upper())
        additions.append(pad + "  %s: { username: process.env.%s_USERNAME || '%s', email: '%s', password: process.env.%s_PASSWORD || '%s' }," % (handle, env, username, email, env, password))
    additions.append(pad + "},")
    print('  cucumber.js: the users registry (%s)' % ', '.join(r[0] for r in rows))
if additions:
    src = src[:world.end()] + '\n' + '\n'.join(additions) + src[world.end():]

if src != before:
    open(cucumber_file, 'w').write(src)
PYEOF

  # A first feature, when the project has none for the forum yet: the login page, each default account,
  # a refused login, a topic read, and what a member may not open.
  local feature="${WORKSPACE_SCRIPTS}/plugins/discourse/site.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/site.feature" ] ; then
    mkdir -p "${project_path}/tests/features" && cp "${feature}" "${project_path}/tests/features/site.feature" \
      && echo "  tests/features/site.feature: a first feature for the forum" ;
  fi

  # The scenarios log in as the default accounts: make sure a forum that has its admin has them.
  if ( add_discourse_users > /dev/null 2>&1 ) ; then
    echo "  the default accounts are in the forum (${users[*]})" ;
  else
    echo "  The default accounts could not be written: is the forum running (ddev start in ${project_path})?" ;
  fi
}
