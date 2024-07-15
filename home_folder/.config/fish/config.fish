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

function fish_right_prompt
    # Colors
    set -l color_time (set_color $fish_color_autosuggestion 2>/dev/null; or set_color 555)
    set -l color_aws (set_color purple)
    set -l color_k8s (set_color cyan)
    set -l color_k8s_namespace (set_color yellow)
    set -l normal (set_color normal)

    # Time
    set -l time_val (date '+%H:%M:%S')
    set -l time "$color_time$time_val$normal"

    # AWS Profile
    set -l aws_profile
    if set -q AWS_PROFILE
        set aws_profile "$color_aws$AWS_PROFILE$normal"
    end

    # Kubernetes Cluster and Namespace
    set -l k8s_info
    set -l k8s_context (kubectl config current-context 2>/dev/null)
    set -l k8s_namespace (kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)

    # Extract just the cluster name if it's an ARN
    set -l regex 'arn:aws:eks:[^:]+:[^:]+:cluster\/(.+)'
    if string match -r $regex $k8s_context >/dev/null
        set k8s_context (string match -r $regex $k8s_context)[2]
    end

    if test -n "$k8s_context"
        set k8s_info "$color_k8s$k8s_context"
        if test -n "$k8s_namespace"
            set k8s_info "$k8s_info/$color_k8s_namespace$k8s_namespace"
        end
        set k8s_info "$k8s_info$normal"
    end

    # Combine components
    set -l right_prompt
    if test -n "$aws_profile"; or test -n "$k8s_info"
        set right_prompt "$aws_profile $k8s_info | $time"
    else
        set right_prompt $time
    end

    echo $right_prompt
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

function select-git-branch
    if set -q argv[1]
        git checkout $argv[1]
        return
    end

    set branches (git branch | sed 's/\*//g' | sed 's/ //g')
    set current_branch (git branch --show-current)

    # Highlight the current branch in the selection list
    for branch in $branches
        if test "$branch" = "$current_branch"
            echo "* $branch" >>/tmp/branches.txt
        else
            echo "  $branch" >>/tmp/branches.txt
        end
    end

    # Use fzf to select a profile
    set selected_branch (cat /tmp/branches.txt | fzf | string trim)
    rm /tmp/branches.txt

    # Remove asterisk prefix if it exists
    set selected_branch (echo $selected_branch | sed 's/^\* //')

    if test -n "$selected_branch"
        git checkout $selected_branch
    end
end

function select-eks-cluster
    set current_context (kubectl config current-context 2>/dev/null)

    set clusters (aws eks list-clusters --output text --query 'clusters[*]' | tr "\t" "\n")

    echo -n "" >/tmp/eks_highlighted_clusters.txt

    for cluster in $clusters
        set cluster_arn (aws eks describe-cluster --name $cluster --query 'cluster.arn' --output text)

        if test "$current_context" = "$cluster_arn"
            echo "* $cluster" >>/tmp/eks_highlighted_clusters.txt
        else
            echo "  $cluster" >>/tmp/eks_highlighted_clusters.txt
        end
    end

    set selected_cluster (cat /tmp/eks_highlighted_clusters.txt | fzf | string trim)
    rm /tmp/eks_highlighted_clusters.txt

    set selected_cluster (string replace -r '^\* ' '' -- $selected_cluster)

    if test -n "$selected_cluster"
        aws eks update-kubeconfig --name $selected_cluster >/dev/null
        echo "Switched to EKS cluster: $selected_cluster"
    else
        echo "No cluster was selected."
    end
end

function select-k8s-namespace
    set namespaces (kubectl get namespaces --no-headers -o custom-columns=":metadata.name")

    echo -n "" >/tmp/k8s_namespaces.txt

    for ns in $namespaces
        echo $ns >>/tmp/k8s_namespaces.txt
    end

    set selected_namespace (cat /tmp/k8s_namespaces.txt | fzf | string trim)
    rm /tmp/k8s_namespaces.txt

    if test -n "$selected_namespace"
        kubectl config set-context --current --namespace=$selected_namespace >/dev/null
        echo "Switched to namespace: $selected_namespace"
    else
        echo "No namespace was selected."
    end
