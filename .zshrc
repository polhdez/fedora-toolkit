# - Env vars -
export PATH=$PATH:~/.local/bin/
export SAVEHIST=10000
export HISTSIZE=10000
export HISTFILE=~/.zsh_history

# - Keybinds -
typeset -g -A key
key[Home]="${terminfo[khome]}"
key[End]="${terminfo[kend]}"
key[Insert]="${terminfo[kich1]}"
key[Backspace]="${terminfo[kbs]}"
key[Delete]="${terminfo[kdch1]}"
key[Up]="${terminfo[kcuu1]}"
key[Down]="${terminfo[kcud1]}"
key[Left]="${terminfo[kcub1]}"
key[Right]="${terminfo[kcuf1]}"
key[PageUp]="${terminfo[kpp]}"
key[PageDown]="${terminfo[knp]}"
key[Shift-Tab]="${terminfo[kcbt]}"

[[ -n "${key[Home]}"      ]] && bindkey -- "${key[Home]}"       beginning-of-line
[[ -n "${key[End]}"       ]] && bindkey -- "${key[End]}"        end-of-line
[[ -n "${key[Insert]}"    ]] && bindkey -- "${key[Insert]}"     overwrite-mode
[[ -n "${key[Backspace]}" ]] && bindkey -- "${key[Backspace]}"  backward-delete-char
[[ -n "${key[Delete]}"    ]] && bindkey -- "${key[Delete]}"     delete-char
[[ -n "${key[Up]}"        ]] && bindkey -- "${key[Up]}"         up-line-or-history
[[ -n "${key[Down]}"      ]] && bindkey -- "${key[Down]}"       down-line-or-history
[[ -n "${key[Left]}"      ]] && bindkey -- "${key[Left]}"       backward-char
[[ -n "${key[Right]}"     ]] && bindkey -- "${key[Right]}"      forward-char
[[ -n "${key[PageUp]}"    ]] && bindkey -- "${key[PageUp]}"     beginning-of-buffer-or-history
[[ -n "${key[PageDown]}"  ]] && bindkey -- "${key[PageDown]}"   end-of-buffer-or-history
[[ -n "${key[Shift-Tab]}" ]] && bindkey -- "${key[Shift-Tab]}"  reverse-menu-complete

bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

# - Fix for home and end of line keys -
if (( ${+terminfo[smkx]} && ${+terminfo[rmkx]} )); then
	autoload -Uz add-zle-hook-widget
	function zle_application_mode_start { echoti smkx }
	function zle_application_mode_stop { echoti rmkx }
	add-zle-hook-widget -Uz zle-line-init zle_application_mode_start
	add-zle-hook-widget -Uz zle-line-finish zle_application_mode_stop
fi

# - Plugins -
ZSH_PLUGIN_DIR=/usr/share/
[[ -f $ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
    source $ZSH_PLUGIN_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh
if [[ -f $ZSH_PLUGIN_DIR/zsh-history-substring-search/zsh-history-substring-search.zsh ]]; then
    source $ZSH_PLUGIN_DIR/zsh-history-substring-search/zsh-history-substring-search.zsh
    [[ -n "${key[Up]}"        ]] && bindkey -- "${key[Up]}"         history-substring-search-up
    [[ -n "${key[Down]}"      ]] && bindkey -- "${key[Down]}"       history-substring-search-down
fi
[[ -f $ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] &&
    source $ZSH_PLUGIN_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# - Completion -
autoload -U compinit promptinit
compinit
zstyle ':completion:*' menu select

# - Aliases -
alias ll="ls -la"
alias cls=clear

# - Prompt -
eval "$(starship init zsh)"