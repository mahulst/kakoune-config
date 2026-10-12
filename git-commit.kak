# Git commits from within Kakoune.
provide-module git-commit2 %{
  declare-user-mode git-commit2

  map global git-commit2 c ':git-commit<ret>'            -docstring 'commit staged changes'
  map global git-commit2 C ':git-commit-all<ret>'        -docstring 'commit everything'
  map global git-commit2 a ':git-commit-amend<ret>'      -docstring 'amend last commit'
  map global git-commit2 e ':git-commit-amend-no-edit<ret>' -docstring 'extend last commit'
}

define-command git-commit-raw -params 0.. -docstring 'git commit <arguments>; show full output (incl. pre-commit hook feedback) in the docs client' %{
    evaluate-commands %sh{
        toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
        if [ -z "$toplevel" ]; then
            echo "fail 'not in a git repository'"
            exit
        fi
        outfile=$(mktemp "${TMPDIR:-/tmp}"/kak-git-commit.XXXXXX)
        ( cd "$toplevel" && git commit "$@" ) > "$outfile" 2>&1
        status=$?
        printf '%s\n' "
            try %{ delete-buffer *git-commit-output* }
            evaluate-commands -try-client %opt{docsclient} %{
                edit! '$outfile'
                rename-buffer *git-commit-output*
                set-option buffer readonly true
                hook -always -once buffer BufClose .* %{ nop %sh{ rm -f '$outfile' } }
            }
        "
        if [ "$status" -eq 0 ]; then
            echo "echo -markup '{Information}Commit succeeded'"
        else
            echo "fail 'Commit failed, see docs client'"
        fi
    }
}

define-command git-commit -docstring 'prompt for a commit message and commit staged changes' %{
    prompt 'commit message: ' %{ git-commit-raw -m %val{text} }
}

define-command git-commit-all -docstring 'prompt for a commit message and commit all tracked changes' %{
    prompt 'commit message (all): ' %{ git-commit-raw -a -m %val{text} }
}

define-command git-commit-amend -docstring 'prompt for a commit message and amend HEAD' %{
    prompt -init %sh{ git log -1 --format=%s 2>/dev/null } 'amend message: ' %{ git-commit-raw --amend -m %val{text} }
}

define-command git-commit-amend-no-edit -docstring 'amend HEAD, keeping its message' %{
    git-commit-raw --amend --no-edit
}
