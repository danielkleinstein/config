if status is-interactive
	clear -x
end

alias .. "pushd .."
fish_add_path -aP ~/scripts
fish_add_path ~/.local/bin
fish_add_path -aP /usr/sbin
fish_add_path -aP ~/.cargo/bin
fish_add_path "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
fish_add_path /opt/homebrew/opt/openjdk/bin
fish_add_path /Users/danielkleinstein/bin

function save_output
    set -l output_file /tmp/last_command_output
    eval $argv 2>&1 | tee $output_file
    cat $output_file | fish_clipboard_copy
    echo "Copied!"
end


function cdl
    cd (ls -td -- */ | head -n 1)
end

function mkcd
    if test "$argv" = ""
        echo -n "Directory name: "
        read dir
        mkdir -p $dir; and cd $dir
    else
        mkdir -p $argv; and cd $argv
    end
end

function ex
    if test -f $argv
        switch (file --mime-type $argv -b)
            case 'application/x-bzip2'
                tar xvjf $argv
            case 'application/x-gzip'
                tar xvzf $argv
            case 'application/x-xz'
                tar xvJf $argv
            case 'application/zip'
                unzip $argv
            case 'application/vnd.ms-cab-compressed'
                cabextract $argv
            case 'application/x-tar'
                tar xvf $argv
            case '*'
                echo "don't know how to extract '$argv'..."
        end
    else
        echo "'$argv' is not a valid file..."
    end
end

function please
    sudo $history[1]
end

function copy
    for cmd in (history)
        if test "$cmd" != "copy"
            save_output $cmd
            return
        end
    end
    echo "No non-'copy' command found in history"
end


function fd
    cd (find . -type d -name $argv | head -1)
end

function ff
    find . -type f -name $argv
end

function up
    if test "$argv" = ""
        cd ..
    else
        switch $argv
            case '*'
                cd (string repeat -n $argv '../')
        end
    end
end

function ppjson
    python -m json.tool $argv
end

function gcd
    cd (git rev-parse --show-toplevel)
end

function killport
    kill -9 (lsof -t -i tcp:$argv)
end

function clast
  history --max=1 | fish_clipboard_copy
end

function reload
    . ~/.config/fish/config.fish
end

function fish_prompt --description 'Write out the prompt'
                 set -l last_pipestatus $pipestatus
                 set -l normal (set_color normal)

                 # Color the prompt differently when we're root
                 set -l color_cwd $fish_color_cwd
                 set -l prefix
                 set -l suffix '>'
                 if contains -- $USER root toor
                     if set -q fish_color_cwd_root
                         set color_cwd $fish_color_cwd_root
                     end
                     set suffix '#'
                 end

                 # If we're running via SSH, change the host color.
                 set -l color_host $fish_color_host
                 if set -q SSH_TTY
                     set color_host $fish_color_host_remote
                 end

                 # Write pipestatus
                 set -l prompt_status (__fish_print_pipestatus " [" "]" "|" (set_color $fish_color_status) (set_color --bold $fish_color_status) $last_pipestatus)

                 echo -n -s (set_color $fish_color_user) $normal (set_color $color_cwd) (prompt_pwd) $normal (fish_vcs_prompt) $normal $prompt_status $suffix " "
end

set fish_greeting

function prompt_pwd --description 'Print the current working directory, shortened to fit the prompt'
                #set -l options h/help
                #argparse -n prompt_pwd --max-args=0 $options -- $argv
                #or return

                if set -q _flag_help
                    __fish_print_help prompt_pwd
                    return 0
                end

                # This allows overriding fish_prompt_pwd_dir_length from the outside (global or universal) without leaking it
                set -q fish_prompt_pwd_dir_length
                or set -l fish_prompt_pwd_dir_length 1

                # Replace $HOME with "~"
                set -l realhome /local/home/dkl
                set -l realhome2 ~
                set -l tmp (string replace -r '^'"$realhome"'($|/)' '~$1' $PWD)
                set -l tmp2 (string replace -r '^'"$realhome2"'($|/)' '~$1' $tmp)

                if [ $fish_prompt_pwd_dir_length -eq 0 ]
                    echo $tmp2
                else
                    # Shorten to at most $fish_prompt_pwd_dir_length characters per directory
                    string replace -ar '(\.?[^/]{'"$fish_prompt_pwd_dir_length"'})[^/]*/' '$1/' $tmp2
                end
end

set -x LESS_TERMCAP_mb (printf "\033[01;31m")  
set -x LESS_TERMCAP_md (printf "\033[01;31m")  
set -x LESS_TERMCAP_me (printf "\033[0m")  
set -x LESS_TERMCAP_se (printf "\033[0m")  
set -x LESS_TERMCAP_so (printf "\033[01;44;33m")  
set -x LESS_TERMCAP_ue (printf "\033[0m")  
set -x LESS_TERMCAP_us (printf "\033[01;32m")

if status --is-interactive
  eval (/opt/homebrew/bin/brew shellenv)
end

[ -f /opt/homebrew/share/autojump/autojump.fish ]; and source /opt/homebrew/share/autojump/autojump.fish

if [ -z "$TMUX" ]
	#tmux a -t main
end

source ~/.iterm2_shell_integration.fish

