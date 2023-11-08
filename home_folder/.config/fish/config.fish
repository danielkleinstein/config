if status is-interactive
    clear -x
end

alias .. "pushd .."
fish_add_path -aP ~/scripts
fish_add_path -aP ~/scripts
for dir in ~/scripts/*
    if test -d $dir
        fish_add_path -aP $dir
    end
end
fish_add_path ~/.local/bin
fish_add_path -aP /usr/sbin
fish_add_path -aP ~/.cargo/bin

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
            case application/x-bzip2
                tar xvjf $argv
            case application/x-gzip
                tar xvzf $argv
            case application/x-xz
                tar xvJf $argv
            case application/zip
                unzip $argv
            case 'application/vnd.ms-cab-compressed'
                cabextract $argv
            case application/x-tar
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
        if test "$cmd" != copy
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

function select-aws-profile
    if set -q argv[1]
        set -gx AWS_PROFILE $argv[1]
        # Check if the user is authenticated, and if not, run SSO login
        if not aws sts get-caller-identity >/dev/null 2>&1
            aws sso login
        end
        return
    end

    # Extract profiles from ~/.aws/config
    set profiles (grep '\[profile ' ~/.aws/config | sed -e 's/\[profile \(.*\)\]/\1/')

    # Determine the current AWS profile
    set current_profile $AWS_PROFILE

    # Highlight the current profile in the selection list
    for profile in $profiles
        if test "$profile" = "$current_profile"
            echo "* $profile" >>/tmp/aws_highlighted_profiles.txt
        else
            echo "  $profile" >>/tmp/aws_highlighted_profiles.txt
        end
    end

    # Use fzf to select a profile
    set selected_profile (cat /tmp/aws_highlighted_profiles.txt | fzf | string trim)
    rm /tmp/aws_highlighted_profiles.txt

    # Remove asterisk prefix if it exists
    set selected_profile (echo $selected_profile | sed 's/^\* //')

    # If a profile was selected, set it as the new AWS_PROFILE
    if test -n "$selected_profile"
        set -gx AWS_PROFILE $selected_profile
    end

    # Check if the user is authenticated, and if not, run SSO login
    if not aws sts get-caller-identity >/dev/null 2>&1
        aws sso login
    end
end

function select-eks-cluster
    set -l clusters (aws eks list-clusters | jq -r '.clusters[]')

    if not set -q clusters[1]
        echo "No EKS clusters found."
        return 1
    end

    set -l current_context (kubectl config current-context)

    for cluster in $clusters
        if test "$cluster" = "$current_context"
            echo "* $cluster" >>/tmp/eks_highlighted_clusters.txt
        else
            echo "  $cluster" >>/tmp/eks_highlighted_clusters.txt
        end
    end

    set -l selected_cluster (cat /tmp/eks_highlighted_clusters.txt | fzf | string trim)
    rm /tmp/eks_highlighted_clusters.txt

    set selected_cluster (echo $selected_cluster | sed 's/^\* //')

    if test -n "$selected_cluster"
        aws eks update-kubeconfig --name $selected_cluster
        echo "Switched to EKS cluster '$selected_cluster'."
    else
        echo "No EKS cluster selected."
        return 1
    end
end


set -x LESS_TERMCAP_mb (printf "\033[01;31m")
set -x LESS_TERMCAP_md (printf "\033[01;31m")
set -x LESS_TERMCAP_me (printf "\033[0m")
set -x LESS_TERMCAP_se (printf "\033[0m")
set -x LESS_TERMCAP_so (printf "\033[01;44;33m")
set -x LESS_TERMCAP_ue (printf "\033[0m")
set -x LESS_TERMCAP_us (printf "\033[01;32m")

alias k=kubectl
alias kns="kubectl config set-context --current --namespace"
alias kp="kubectl get pods"
alias kp-nodes="kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name"
alias kl="kubectl logs"
alias kaf="kubectl apply -f"

alias tf="terraform"
alias ti="terraform init"
alias ta="terraform apply"
alias taa="terraform apply -auto-approve"
alias td="terraform destroy"
alias tdd="terraform destroy -auto-approve"

if type -q bat
    alias cat="bat"
    alias catd="bat --paging=never"
end
alias catt="command cat"

alias man="tldr"
alias mann="command man"

alias first "awk '{print \$1}'"
alias second "awk '{print \$2}'"
alias third "awk '{print \$3}'"
alias fourth "awk '{print \$4}'"
alias fifth "awk '{print \$5}'"
alias sixth "awk '{print \$6}'"
alias seventh "awk '{print \$7}'"
alias eighth "awk '{print \$8}'"
alias ninth "awk '{print \$9}'"
alias tenth "awk '{print \$10}'"

function line
    if test (count $argv) -eq 1
        sed -n "$argv[1]p"
    else
        echo "Please provide a valid line number."
    end
end

alias linefirst "sed -n '1p'"
alias linesecond "sed -n '2p'"
alias linethird "sed -n '3p'"
alias linefourth "sed -n '4p'"
alias linefifth "sed -n '5p'"
alias linesixth "sed -n '6p'"
alias lineseventh "sed -n '7p'"
alias lineeighth "sed -n '8p'"
alias lineninth "sed -n '9p'"
alias linetenth "sed -n '10p'"

alias strip="awk '{\$1=\$1};1'"
alias trim="strip"

alias strip="awk '{\$1=\$1};1'"
alias trim="strip"

alias mkvenv='python3 -m venv venv; and source venv/bin/activate.fish'

function s3p --argument-names path
    # If an argument is provided, use it, otherwise read from stdin
    if test "$path"
        echo "s3://$path"
        return
    end
    while read -l input
        echo "s3://$input"
    end
end

function s3cat
    # If an argument is provided, use it, otherwise read from stdin
    if set -q $argv[1]
        set -f path $argv[1]
    else
        read -f path
    end

    # Check if the path starts with "s3://"
    if not echo $path | string match -q "s3://*"
        set path (echo $path | s3p)
    end

    # Use the AWS CLI to cat the file from the provided path
    aws s3 cp $path - | cat
end

function s3-concat-and-cat
    set -l s3_path "s3://"
    for i in (seq (count $argv))
        if [ $i -gt 1 ]
            set s3_path $s3_path/
        end
        set s3_path $s3_path$argv[$i]
    end

    # Use AWS CLI to cat the file from S3
    aws s3 cp $s3_path - | cat
end

function inner_s3ls
    set bucket $argv[1]

    if test -z "$bucket"
        aws s3 ls | awk '{for (i=3; i<NF; i++) printf $i " "; print $NF}'
    else
        aws s3 ls $bucket | awk '{for (i=4; i<NF; i++) printf $i " "; print $NF}'
    end
end

function s3ls --argument-names path
    # If an argument is provided, use it, otherwise read from stdin
    if test "$path"
        set -f path $argv[1]
    else
        # Check if stdin is connected to a terminal or has data
        if not command test -t 0
            while read -l input
                s3ls $input
            end
            return
        else
            # No argument and no stdin, run default command
            inner_s3ls
            return
        end
    end

    # Check if the path starts with "s3://"
    if not echo $path | string match -q "s3://*"
        set path (echo $path | s3p)
    end

    inner_s3ls $path
end

function last_history_item
    echo $history[1]
end

abbr -a !! --position anywhere --function last_history_item

function vim_edit
    echo vim $argv
end

abbr -a vim_edit_texts --position command --regex ".+\.txt|.+\.rs" --function vim_edit
abbr 4DIRS --set-cursor=! "$(string join \n -- 'for dir in */' 'cd $dir' '!' 'cd ..' 'end')"

kubectl completion fish | source
