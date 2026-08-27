#!/usr/bin/env bash
#
#        ┌────────────────────────────────────────────────────┐
#        │                                                    │
#        │                                                    │
#        │ ██████╗ ███████╗███╗   ██╗██████╗ ███████╗███████╗ │
#        │ ██╔══██╗██╔════╝████╗  ██║██╔══██╗██╔════╝╚══███╔╝ │
#        │ ██████╔╝█████╗  ██╔██╗ ██║██║  ██║█████╗    ███╔╝  │
#        │ ██╔══██╗██╔══╝  ██║╚██╗██║██║  ██║██╔══╝   ███╔╝   │
#        │ ██║  ██║███████╗██║ ╚████║██████╔╝███████╗███████╗ │
#        │ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝╚═════╝ ╚══════╝╚══════╝ │
#        │         ██╗   ██╗ ██████╗ ██╗   ██╗███████╗        │
#        │         ██║   ██║██╔═══██╗██║   ██║██╔════╝        │
#        │         ██║   ██║██║   ██║██║   ██║███████╗        │
#        │         ╚██╗ ██╔╝██║   ██║██║   ██║╚════██║        │
#        │          ╚████╔╝ ╚██████╔╝╚██████╔╝███████║        │
#        │           ╚═══╝   ╚═════╝  ╚═════╝ ╚══════╝        │
#        │                                                    │
#        │..............Rendez-Vous Tmux Plugin...............│
#        └────────────────────────────────────────────────────┘
#
# Bash features used over this plugin:
# ┌──────────────────────────────┬─────────┬──────────────────────────────┐
# │ Feature                      │ Version │ Location                     │
# ├──────────────────────────────┼─────────┼──────────────────────────────┤
# │ readarray -d                 │ 4.4     │ plugin.tmux:13               │
# ├──────────────────────────────┼─────────┼──────────────────────────────┤
# │ $! and wait for process      │ 4.4     │ rdv-notify                   │
# ├──────────────────────────────┼─────────┼──────────────────────────────┤
# │ readarray                    │ 4.0     │ save-rendez-vous             │
# ├──────────────────────────────┼─────────┼──────────────────────────────┤
# │ += for arrays                │ 3.1     │ rdv-notify, save-rendez-vous │
# ├──────────────────────────────┼─────────┼──────────────────────────────┤
# │ ${var//pat/repl}             │ 3.0     │ plugin.tmux                  │
# ├──────────────────────────────┼─────────┼──────────────────────────────┤
# │ ${var:i:1} (variable offset) │ 3.0     │ tmux-spinner                 │
# ├──────────────────────────────┼─────────┼──────────────────────────────┤
# │ <<< here-string              │ 2.05b   │ rdv-notify                   │
# ├──────────────────────────────┼─────────┼──────────────────────────────┤
# │ [[ ]]                        │ 2.02    │ most scripts                 │
# ├──────────────────────────────┼─────────┼──────────────────────────────┤
# │ (( )) arithmetic             │ 2.0     │ rdv-notify, _test            │
# ├──────────────────────────────┼─────────┼──────────────────────────────┤
# │ declare -r                   │ 2.0     │ rdv-notify                   │
# └──────────────────────────────┴─────────┴──────────────────────────────┘
#
# External commands dependencies:
# ┌───────────────┬──────────────────────────────────────┐
# │ sesh          │ when dealing with sessions           │
# ├───────────────┼──────────────────────────────────────┤
# │ lazy-tmux     │ sessions persistances / restoration  │
# ├───────────────┼──────────────────────────────────────┤
# │ fzf           │ plugin pickers                       │
# └───────────────┴──────────────────────────────────────┘
#
# TODO: feature: save the list of all opened client's sessions in daemon
#       in addition of sessions states, and on tmux starts propose
#       to restore the last client's state
#
# TODO: Auto restore sessions on new tmux run

# shellcheck source-path=../tmux-bash-lib/lib
source tmux::plugin.sh

plugin::require_tmux 3 6 || exit 1
plugin::require_bash 4 4 || exit 1
plugin::require_command 'sesh' || exit 1
plugin::require_command 'lazy-tmux' || exit 1
plugin::require_command 'fzf' || exit 1

plugin::set_default '@rendez-vous-linker-bg' default
plugin::set_default '@rendez-vous-linker-fg' default
plugin::set_default '@rendez-vous-linker-border' default

plugin::set_default '@rendez-vous-save-daemon-enabled' off
plugin::set_default '@rendez-vous-save-daemon-interval' 15

plugin::set_default '@rendez-vous-save-scrollback' off
plugin::set_default '@rendez-vous-save-before-hook' off
plugin::set_default '@rendez-vous-save-after-hook' off
plugin::set_default '@rendez-vous-restore-before-hook' off
plugin::set_default '@rendez-vous-restore-after-hook' off
plugin::set_default '@rendez-vous-connect-after-restore' on

plugin::add_direnv bin

##
#
STATE_DIRECTORY="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-rendez-vous"
mkdir -p "${STATE_DIRECTORY}" && tmux set-environment -g TMUX_RDV_STATE "${STATE_DIRECTORY}"

##
# Commands Alias
# shellcheck disable=SC2102,SC2086
tmux set-option -s command-alias[700] "cd=attach-session -t . -c"
tmux set-option -s command-alias[701] "last-session=run 'sesh last'"
# shellcheck disable=SC2016
tmux set-option -s command-alias[702] 'sesh-root=run "sesh connect --root $(pwd)"'

##
# Save Daemon
killall rdv-saver-daemon &> /dev/null
if [[ $(tmux show -gv '@rendez-vous-save-daemon-enabled') == "on" ]]; then
	tmux run -b rdv-saver-daemon
fi
