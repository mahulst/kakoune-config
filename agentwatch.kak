# Highlighting + wrapping for `agentctl watch` output piped through run-in-fifo.
# Trace line shape:  HH:MM:SS  toolname  detail
#                                        indented continuation lines

hook global WinSetOption filetype=agentwatch %{
    # Soft-wrap long lines at word boundaries, keeping continuation indented.
    add-highlighter buffer/agentwatch-wrap wrap -word -indent

    add-highlighter buffer/agentwatch group

    # Timestamp at start of line.
    add-highlighter buffer/agentwatch/ regex ^\d{2}:\d{2}:\d{2} 0:comment

    # Event / tool label (second column). Group by kind.
    add-highlighter buffer/agentwatch/ regex ^\d{2}:\d{2}:\d{2}\h+(assistant)\b 1:title
    add-highlighter buffer/agentwatch/ regex ^\d{2}:\d{2}:\d{2}\h+(thinking)\b 1:comment
    add-highlighter buffer/agentwatch/ regex ^\d{2}:\d{2}:\d{2}\h+(bash)\b 1:function
    add-highlighter buffer/agentwatch/ regex ^\d{2}:\d{2}:\d{2}\h+(edit|write)\b 1:keyword
    add-highlighter buffer/agentwatch/ regex ^\d{2}:\d{2}:\d{2}\h+(read|grep|glob)\b 1:string
    add-highlighter buffer/agentwatch/ regex ^\d{2}:\d{2}:\d{2}\h+(webfetch)\b 1:attribute
    add-highlighter buffer/agentwatch/ regex ^\d{2}:\d{2}:\d{2}\h+(status|idle)\b 1:comment
    add-highlighter buffer/agentwatch/ regex \berror\b 0:Error

    # Dim indented continuation / tool-output lines.
    add-highlighter buffer/agentwatch/ regex ^\h{6,}.*$ 0:comment
}

hook global WinSetOption filetype=(?!agentwatch).* %{
    try %{ remove-highlighter buffer/agentwatch-wrap }
    try %{ remove-highlighter buffer/agentwatch }
}
