"""Connect to an instance."""
import os
import subprocess  # nosec (remove bandit warning)
from typing import Optional

from terraform_manager.instance_configuration import LinuxDistro
from terraform_manager.manager_base import terraform_folders_path


def update_ssh_config(username: str, instance_ip: str, private_key_path: str):
    config = f"""
Host EC2-Helper-{instance_ip}
    HostName {instance_ip}
    User {username}
    Port 22
    IdentityFile {private_key_path}
    StrictHostKeyChecking no
    """

    ssh_config_path = os.path.expanduser("~/.ssh/config")

    os.makedirs(os.path.dirname(ssh_config_path), exist_ok=True)

    # Write the configuration to the SSH config file
    with open(ssh_config_path, "a+") as file:
        file.seek(0)
        contents = file.read()

        if config not in contents:
            file.write(config)


def vscode_instance_configuration_folder(name: str, folder: Optional[str]):
    """Open VSCode remotely connected to the given instance."""
    instance_path = os.path.join(terraform_folders_path(), f"ec2-{name}")

    if not os.path.exists(instance_path):
        raise ValueError(f'Folder "{instance_path}" does not exist')

    config_dir = os.path.join(instance_path, "config")

    # Assert that the config dir exists
    if not os.path.exists(config_dir):
        raise ValueError(f'Config folder "{config_dir}" does not exist.')

    with open(
        os.path.join(config_dir, "server_ip.txt"), encoding="utf-8"
    ) as server_ip_file:
        server_ip = server_ip_file.read().strip()

    with open(
        os.path.join(config_dir, "server_key.txt"), encoding="utf-8"
    ) as server_key_file:
        server_key = server_key_file.read().strip()

    # Retrieve username based on config/distro
    with open(os.path.join(config_dir, "distro"), encoding="utf-8") as distro_file:
        distro = distro_file.read().strip()
        if distro == LinuxDistro.AMAZON_LINUX.name:
            username = "ec2-user"
        elif distro == LinuxDistro.UBUNTU.name:
            username = "ubuntu"
        else:
            raise ValueError(f"Unexpected distro: {distro}")

    if folder:
        folder = folder.replace(f"~", f"/home/{username}")
    else:
        folder = f"/home/{username}"

    update_ssh_config(username, server_ip, os.path.join(instance_path, server_key))
    subprocess.run(
        [
            "code",
            f"--folder-uri=vscode-remote://ssh-remote+EC2-Helper-{server_ip}{folder}",
        ],
        check=True,
    )  # nosec (remove bandit warning)
