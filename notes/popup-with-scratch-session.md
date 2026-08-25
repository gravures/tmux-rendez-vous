# Launch a Popup with a Scratch Session

```bash
TMUX_BASE_CLIENT=$(tmux display -p "#{client_name}")
tmux new-session -E -d -s scratch-rdv -n scratch-rdv \
	-e "TMUX_BASE_CLIENT=${TMUX_BASE_CLIENT}" 'rendez-vous-picker'
tmux set-option -t scratch-rdv status off
tmux display-popup -w '80%' -h '70%' "tmux attach-session -t scratch-rdv"
tmux kill-session -t 'scratch-rdv'
```
