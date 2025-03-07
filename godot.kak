define-command godot-run-file -docstring 'Run current buffer godot script' %{
    evaluate-commands %sh{
        filename=$(basename "$kak_buffile")
        echo "run-in-fifo 'godot --headless -s ${kak_buffile}' godot"
    } 
}

define-command godot-run-tests -docstring 'Run godot tests' %{
    evaluate-commands %sh{
        rootdir=$(git rev-parse --show-toplevel)
        filename=$(basename "$kak_buffile")
        echo "run-in-fifo ' godot -d -s --path "$rootdir" addons/gut/gut_cmdln.gd --headless' godot"
    } 
}

define-command godot-run-test -docstring 'Run godot tests in current file' %{
    evaluate-commands %sh{

        rootdir="$(git rev-parse --show-toplevel)"
        absolute_path="$kak_buffile"
        relative_path="${absolute_path#"$rootdir/"}"
        echo "run-in-fifo ' godot -d -s --path "$rootdir" addons/gut/gut_cmdln.gd -gtest=res://$relative_path --headless -gprefix="XX"' godot"
    } 
}

define-command godot-run-format -docstring 'Run gdformat' %{
    nop %sh{
        ~/.venv/godot/bin/gdformat --use-spaces=4 $kak_buffile
    } 
    edit!
}

declare-option \
  -docstring "name or path of Godot executable" \
  str godot_executable "godot"

declare-option \
  -docstring "arguments passed to the Godot executable" \
  str-list godot_arguments "--debug"


define-command \
  -docstring "run a Godot scene file from the completion list" \
  -params 1.. \
  godot %{ evaluate-commands %sh{
    # Find Godot project path
    godot_scene_path="$1"; shift
    godot_extra_arguments="$@"
    godot_project_path=""
    path=$(realpath "$godot_scene_path")
    while [ -z "$godot_path" -a "$path" != '/' ]; do
      path=$(dirname "$path")
      godot_path=$(find "$path" -maxdepth 1 -type f -name 'project.godot')
      godot_path=$([ -n "$godot_path" ] && dirname "$godot_path")
    done
    
    # If we found it then run Godot otherwise notify the user that we can't run the scene
    if [ -n "$godot_path" ]; then
      fifo=$(mktemp --directory --tmpdir godot.kak.XXXXXXXX)/fifo
      mkfifo $fifo
      godot_scene_path=$(realpath --relative-to="$godot_path" "$godot_scene_path")
      ("$(echo "$kak_opt_godot_executable" | envsubst)" --path "$godot_path" $kak_opt_godot_arguments $godot_extra_arguments "$godot_scene_path" > $fifo 2>&1) < /dev/null > /dev/null 2>&1 &
      godot_pid=$!
      printf "%s\n" "edit! -fifo $fifo -scroll *godot*
                     info -title 'godot.kak' 'Running \`$(basename "$kak_opt_godot_executable") --path ''$godot_path'' $kak_opt_godot_arguments $godot_extra_arguments ''$godot_scene_path''\`...'
                     hook buffer BufCloseFifo .* %{ nop %sh{
                       kill $godot_pid > /dev/null 2>&1
                       rm -r $(dirname $fifo)
                     } }"
    else
      printf "info -title 'godot.kak' 'Can''t find Godot project path for \`$godot_scene_path\`. Skipping...'"
    fi
  } }

complete-command -menu godot shell-script-candidates %{
  case "$kak_token_to_complete" in
    0) find -type f -regex ".*.tscn";;
  esac
}


define-command \
  -docstring "try runing a Godot scene file based on the current buffer file name" \
  -params 0 \
  godot-current %{ evaluate-commands %sh{
    rootdir="$(git rev-parse --show-toplevel)"
    absolute_path="$kak_buffile"
    relative_path="${absolute_path#"$rootdir/"}"
    echo "run-in-fifo ' godot $relative_path' godot"

  } }

declare-user-mode godot

map -docstring "Godot" global user G \
    %{:enter-user-mode godot<ret>}

map -docstring "Run file" \
	global godot r %{: godot-run-file  <ret>}
map -docstring "Run all test" \
	global godot t %{: godot-run-tests <ret>}
map -docstring "Run test file" \
	global godot T %{: godot-run-tests <ret>}

map -docstring "Run gdformat" \
	global godot f %{: godot-run-format  <ret>}
