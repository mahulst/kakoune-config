# Timesheet support
# <space>S enters timesheet user mode
# Keys:
#   t - append current time (HH:MM) to end of line
#   e - append ' - HH:MM' to end of line
#   h - calculate hours from time ranges in selection, append total
#   g - generate current month entries grouped by ISO week
#   d - jump cursor to today's date

declare-user-mode timesheet

map global user S ':enter-user-mode timesheet<ret>' -docstring 'timesheet mode'

map global timesheet t ':timesheet-insert-time<ret>' -docstring 'append time'
map global timesheet e ':timesheet-append-end-time<ret>' -docstring 'append - time to end of line'
map global timesheet h ':timesheet-calc-hours<ret>' -docstring 'calculate hours from selection'
map global timesheet g ':timesheet-generate-month<ret>' -docstring 'generate current month'
map global timesheet d ':timesheet-goto-today<ret>' -docstring 'go to today'

define-command -hidden timesheet-insert-time -docstring 'append current time to end of line' %{
    execute-keys "ghGla %sh{date '+%H:%M'}<esc>"
}

define-command -hidden timesheet-append-end-time -docstring 'append - time to end of line' %{
    execute-keys "ghGla - %sh{date '+%H:%M'}<esc>"
}

define-command -hidden timesheet-calc-hours -docstring 'calculate hours from time ranges per line in selection' %{
    evaluate-commands %sh{
        # Process each line in the selection individually.
        # For lines with a valid "HH:MM - HH:MM" range, calculate hours and
        # append/overwrite the "(X.XX hours)" annotation on that line.
        # Lines without a valid range are left unchanged.
        # The result replaces the entire selection.

        found=0
        result=""
        IFS='
'
        for line in $kak_selection; do
            # Check if line contains ' - ' with times
            left=$(echo "$line" | sed 's/ - .*//')
            right=$(echo "$line" | sed 's/.* - //')

            start_time=$(echo "$left" | grep -oE '[0-9]{1,2}:[0-9]{2}' | tail -1)
            end_time=$(echo "$right" | grep -oE '[0-9]{1,2}:[0-9]{2}' | tail -1)

            if [ -n "$start_time" ] && [ -n "$end_time" ] && echo "$line" | grep -q ' - '; then
                start_h=$(echo "$start_time" | cut -d: -f1 | sed 's/^0*//')
                start_m=$(echo "$start_time" | cut -d: -f2 | sed 's/^0*//')
                end_h=$(echo "$end_time" | cut -d: -f1 | sed 's/^0*//')
                end_m=$(echo "$end_time" | cut -d: -f2 | sed 's/^0*//')

                start_h=${start_h:-0}
                start_m=${start_m:-0}
                end_h=${end_h:-0}
                end_m=${end_m:-0}

                start_total=$((start_h * 60 + start_m))
                end_total=$((end_h * 60 + end_m))

                if [ "$end_total" -lt "$start_total" ]; then
                    diff=$(( (1440 - start_total) + end_total ))
                else
                    diff=$((end_total - start_total))
                fi

                hours=$((diff / 60))
                remaining=$((diff % 60))
                if [ "$remaining" -eq 0 ]; then
                    decimal="00"
                else
                    decimal=$(printf '%02d' $((remaining * 100 / 60)))
                fi

                # Strip existing (X.XX hours) annotation if present
                clean=$(echo "$line" | sed 's/ *([0-9]*\.[0-9]* hours)$//')
                line="${clean} (${hours}.${decimal} hours)"
                found=1
            fi

            if [ -z "$result" ]; then
                result="$line"
            else
                result="${result}
${line}"
            fi
        done

        if [ "$found" = "0" ]; then
            echo "echo -markup '{Error}no time ranges found in selection'"
        else
            # Write result to temp file to avoid quoting issues
            printf '%s' "$result" > /tmp/kak_timesheet_result
            echo "execute-keys '|cat /tmp/kak_timesheet_result<ret>'"
        fi
    }
}

define-command -hidden timesheet-generate-month -docstring 'generate current month entries grouped by week' %{
    evaluate-commands %sh{
        year=$(date '+%Y')
        month=$(date '+%m')
        last_day=$(date -j -v1d -v+1m -v-1d -f '%Y-%m-%d' "${year}-${month}-15" '+%d' | sed 's/^0//')
        current_week=""
        output=""

        for day in $(seq 1 $last_day); do
            d=$(printf '%s-%s-%02d' "$year" "$month" "$day")
            week=$(date -j -f '%Y-%m-%d' "$d" '+%V' | sed 's/^0//')
            if [ "$week" != "$current_week" ]; then
                if [ -n "$current_week" ]; then
                    output="${output}
"
                fi
                output="${output}Week ${week}:"
                current_week=$week
            fi
            output="${output}
${d}"
        done

        # Escape single quotes for kakoune
        escaped=$(printf '%s' "$output" | sed "s/'/''/g")
        echo "execute-keys 'i${escaped}<esc>'"
    }
}

define-command -hidden timesheet-goto-today -docstring 'jump to today in the buffer' %{
    execute-keys "gg/%sh{date '+%Y-%m-%d'}<ret>gh"
}
