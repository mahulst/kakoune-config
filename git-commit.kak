# Git commits from within Kakoune.
provide-module git-commit2 %{
  declare-user-mode git-commit2

  map global git-commit2 c ':git commit -v<ret>'                -docstring 'commit staged changed'
  map global git-commit2 C ':git commit -va<ret>'               -docstring 'commit everything'
  map global git-commit2 a ':git commit --amend<ret>'           -docstring 'amend last commit'
  map global git-commit2 e ':git commit --amend --no-edit<ret>' -docstring 'extend last commit'
}
