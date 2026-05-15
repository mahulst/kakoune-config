declare-user-mode moon
declare-option -hidden str moon_target ""
declare-option -hidden str moon_action ""

map -docstring "moon mode" global user M %{: enter-user-mode moon<ret>}

map -docstring "moon build" global moon b %{: moon-run-action build<ret>}
map -docstring "moon typecheck" global moon c %{: moon-run-action typecheck<ret>}
map -docstring "moon test" global moon t %{: moon-run-action test<ret>}

define-command -hidden moon-run-action -params 1 %{
    set-option buffer moon_action %arg{1}
    moon-resolve-target
    evaluate-commands %sh{
        if [ -n "$kak_opt_moon_target" ]; then
            printf "moon-run-action-exec\n"
        else
            printf "prompt moon_target: %%{ set-option buffer moon_target %%val{text}; moon-run-action-exec }\n"
        fi
    }
}

define-command -hidden moon-resolve-target %{
    evaluate-commands %sh{
        buffile="${kak_buffile:-$kak_bufname}"
        target=""

        case "$buffile" in
            */apps/*)
                rest="${buffile#*/apps/}"
                target="${rest%%/*}"
                ;;
            */packages/*)
                rest="${buffile#*/packages/}"
                target="${rest%%/*}"
                ;;
        esac

        escaped_target=${target//\'/\'\"\'\"\'}
        escaped_buffile=${buffile//\'/\'\"\'\"\'}
        printf "set-option buffer moon_target '%s'\n" "$escaped_target"
        printf "echo -debug 'moon buffile=%s target=%s'\n" "$escaped_buffile" "$escaped_target"
    }
}

define-command -hidden moon-run-action-exec %{
    evaluate-commands %sh{
        action="$kak_opt_moon_action"
        target="$kak_opt_moon_target"
        target=$(printf '%s' "$target" | tr -d '[:space:]')

        escaped_action=${action//\'/\'\"\'\"\'}
        escaped_target=${target//\'/\'\"\'\"\'}
        printf "echo -debug 'moon action=%s target=%s'\n" "$escaped_action" "$escaped_target"

        if [ -z "$target" ]; then
            printf "fail 'moon target required'\n"
            exit
        fi

        case "$action" in
            build)
                cmd="DEBUG_PRINT_LIMIT=100000 moonx ${target}:build"
                output_type="tsc-moon"
                ;;
            typecheck)
                cmd="DEBUG_PRINT_LIMIT=100000 COLORS=false moon run ${target}:typecheck"
                output_type="tsc-moon"
                ;;
            test)
                cmd="DEBUG_PRINT_LIMIT=100000 NO_COLOR=1 moonx ${target}:test"
                output_type="jest-moon"
                ;;
            *)
                printf "fail 'unknown moon action: %s'\n" "$action"
                exit
                ;;
        esac

        escaped_cmd=${cmd//\'/\'\"\'\"\'}
        printf "run-in-fifo '%s' '%s'\n" "$escaped_cmd" "$output_type"
    }
}
