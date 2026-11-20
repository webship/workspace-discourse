import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUNCTIONS = path.join(PKG, 'scripts', 'functions', 'fun-discourse.sh');

// The cucumber.js webship-js scaffolds, as far as the testing hook reads it.
const SCAFFOLD = `module.exports = {
  default: {
    requireModule: ['tsx/cjs'],
    require: [
      'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.
      'tests/step-definitions/**/*.js',                                  // Your custom step definitions.
    ],
    paths: ['tests/features/**/*.feature'],
    worldParameters: {
      launchUrl: process.env.LAUNCH_URL || 'http://localhost:8080',
    },
  },
};
`;

/**
 * A project folder with the testing stack scaffolded, and the tooling folder the installer would have filled.
 * A forum of this plugin has the builder's .ddev/config.discourse.yaml.
 */
function project(kind: 'discourse' | 'drupal') {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'discourse-plugin-'));
  const dir = path.join(root, 'dev', 'site1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.ddev', 'config.yaml'), `name: site1\ntype: ${kind === 'discourse' ? 'generic' : 'drupal11'}\n`);
  if (kind === 'discourse') fs.writeFileSync(path.join(dir, '.ddev', 'config.discourse.yaml'), 'web_environment: []\n');
  fs.writeFileSync(path.join(dir, 'cucumber.js'), SCAFFOLD);
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'site1', devDependencies: { 'webship-js': '^2.0.6' } }, null, 2));
  const scripts = path.join(root, 'core', 'scripts');
  fs.mkdirSync(path.join(scripts, 'plugins', 'discourse'), { recursive: true });
  fs.copyFileSync(path.join(PKG, 'testing', 'site.feature'), path.join(scripts, 'plugins', 'discourse', 'site.feature'));
  fs.copyFileSync(path.join(PKG, 'scripts', 'discourse-site.rb'), path.join(scripts, 'plugins', 'discourse', 'discourse-site.rb'));
  return { root, dir, scripts };
}

/**
 * Run bash with the plugin's functions sourced and `ddev` replaced by a recorder of its calls and of what it
 * reads on stdin: the first line whole (`stdin1:`), then the start of the rest (`stdin:`).
 */
function bash(script: string, env: Record<string, string> = {}) {
  const fake = 'ddev() { echo "ddev $*" >> "${DDEV_LOG:-/dev/null}" ; if [ ! -t 0 ] ; then IFS= read -r first ; echo "  stdin1: ${first}" >> "${DDEV_LOG:-/dev/null}" ; head -c 120 | sed "s/^/  stdin: /" >> "${DDEV_LOG:-/dev/null}" ; echo >> "${DDEV_LOG:-/dev/null}" ; fi ; return 0 ; }';
  return spawnSync('bash', ['-c', `${fake}\nsource ${FUNCTIONS}\n${script}`], { encoding: 'utf8', env: { ...process.env, ...env } });
}

/**
 * The accounts a recorded call of discourse-site.rb carried: the base64 of their JSON object, on the first line of
 * its standard input, before the script, and never on its command line (a failed run prints that).
 */
function payloadOf(recorded: string) {
  const lines = recorded.split('\n');
  const call = lines.findIndex((l) => l.startsWith('ddev exec -s discourse DISCOURSE_SITE_VERBS='));
  assert.ok(call >= 0, `a call of the site script: ${recorded}`);
  assert.doesNotMatch(lines[call], /discourse_site_accounts/, 'no account on the command line');
  const m = (lines[call + 1] || '').match(/^  stdin1: \$discourse_site_accounts = '([A-Za-z0-9+\/=]+)'$/);
  assert.ok(m, `the first line of its input carries the accounts: ${lines[call + 1]}`);
  return JSON.parse(Buffer.from(m![1], 'base64').toString('utf8'));
}

test('the default accounts are an admin, a moderator, a member and a new user, with example addresses', () => {
  const r = bash('set_discourse_users ; for u in "${users[@]}" ; do n="user_${u}_name" ; m="user_${u}_mail" ; p="user_${u}_password" ; g="user_${u}_role" ; echo "${!n}|${!m}|${!p}|${!g}" ; done');
  assert.strictEqual(r.status, 0, r.stderr);
  const rows = r.stdout.trim().split('\n').map((l) => l.split('|'));
  assert.deepStrictEqual(rows.map((x) => x[0]), ['administrator', 'moderator', 'member', 'newuser']);
  assert.deepStrictEqual(rows.map((x) => x[3]), ['admin', 'moderator', 'member', 'newuser']);
  for (const [name, mail, password] of rows) {
    assert.strictEqual(mail, `${name}@example.com`);
    // The forum's rule: 10 characters or more (the build gives an admin the same rule).
    assert.ok(password.length >= 10, 'a password the forum accepts');
  }
});