end

set -x EDITOR vim
set -x LESS_TERMCAP_mb (printf "\033[01;31m")
set -x LESS_TERMCAP_md (printf "\033[01;31m")
set -x LESS_TERMCAP_me (printf "\033[0m")
set -x LESS_TERMCAP_se (printf "\033[0m")
set -x LESS_TERMCAP_so (printf "\033[01;44;33m")
set -x LESS_TERMCAP_ue (printf "\033[0m")
set -x LESS_TERMCAP_us (printf "\033[01;32m")

alias k=kubectl
alias mk="kubectl config use-context minikube"
alias kn="kubectl get nodes"
alias kp="kubectl get pods"
alias kp-nodes="kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name"
alias kl="kubectl logs"
alias kaf="kubectl apply -f"
alias kn="kubectl config set-context --current --namespace"
alias kgd="kubectl get deployments.apps"
alias kgds="kubectl get daemonsets.apps"
alias kgp="kubectl get pods"
alias kgn="kubectl get nodes"
alias kg="kubectl get"
alias kd="kubectl describe"
alias kdn="kubectl describe node"
alias kgs="kubectl get svc"
alias kdes="kubectl delete svc"
alias kdp="kubectl describe pod"

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
abbr 4DIRS --set-cursor=! "(string join \n -- 'for dir in */' 'cd $dir' '!' 'cd ..' 'end')"

kubectl completion fish | source

function export-aws-creds -d "Export AWS credentials from aws sts assume-role output"
    set -l json_output $argv

    if test -z "$json_output"
        echo "Please provide the JSON output from the 'aws sts assume-role' command."
        return
    end

    set -l access_key_id (echo $json_output | jq -r '.Credentials.AccessKeyId')
    set -l secret_access_key (echo $json_output | jq -r '.Credentials.SecretAccessKey')
    set -l session_token (echo $json_output | jq -r '.Credentials.SessionToken')

    set -g -x AWS_ACCESS_KEY_ID $access_key_id
    set -g -x AWS_SECRET_ACCESS_KEY $secret_access_key
    set -g -x AWS_SESSION_TOKEN $session_token

    echo "AWS credentials exported successfully."
end

function unset-aws-creds
    set -e AWS_ACCESS_KEY_ID
    set -e AWS_SECRET_ACCESS_KEY
    set -e AWS_SESSION_TOKEN
end

function stash-aws-creds
    set -gx STASHED_AWS_ACCESS_KEY_ID $AWS_ACCESS_KEY_ID
    set -gx STASHED_AWS_SECRET_ACCESS_KEY $AWS_SECRET_ACCESS_KEY
    set -gx STASHED_AWS_SESSION_TOKEN $AWS_SESSION_TOKEN
    unset-aws-creds
end

function pop-aws-creds
    set -gx AWS_ACCESS_KEY_ID $STASHED_AWS_ACCESS_KEY_ID
    set -gx AWS_SECRET_ACCESS_KEY $STASHED_AWS_SECRET_ACCESS_KEY
    set -gx AWS_SESSION_TOKEN $STASHED_AWS_SESSION_TOKEN
end

alias aws-whoami="aws sts get-caller-identity"

function git-cleanup-branches
    # Ensure we are in a git repository
    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "This is not a git repository."
        return 1
    end

    # Fetch latest changes
    git fetch origin

    # Get all branches except the current one
    set -l branches (git branch | string trim | string replace '*' '')

    for branch in $branches
        # Allow Ctrl+C to interrupt the function
        function handle_cancel --on-signal SIGINT
            echo "Interrupted. Exiting..."
            functions --erase handle_cancel
            return 1
        end

        # Check if the branch is merged into main
        if git branch --merged main | string match -q "$branch"
            echo "Deleting merged branch: $branch"
            git branch -d $branch
        else
            echo "Branch '$branch' is not merged into main. Delete? [y/N]"
            read -l confirm
            switch $confirm
                case Y y
                    git branch -D $branch > /dev/null
            end
        end

        # Remove the signal handler after processing each branch
        functions --erase handle_cancel
    end
end
