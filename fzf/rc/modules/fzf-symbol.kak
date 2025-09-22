hook global ModuleLoaded fzf %{
    map -docstring 'symbols' global fzf S ': require-module fzf-symbol; fzf-symbol<ret>'
}

provide-module fzf-symbol %§

declare-option -docstring "" \
str fzf_symbol_search_command 'kak-symbol-search'

define-command -hidden fzf-symbol %{ evaluate-commands %sh{
    cmd="$kak_opt_fzf_symbol_search_command"
    cmd="$cmd 2>/dev/null"
    title="fzf symbol"
    message="find symbols in project.
<ret>: open search result in new buffer."

    preview_cmd=""

    printf "%s\n" "info -title '${title}' '${message}${tmux_keybindings}'"
    [ -n "${kak_client_env_TMUX}" ] && additional_flags="--expect ${kak_opt_fzf_vertical_map:-ctrl-v} --expect ${kak_opt_fzf_horizontal_map:-ctrl-s}"
    printf "%s\n" "fzf -kak-cmd %{evaluate-commands} ${preview_cmd} -fzf-args %{--expect ${kak_opt_fzf_window_map:-ctrl-w} $additional_flags  -n 2} -items-cmd %{$cmd} -filter %{sed -E 's/.*\(([^:]+):([0-9]+):([0-9]+)\).*/edit -existing \1; execute-keys \2g /'}"
}}
§