test('the accounts are written by the site script with the forum\'s Rails, in its container, never in a file', () => {
  const p = project('discourse');
  const log = path.join(p.root, 'ddev.log');
  const env = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, account_name: 'owner1', account_mail: 'owner1@example.com', account_pass: 'Owner-pass-1234' };
  const r = bash('set_discourse_users ; add_discourse_users', env);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const written = fs.readFileSync(log, 'utf8');
  const call = written.split('\n').find((l) => l.startsWith('ddev exec -s discourse')) as string;
  assert.match(call, /DISCOURSE_SITE_VERBS='accounts' rails runner -$/);
  assert.match(written, /stdin: # frozen_string_literal: true/, 'the script goes in on stdin');
  const payload = payloadOf(written);
  assert.deepStrictEqual(payload.accounts.map((a: any) => [a.handle, a.username, a.email, a.role, a.trust_level]), [
    ['administrator', 'administrator', 'administrator@example.com', 'admin', 4],
    ['moderator', 'moderator', 'moderator@example.com', 'moderator', 2],
    ['member', 'member', 'member@example.com', 'member', 2],
    ['newuser', 'newuser', 'newuser@example.com', 'member', 0],
  ]);
  assert.strictEqual(payload.owner.email, 'owner1@example.com', 'the workspace account is the owner, never one of the list');
  assert.deepStrictEqual(fs.readdirSync(p.dir).filter((f) => !['.ddev', 'cucumber.js', 'package.json'].includes(f)), [], 'no file with a password is left in the project');
});

test('cancelling the accounts deletes the default ones through the site script', () => {
  const p = project('discourse');
  const log = path.join(p.root, 'ddev.log');
  const r = bash('set_discourse_users ; cancel_discourse_users', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, account_name: 'owner1', account_mail: 'owner1@example.com', account_pass: 'x' });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const recorded = fs.readFileSync(log, 'utf8');
  assert.ok(recorded.split('\n').find((l) => l.includes("DISCOURSE_SITE_VERBS='cancel'")), 'the cancel verb is called');
  assert.deepStrictEqual(payloadOf(recorded).accounts.map((a: any) => a.handle), ['administrator', 'moderator', 'member', 'newuser']);
});

test('the builder refuses a release it does not know, a bad name, and the options that need --install, before it changes anything', () => {
  const p = project('discourse');
  const log = path.join(p.root, 'ddev.log');
  const base = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', DDEV_LOG: log };
  const stub = 'trim_project_name() { :; } ; drop_database() { echo dropped ; } ;';
  const odd = bash(`PROJECT_NAME=site1 ; DISCOURSE_VERSION="beta" ; ${stub} discourse_build`, base);
  assert.strictEqual(odd.status, 1);
  assert.match(odd.stdout, /--discourse-version takes a channel \(release, esr, latest\) or a tag \(v2026\.10\.2\), not beta\. Nothing was changed\./);
  const users = bash(`PROJECT_NAME=site1 ; ADD_USERS=yes ; INSTALL=no ; ${stub} discourse_build`, base);
  assert.strictEqual(users.status, 1);
  assert.match(users.stdout, /--add-users needs --install/);
  const sample = bash(`PROJECT_NAME=site1 ; SAMPLE_DATA=yes ; INSTALL=no ; ${stub} discourse_build`, base);
  assert.strictEqual(sample.status, 1);
  assert.match(sample.stdout, /--sample-data needs --install/);
  const name = bash(`PROJECT_NAME=Site_1 ; ${stub} discourse_build`, base);
  assert.strictEqual(name.status, 1);
  assert.match(name.stdout, /must be small letters, digits and dashes/);
  for (const ok of ['release', 'esr', 'latest', 'v2026.10.2', 'v2026.11.0-latest.2']) {
    const r = bash(`PROJECT_NAME=site1 ; DISCOURSE_VERSION="${ok}" ; ADD_USERS=yes ; INSTALL=no ; ${stub} discourse_build`, base);
    assert.doesNotMatch(r.stdout, /--discourse-version takes/, `${ok} is a release the builder knows`);
  }
  assert.doesNotMatch(odd.stdout + users.stdout + sample.stdout + name.stdout, /dropped/, 'nothing was deleted');
  assert.ok(!fs.existsSync(log), 'the container tool was never called');
});

