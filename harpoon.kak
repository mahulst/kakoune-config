# File based commands

define-command peek -docstring %{ open a buffer with all your saved marks, it refers to the file where they are stored so you can manipulate it } -override %{
  edit %sh{
    rootdir=$(git rev-parse --show-toplevel)
    meatsfile="$rootdir/.meats"
    [[ -f "$meatsfile" ]] || touch "$meatsfile"
    printf "$meatsfile\n"
  }
  set buffer autoreload true
  set-option buffer filetype harpoon
}

hook global WinSetOption filetype=harpoon %{
    map -docstring "Jump to position" buffer normal <ret> %{: harpoon-jump<ret>}
}
hook global WinSetOption filetype=(?!harpoon).* %{
    unmap buffer normal <ret> %{: harpoon-jump<ret>}
}

declare-option -docstring "regex describing file paths and line numbers" \
    regex \
    harpoon_file_pattern \
    "/(\w|\.|-|/)+:\d+:\d+"

define-command harpoon-jump %{

    evaluate-commands -save-regs fl %{

        execute-keys -draft "g" "h" "/" %opt{harpoon_file_pattern} <ret> "<a-;>" ";T:" '"fy' 'llT:"ly'

	harpoon-line-column %reg{f} %reg{l}
    }
}
define-command harpoon-line-column -params 2 %{
    evaluate-commands -try-client %opt{jumpclient} %{
        edit -existing "%arg{1}" "%arg{2}" 

        try %{ focus }
    }
} -docstring "Like edit but understands file:line:col parameters"

define-command stab -override -docstring %{ save a meat to marks } %{
  info -style modal "Stab!!!: "
  on-key %{
    info -style modal
    nop %sh{ 
      rootdir=$(git rev-parse --show-toplevel)
      meatsfile="$rootdir/.meats"
      [[ -f "$meatsfile" ]] || touch "$meatsfile"
      cat "$meatsfile" | grep -v "^$kak_key" | tee "$meatsfile" 1>/dev/null
      cat "$meatsfile" | kak -f "ggi$kak_key::$kak_buffile:$kak_cursor_line:$kak_cursor_column<ret>" | tee "$meatsfile" 1>/dev/null
    }
    echo ::SAGE::
  }
}

define-command lick -override -docstring %{ prompt for a key to open a mark } %{
  info -style modal %sh{
    rootdir=$(git rev-parse --show-toplevel)
    meatsfile="$rootdir/.meats"
    printf "Pick your poison:\n"
    cat "$meatsfile" | xargs printf "%s\n"
  }
  on-key %{
    info -style modal
    eval %sh{
      rootdir=$(git rev-parse --show-toplevel)
      meatsfile="$rootdir/.meats"
      command=$(cat "$meatsfile" | grep -m 1 "^$kak_key" | kak -f 's.<plus>::<ret>dxs:<ret>r<space>')
      printf "edit $command\n"
      # printf "edit ~/.config/kak/kakrc 12 12"
    }
  }
}

# Register based commands

define-command lickR -override -docstring %{ save a meat to marks } %{
  info -style modal %sh{
    printf "Pick your poison:\n"
    reglines=$(cat << EOL
a :: $kak_reg_a
b :: $kak_reg_b
c :: $kak_reg_c
d :: $kak_reg_d
e :: $kak_reg_e
f :: $kak_reg_f
g :: $kak_reg_g
h :: $kak_reg_h
i :: $kak_reg_i
j :: $kak_reg_j
k :: $kak_reg_k
l :: $kak_reg_l
m :: $kak_reg_m
n :: $kak_reg_n
o :: $kak_reg_o
p :: $kak_reg_p
q :: $kak_reg_q
r :: $kak_reg_r
s :: $kak_reg_s
t :: $kak_reg_t
u :: $kak_reg_u
v :: $kak_reg_v
w :: $kak_reg_w
x :: $kak_reg_x
y :: $kak_reg_y
z :: $kak_reg_z
EOL
)
    echo "$reglines" | perl -n -e'/(\w) :: ([^@]+)@(\d+)@(\d+)/ && print "$1 :: $2 $3 $4\n"'
  }

  on-key %{
    info -style modal
    eval %sh{
      fuk=$(cat << EOL
a :: $kak_reg_a
b :: $kak_reg_b
c :: $kak_reg_c
d :: $kak_reg_d
e :: $kak_reg_e
f :: $kak_reg_f
g :: $kak_reg_g
h :: $kak_reg_h
i :: $kak_reg_i
j :: $kak_reg_j
k :: $kak_reg_k
l :: $kak_reg_l
m :: $kak_reg_m
n :: $kak_reg_n
o :: $kak_reg_o
p :: $kak_reg_p
q :: $kak_reg_q
r :: $kak_reg_r
s :: $kak_reg_s
t :: $kak_reg_t
u :: $kak_reg_u
v :: $kak_reg_v
w :: $kak_reg_w
x :: $kak_reg_x
y :: $kak_reg_y
z :: $kak_reg_z
EOL
)
  command=$(echo "$fuk" | grep -m 1 "^$kak_key" | perl -n -e'/(\w) :: ([^@]+)@(\d+)@(\d+)/ && print "$2 $3 $4"')
  echo "$command" | printf "edit $command"
    }
  }
}

define-command stabR -override -docstring %{ save a meat to marks } %{
  info -style modal "Stab!!!: "
  on-key %{
    info -style modal
    eval %sh{
      echo "$kak_key" | xargs printf 'exec \\"%sZ'
    }
  }
}

map global user m ":stab<ret>" -docstring "mark location"
map global user p ":peek<ret>" -docstring "view marks"
map global user M ":lick<ret>" -docstring "go to location"

