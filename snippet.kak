define-command insert-date %{
    execute-keys '|date +"%F %T.%3Z"<ret><esc>'
}
define-command insert-frontmatter %{
    evaluate-commands -save-regs d %sh{
        date=$(date +"%F %T.%3Z")
        template=$(printf "%s" "${kak_opt_frontmatter_template}" | sed "s/<date>/$date/")
        echo "execute-keys 'i${template}'"
    }
}
define-command insert-jest-test %{
    evaluate-commands -save-regs d %sh{
        echo "execute-keys 'i${kak_opt_jest_test_template}'"
    }
}
define-command insert-weekly %{
    evaluate-commands %sh{
        week_number=$(date -v -$(($(date +%u)-1))d +%Y-%m-%d)
        template=$(printf "%s" "${kak_opt_weekly_template}" | sed "s/<week>/$week_number/")
        echo "execute-keys 'i${template} <esc>'"
    }}
define-command create-weekly-file %{
    evaluate-commands %sh{
        week_number=$(date -v -$(($(date +%u)-1))d +%Y-%m-%d)
        filename="weeklies/${week_number}.md"
        touch "$filename"
        echo "edit $filename"
    }
    evaluate-commands %{
        insert-weekly
    }
}
define-command insert-work-task  -params 1 %{
    evaluate-commands %sh{
        day=$(date +%F)
        template=$(printf "%s" "${kak_opt_work_task_template}" | sed "s/<day>/$day/"| sed "s/<task>/$1/")
        echo "execute-keys 'i${template} <esc>'"
    }
}

declare-user-mode snippet
map global user -docstring 'insert snippet' i ':enter-user-mode snippet<ret>'
map global snippet -docstring 'current date' d ':insert-date<ret>'
map global snippet -docstring 'frontmatter template' f ':insert-frontmatter<ret>'
map global snippet -docstring 'jest test' j ':insert-jest-test<ret>'
map global snippet -docstring 'create and open weekly template' w ':create-weekly-file<ret>'
declare-user-mode work-task
map global snippet -docstring 'insert work task' t ':enter-user-mode work-task<ret>'
map global work-task -docstring 'gamedev' g ':insert-work-task gamedev <ret>'
map global work-task -docstring 'notes' n ':insert-work-task writing <ret>'
map global work-task -docstring 'learning' l ':insert-work-task learning <ret>'
map global work-task -docstring 'website' w ':insert-work-task website <ret>'
map global work-task -docstring 'kakoune config' k ':insert-work-task kakoune <ret>'

declare-option str work_task_template %{
  - <task>|<day>|0.0

}
declare-option str frontmatter_template %{---
publish: true
secret: true
tags:
- tag
title: Title
date: <date> 
---
}

declare-option str jest_test_template %{
    test('''', async () => {});
}

declare-option str weekly_template %{---
publish: true
secret: true
tags:
  - weekly
date: <week> 07:00:00.0Z
mood: 3
tracker:
  - writing|<week>|0.0
---

# Highlights:
 
# Notes

# Ideas

# Closing notes

}