test('the builder writes the launcher\'s definition and the project\'s service: the image and the volume carry the project\'s label', () => {
  const p = project('discourse');
  const r = bash(`discourse_write_config ${p.dir} site1 release owner1@example.com`);
  assert.strictEqual(r.status, 0, r.stderr);
  const def = fs.readFileSync(path.join(p.dir, 'discourse_docker', 'containers', 'site1.yml'), 'utf8');
  assert.match(def, /templates\/postgres\.template\.yml[\s\S]*templates\/redis\.template\.yml[\s\S]*templates\/web\.template\.yml/);
  assert.doesNotMatch(def, /web\.ssl|letsencrypt|web\.ratelimited/, 'no certificate of its own and no rate limit of its web server');
  assert.match(def, /^expose: \[\]$/m, 'no port of the host');
  assert.match(def, /docker_args: "--label com\.docker\.compose\.project=ddev-site1"/);
  assert.match(def, /version: release/);
  assert.match(def, /DISCOURSE_HOSTNAME: "site1\.ddev\.site"/);
  assert.match(def, /DISCOURSE_DEVELOPER_EMAILS: "owner1@example\.com"/);
  assert.match(def, /DISCOURSE_SMTP_ADDRESS: web\n\s+DISCOURSE_SMTP_PORT: 1025/);
  assert.match(def, /host: ddev-site1-discourse-shared\n\s+guest: \/shared/);
  assert.strictEqual(fs.statSync(path.join(p.dir, 'discourse_docker', 'containers', 'site1.yml')).mode & 0o007, 0, 'the definition is not readable by others');
  const compose = fs.readFileSync(path.join(p.dir, '.ddev', 'docker-compose.discourse.yaml'), 'utf8');
  assert.match(compose, /image: local_discourse\/site1/);
  assert.match(compose, /command: \/sbin\/boot/);
  assert.match(compose, /HTTPS_EXPOSE=443:80/);
  assert.match(compose, /name: ddev-site1-discourse-shared/);
  assert.match(fs.readFileSync(path.join(p.dir, '.ddev', 'config.discourse.yaml'), 'utf8'), /DISCOURSE_VERSION=release/);
});

test('the testing hook adds the step pack, the users registry, the data admin, the tags and a first feature, once', () => {
  const p = project('discourse');
  const log = path.join(p.root, 'ddev.log');
  // The forum answers at once here: the wait for it is the recorder's.
  const run = () => bash(`discourse_wait() { echo "ddev wait" >> "${log}" ; } ; cd ${p.dir} && testing_configure_discourse ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, account_name: 'owner1', account_mail: 'owner1@example.com', account_pass: 'x' });
  const r = run();
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
  assert.strictEqual(pkg.devDependencies['@webship-js/discourse-steps'], '^2.0.0');
  assert.strictEqual(pkg.devDependencies['webship-js'], '^2.0.6', 'what was there stays');
  const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  const lines = cucumber.split('\n');
  const core = lines.findIndex((l) => l.includes('node_modules/webship-js/tests/step-definitions'));
  assert.strictEqual(lines[core + 1], "      'node_modules/@webship-js/discourse-steps/tests/step-definitions/**/*.js',", 'the pack is listed right after webship-js');
  assert.match(cucumber, /member: \{ username: process\.env\.DISCOURSE_MEMBER_USERNAME \|\| 'member', email: 'member@example\.com', password: process\.env\.DISCOURSE_MEMBER_PASSWORD \|\| '[^']+' \},/);
  assert.match(cucumber, /dataAdmin: process\.env\.DATA_ADMIN \|\| 'administrator',/);
  assert.match(cucumber, /tags: process\.env\.CUCUMBER_TAGS \|\| 'not @wip and not @must-fail',/);
  assert.match(cucumber, /Resident credentials or empty 'allowCredentials' lists are not supported\|net::ERR_NETWORK_CHANGED/);
  // The router serves the forum, so the web container has no address of its own: the suite gets the forum's.
  assert.match(cucumber, /launchUrl: process\.env\.LAUNCH_URL \|\| 'https:\/\/site1\.ddev\.site',/);
  // Still a module node can load, with the registry where webship-js reads it.
  const loaded = spawnSync(process.execPath, ['-e', `const c = require(${JSON.stringify(path.join(p.dir, 'cucumber.js'))}).default; console.log(JSON.stringify([c.require, Object.keys(c.worldParameters.users), c.tags, c.worldParameters.dataAdmin, c.worldParameters.users.newuser.username, c.worldParameters.javascript.mode]))`], { encoding: 'utf8', env: { ...process.env, CUCUMBER_TAGS: '' } });
  assert.strictEqual(loaded.status, 0, loaded.stderr);
  const [requires, handles, tags, admin, username, mode] = JSON.parse(loaded.stdout);
  assert.strictEqual(requires.length, 3);
  assert.deepStrictEqual(handles, ['administrator', 'moderator', 'member', 'newuser']);
  assert.match(tags, /not @must-fail/);
  assert.strictEqual(admin, 'administrator');
  assert.strictEqual(username, 'newuser');
  assert.strictEqual(mode, 'warn');
  assert.ok(fs.existsSync(path.join(p.dir, 'tests', 'features', 'site.feature')));
  assert.match(fs.readFileSync(log, 'utf8'), /^ddev wait\n[\s\S]*DISCOURSE_SITE_VERBS='accounts' rails runner -$/m, 'the forum gets the default accounts, once it answers');
  // Again, after a person changed the feature: nothing is doubled, nothing is reset.
  fs.writeFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'Feature: mine\n');
  assert.strictEqual(run().status, 0);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), cucumber);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'utf8'), 'Feature: mine\n');
});

test('the testing hook leaves a project of another platform alone', () => {
  const p = project('drupal');
  const r = bash(`cd ${p.dir} && testing_configure_discourse ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  assert.strictEqual(r.status, 0);
  assert.strictEqual(r.stdout, '');
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), SCAFFOLD);
  assert.ok(!fs.existsSync(path.join(p.dir, 'tests')));
});

