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
# TODO: README.md
#
script_dir="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

##
# Requierements
function require_tmux() {
	local require version
	require=(3 6)
	readarray -td'.' version < <(tmux display -p "#{version}")

	[[ ${version[0]} -gt ${require[0]} ]] && return 0
	# Minor version can be a number or alphanumeric, e.g. 3.3 vs 3.3a
	[[ ${version[0]} -eq ${require[0]} ]] &&
		[[ "${version[1]//[!0-9]/}" -ge ${require[1]} ]] &&
		return 0

	tmux display -d 3000 "!!! rendez-vous plugin require a tmux version >= ${require[*]}"
	exit 1
}

function require_command() {
	local cmd=${1:? missing <command> parameter}

	if
		! command -v "${cmd}" >/dev/null
	then
		tmux display -d 3000 "!!! rendez-vous plugin require '${cmd}' program"
		exit 1
	fi
}

require_tmux
require_command 'sesh'
require_command 'lazy-tmux'
require_command 'fzf'

##
# Options
#
set_option() {
	local name=${1:? missing <name> parameter}
	local default=${2:? missing <name> parameter}

	if ! tmux show-options -gv "${name}" >/dev/null; then
		tmux set-option -g "${name}" "${default}"
	fi
}
set_option '@rendez-vous-linker-bg' default
set_option '@rendez-vous-linker-fg' default
set_option '@rendez-vous-linker-border' default

set_option '@rendez-vous-save-daemon-enabled' off
set_option '@rendez-vous-save-daemon-interval' 15

set_option '@rendez-vous-save-scrollback' off
set_option '@rendez-vous-save-before-hook' off
set_option '@rendez-vous-save-after-hook' off
set_option '@rendez-vous-restore-before-hook' off
set_option '@rendez-vous-restore-after-hook' off

##
# adds ./bin to $PATH in tmux session environment
# this will give tmux direct access to commands in bin/
bin="${script_dir}/bin"
updated="${bin}"
spath=$(tmux show-environment -g PATH)
spath="${spath##*=}"
while IFS=: read -d: -r path; do
	[[ ${path} != "${bin}" ]] && updated+=":${path}"
done <<<"${spath:+"${spath}:"}"
tmux set-environment -g PATH "${updated}"

##
# Commands Alias
# shellcheck disable=SC2102,SC2086
tmux set-option -s command-alias[700] "cd=attach-session -t . -c"
tmux set-option -s command-alias[701] "last-session=run 'sesh last'"
tmux set-option -s command-alias[702] 'sesh-root=run "sesh connect --root $(pwd)"'

# Sesh Integration
# bind-key -N 'new window' 'n' command-prompt -I "#S" { run sesh window --session "%%"}

##
# Save Daemon
killall rdv-saver-daemon &>/dev/null
if [[ $(tmux show -gv '@rendez-vous-save-daemon-enabled') == "on" ]]; then
	tmux run -b rdv-saver-daemon
fi
