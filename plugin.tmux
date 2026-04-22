#!/usr/bin/env bash
# TODO: README.md
#
script_dir="$(command cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
##
##
##