test('the Rails tool refuses a project that is not a forum of the plugin', () => {
  const p = project('drupal');
  const r = bash('PROJECT_NAME=site1 ; RAILS="runner 1" ; trim_project_name() { :; } ; discourse_rails_tool', { WORKSPACE_ROOT: p.root, doc_name: 'dev' });
  assert.strictEqual(r.status, 1);
  assert.match(r.stdout, /is not a Discourse project of this plugin/);
});

test('the Rails tool runs a rails or a rake command in the forum\'s container', () => {
  const p = project('discourse');
  const log = path.join(p.root, 'ddev.log');
  const fake = `ddev() { case "$*" in describe*) echo '{"raw":{"status":"running"}}' ;; *) echo "ddev $*" >> "${log}" ;; esac ; }`;
  const rails = spawnSync('bash', ['-c', `source ${FUNCTIONS}\n${fake}\nPROJECT_NAME=site1 ; RAILS="runner 'puts 1'" ; RAKE=_none_ ; trim_project_name() { :; } ; discourse_rails_tool`], { encoding: 'utf8', env: { ...process.env, WORKSPACE_ROOT: p.root, doc_name: 'dev' } });
  assert.strictEqual(rails.status, 0, rails.stdout + rails.stderr);
  const rake = spawnSync('bash', ['-c', `source ${FUNCTIONS}\n${fake}\nPROJECT_NAME=site1 ; RAILS=_none_ ; RAKE="admin:create" ; trim_project_name() { :; } ; discourse_rails_tool`], { encoding: 'utf8', env: { ...process.env, WORKSPACE_ROOT: p.root, doc_name: 'dev' } });
  assert.strictEqual(rake.status, 0, rake.stdout + rake.stderr);
  const calls = fs.readFileSync(log, 'utf8');
  assert.match(calls, /^ddev exec -s discourse rails runner 'puts 1'$/m);
  assert.match(calls, /^ddev exec -s discourse rake admin:create$/m);
});

test('the first feature names no platform in a step, and no password', () => {
  const feature = fs.readFileSync(path.join(PKG, 'testing', 'site.feature'), 'utf8');
  const steps = feature.split('\n').filter((l) => /^\s*(Given|When|Then|And|But) /.test(l));
  assert.ok(steps.length >= 10);
  for (const s of steps) assert.doesNotMatch(s, /discourse|rails/i, s);
  assert.doesNotMatch(feature, /dD\.123123ddd/);
  assert.doesNotMatch(feature, /admin:create|Sign Up/i, 'a suite never creates an account');
});
