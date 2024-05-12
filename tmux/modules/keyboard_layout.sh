show_keyboard_layout() {
  local index=$1
  local icon="$(get_tmux_option "@catppuccin_keyboard_layout_icon" "󰥻")"
  local color="$(get_tmux_option "@catppuccin_keyboard_layout_color" "$thm_blue")"
  local text="$(get_tmux_option "@catppuccin_keyboard_layout_text" "#(keyboard_layout)")"

  local module=$(build_status_module "$index" "$icon" "$color" "$text")

  echo "$module"
}
