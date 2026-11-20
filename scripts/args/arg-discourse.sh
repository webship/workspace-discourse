#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: its folder, its DDEV project and its host name.')
parser.add_argument('-i', '--install',
                    action='store_true',
                    default=False,
                    help='Give the forum its admin: the workspace account.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='With --install, add the default accounts (administrator, moderator, member, newuser): the ones the test scenarios log in as.')
parser.add_argument('-s', '--sample-data',
                    action='store_true',
                    default=False,
                    help='With --install, add the sample data: the categories Announcements, Support (with Installation) and Off-topic, the tags howto, question, release-notes and backups, seven topics with replies and likes, a personal message.')
parser.add_argument('-v', '--discourse-version',
                    default="",
                    help='The release to install: a tag (v2026.10.2), or a channel: release (the current monthly release, the default), esr (the extended support release) or latest. Example: --discourse-version esr')
parser.add_argument('-l', '--launch',
                    action='store_true',
                    default=False,
                    help='Open the forum in a browser when it is ready.')
ARGEOF
