define-command http-run -docstring 'parse HTTP request block at cursor and run it with curl' %{
    evaluate-commands -draft %{
        # Select the entire buffer content
        execute-keys '%'
        evaluate-commands %sh{
            input="$kak_selection"

            method=""
            url=""
            headers=""
            body=""
            in_body=false
            past_method=false

            while IFS= read -r line; do
                line=$(printf '%s' "$line" | tr -d '\r')

                case "$line" in
                    \#\#\#*) continue ;;
                esac

                if [ "$past_method" = "false" ]; then
                    if [ -z "$line" ]; then
                        continue
                    fi
                    method=$(printf '%s' "$line" | awk '{print $1}')
                    url=$(printf '%s' "$line" | awk '{print $2}')
                    past_method=true
                    continue
                fi

                if [ "$in_body" = "true" ]; then
                    body="${body}${line}"
                elif [ -z "$line" ]; then
                    in_body=true
                else
                    headers="${headers} -H '${line}'"
                fi
            done <<EOF
$input
EOF

            if [ -z "$method" ] || [ -z "$url" ]; then
                echo "fail 'Could not parse method and URL from buffer'"
                exit
            fi

            curl_cmd="curl -s -X ${method}${headers}"

            if [ -n "$body" ]; then
                escaped_body=$(printf '%s' "$body" | sed "s/'/'\\\\''/g")
                curl_cmd="${curl_cmd} -d '${escaped_body}'"
            fi

            curl_cmd="${curl_cmd} '${url}'"

            # Write a temp script to avoid eval/quoting issues
            tmpdir=$(mktemp -d "${TMPDIR:-/tmp}"/kak-http.XXXXXXXX)
            script="${tmpdir}/run.sh"
            fifo="${tmpdir}/fifo"
            mkfifo "$fifo"

            cat > "$script" <<SCRIPT
#!/bin/sh
resp=\$(${curl_cmd} 2>&1)
if printf '%s' "\$resp" | jq . > /dev/null 2>&1; then
    printf '%s' "\$resp" | jq .
else
    printf '%s\n' "\$resp"
fi
SCRIPT
            chmod +x "$script"

            # Run in background, fully detached from kakoune
            ( "$script" > "$fifo" 2>&1 ) > /dev/null 2>&1 < /dev/null &

            printf "evaluate-commands -try-client %%opt{toolsclient} %%{
                edit! -fifo %s -scroll *httpresponse*
                set-option buffer filetype json
                hook -once buffer BufCloseFifo .* %%{
                    nop %%sh{ rm -r %s }
                }
            }\n" "$fifo" "$tmpdir"
        }
    }
}

map -docstring "HTTP request" global user H ':http-run<ret>'
