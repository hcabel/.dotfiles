
# Directories
abbr .. 'cd ..'
abbr ... 'cd ../..'
abbr .2 'cd ../..'
abbr .... 'cd ../../..'
abbr .3 'cd ../../..'
abbr .4 'cd ../../../..'
abbr .5 'cd ../../../../..'

abbr lg 'lazygit'
abbr rm 'rm -rf'

# File system
alias ls='eza -lh --group-directories-first --icons=auto'
alias lsa='ls -a'
alias lt='eza --tree --level=2 --long --icons --git'
alias lta='lt -a'
alias ff="fzf --preview 'bat --style=numbers --color=always {}'"
function cd
    if test (count $argv) -eq 0
        builtin cd ~
    else if test (count $argv) -eq 1
        if test -d $argv[1]
            builtin cd $argv[1]
        else if test -d ~/.config/$argv[1]
            builtin cd ~/.config/$argv[1]
        else
            z $argv[1] && printf "\U00F17A9" && pwd || echo "Error: Directory not found"
        end
    else
        echo "Usage: cd [directory]"
    end
end

# Git
abbr g 'git'
alias gcm='git commit -m'
alias gcam='git commit -a -m'
alias gcad='git commit -a --amend'

zoxide init fish | source

alias ffmpeg='ffmpeg -hide_banner'
alias ffprobe='ffprobe -hide_banner'
alias ffplay='ffplay -hide_banner'

alias go='grc go'

function colast
    set commit_hash $(git log -n 1 --pretty=format:"%H")
    set commit_message $(git log -n 1 --pretty=format:"%s")
    git checkout $commit_hash > /dev/null 2>&1
    echo "Checked out commit: $commit_hash - $commit_message"
end

function bdiff
    git diff --no-index -- $argv[1] $argv[2]
end

# add value to env
set -gx PATH $HOME/.cargo/bin $PATH

function clear
    command clear
    fastfetch
    commandline -f repaint
end

bind \cl clear
