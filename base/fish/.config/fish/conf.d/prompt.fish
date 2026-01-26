set -g rainbow_color_index 1
set -g rainbow_colors \
    '#55FF55' \
    '#33FFBB' \
    '#00DDFF' \
    '#3399FF' \
    '#5D5DFF' \
    '#AA55FF' \
    '#FF55FF' \
    '#FF77AA' \
    '#FF9999' \
    '#FF5555' \
    '#FF884D' \
    '#FFBB33' \
    '#FFFF55' \
    '#B6FF5D' \

set -g rainbow_color_count (count $rainbow_colors)

function fish_prompt
	set -g fish_prompt_pwd_dir_length 0 # No path shortening

	## INTERACTION
	# set -g fish_color_error reset
	# set -g fish_color_command $gold --bold
	# set -g fish_color_keyword reset
	# set -g fish_color_quote $iris
	# set -g fish_color_end $love
	# set -g fish_color_param reset
	# set -g fish_color_valid_path $foam --italics
	# set -g fish_color_option $muted

	## GIT
	set -g __fish_git_prompt_showupstream auto
	set -g __fish_git_prompt_show_informative_status 1
	set -g __fish_git_prompt_hide_untrackedfiles 1
	set -g __fish_git_prompt_color_branch --bold '#EB6F92'
	set -g __fish_git_prompt_showupstream "informative"
	set -g __fish_git_prompt_char_upstream_ahead ""
	set -g __fish_git_prompt_char_upstream_behind ""
	set -g __fish_git_prompt_char_upstream_prefix ""
	set -g __fish_git_prompt_char_stateseparator '|'
	set -g __fish_git_prompt_char_stagedstate "●"
	set -g __fish_git_prompt_char_dirtystate " "
	set -g __fish_git_prompt_char_untrackedfiles "…"
	set -g __fish_git_prompt_char_conflictedstate "✖"
	set -g __fish_git_prompt_char_cleanstate "✔"
	set -g __fish_git_prompt_color_dirtystate '#9ccfd8'
	set -g __fish_git_prompt_color_stagedstate '#f6c177'
	set -g __fish_git_prompt_color_invalidstate '#EB6F92'
	set -g __fish_git_prompt_color_untrackedfiles $fish_color_normal
	set -g __fish_git_prompt_color_cleanstate green --bold

	printf '%s' (set_color $fish_color_autosuggestion) (date '+%H:%M:%S')
    set_color reset

    set -g rainbow_color_index (math "$rainbow_color_index % $rainbow_color_count + 1")
    set -l rainbow_color $rainbow_colors[$rainbow_color_index]
	printf '%s ' (set_color $rainbow_color) $USER
    set_color reset

	printf '%s' (set_color --bold $fish_color_normal) (prompt_pwd)
    set_color reset

	printf '%s ' (fish_git_prompt)

    set_color reset
	printf '%s%s ' (set_color $fish_color_cwd) (set_color reset)
end
