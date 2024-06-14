show_open_pr_count() {
	local index=$1
	local icon="$(get_tmux_option "@catppuccin_keyboard_layout_icon" "")"
	local color="$(get_tmux_option "@catppuccin_keyboard_layout_color" "$thm_blue")"
	local text="$(get_tmux_option "@catppuccin_keyboard_layout_text" "#(tmux_pr_count --cwd=\"#{pane_current_path}\")")"

	local module=$(build_status_module "$index" "$icon" "$color" "$text")

	echo "$module"
}
