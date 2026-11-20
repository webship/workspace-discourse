#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The Discourse project in this workspace.')
parser.add_argument('-r', '--rails',
                    default="_none_",
                    help='A rails command to run in the forum, with its arguments. Example: --rails "runner \'puts User.count\'"')
parser.add_argument('-k', '--rake',
                    default="_none_",
                    help='A rake task to run in the forum, with its arguments. Example: --rake "admin:create"')
parser.add_argument('--restart',
                    action='store_true',
                    default=False,
                    help='Start the forum again (its container), and wait for it.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='Add the default accounts. An account that is already there gets its email, name, password, role and trust level back.')
parser.add_argument('-c', '--cancel-users',
                    action='store_true',
                    default=False,
                    help='Delete the default accounts and their posts (never the workspace account).')
parser.add_argument('-s', '--sample-data',
                    action='store_true',
                    default=False,
                    help='Put the sample data back: what is missing of it is made again.')
ARGEOF
