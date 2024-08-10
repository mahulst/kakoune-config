define-command insert-date %{
    execute-keys '|date +"%F %T.%3Z"<ret><esc>'
}
define-command insert-frontmatter %{
    evaluate-commands -save-regs d %sh{
        echo "execute-keys 'i${kak_opt_frontmatter_template}'"
    }
}
declare-user-mode snippet
map global user -docstring 'insert snippet' i ':enter-user-mode snippet<ret>'
map global snippet -docstring 'current date' d ':insert-date<ret>'
map global snippet -docstring 'frontmatter template' f ':insert-frontmatter<ret>'

declare-option str frontmatter_template %{---
publish: true
secret: true
tags:
  - tag
title: Title
date: 
---
}


