# ────────────── commands ──────────────
define-command symbol-search -docstring "search for symbols in files in the current working directory" %{
  popup \
    --title 'symbol search' --on-err 'warn' \
    --kak-script %{evaluate-commands "edit %opt{popup_output}"} -- \
    kak-symbol-search --config %opt{symbol_search_config} --cache-dir "/tmp/kak-symbol-search/%val{session}"
}

# ────────────── mappings ──────────────
map global normal <c-r> ': symbol-search<ret>'

# ────────────── configuration ──────────────
declare-option str symbol_search_config %{
[fzf_settings]
preview_window = "70%"

[rust]
enum     = "(enum_item name: (type_identifier) @name)"
struct   = "(struct_item name: (type_identifier) @name)"
method   = "(declaration_list (function_item name: (identifier) @name))"
function = "(function_item name: (identifier) @name)"
impl     = "(impl_item type: (type_identifier) @name)"
macro    = "(macro_definition name: (identifier) @name)"
module   = "(mod_item name: (identifier) @name)"
trait    = "(trait_item name: (type_identifier) @name)"
type     = "(type_item name: (type_identifier) @name)"

[odin]
enum     = "(enum_type name: (identifier) @name)"
struct   = "(struct_type name: (identifier) @name)"
method   = "(method_declaration name: (identifier) @name)"
function = "(function_declaration name: (identifier) @name)"
module   = "(package_declaration name: (identifier) @name)"
type     = "(type_declaration name: (identifier) @name)"

[python]
function = "(function_definition name: (identifier) @name)"
class = "(class_definition name: (identifier) @name)"

[typescript]
class = "(class_declaration name: (type_identifier) @name)"
method = "(method_signature name: (property_identifier) @name)"
function = [
  "(function_declaration name: (identifier))",
  "(program (lexical_declaration (variable_declarator name: (identifier) @name value: (arrow_function))))",
]
constant = "(variable_declarator name: (identifier) @name )"



[haskell]
type = [
  "(type_synomym name: (name) @name)",
  "(data_type name: (name) @name)",
]
function = "(haskell declarations: (declarations (signature name: (variable) @function.name)))"

}
