function __fish_ec2_needs_command
    set cmd (commandline -opc)
    if test (count $cmd) -eq 1
        return 0
    end
    return 1
end

function __fish_ec2_get_instances
    ec2 ls -n
end

complete -c ec2 -n __fish_ec2_needs_command -f -a create -d 'Create a new instance configuration.'
complete -c ec2 -n __fish_ec2_needs_command -f -a connect -d 'Connect to an instance.'
complete -c ec2 -n __fish_ec2_needs_command -f -a list -d 'List all instance configurations.'
complete -c ec2 -n __fish_ec2_needs_command -f -a ls -d 'List all instance configurations.'
complete -c ec2 -n __fish_ec2_needs_command -f -a destroy -d 'Destroy an instance configuration.'
complete -c ec2 -n __fish_ec2_needs_command -f -a vscode -d 'Open vscode to an instance.'

complete -c ec2 -n '__fish_seen_subcommand_from connect' -f -a '(__fish_ec2_get_instances)'
complete -c ec2 -n '__fish_seen_subcommand_from ssh' -f -a '(__fish_ec2_get_instances)'
complete -c ec2 -n '__fish_seen_subcommand_from destroy' -f -a '(__fish_ec2_get_instances)'
