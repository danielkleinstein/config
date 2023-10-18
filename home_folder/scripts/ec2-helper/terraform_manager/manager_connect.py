"""Connect to an instance."""
import os
import subprocess  # nosec (remove bandit warning)

from terraform_manager.instance_configuration import LinuxDistro
from terraform_manager.manager_base import manager_path


def connect_instance_configuration_folder(name: str):
    """Connect to the given instance."""
    instance_path = os.path.join(manager_path(), f'ec2-{name}')

    if not os.path.exists(instance_path):
        raise ValueError(f'Folder "{instance_path}" does not exist')

    config_dir = os.path.join(instance_path, 'config')

    # Assert that the config dir exists
    if not os.path.exists(config_dir):
        raise ValueError(f'Config folder "{config_dir}" does not exist.')

    with open(os.path.join(config_dir, 'server_ip.txt'), encoding='utf-8') as server_ip_file:
        server_ip = server_ip_file.read().strip()

    with open(os.path.join(config_dir, 'server_key.txt'), encoding='utf-8') as server_key_file:
        server_key = server_key_file.read().strip()

    # Retrieve username based on config/distro
    with open(os.path.join(config_dir, 'distro'), encoding='utf-8') as distro_file:
        distro = distro_file.read().strip()
        if distro == LinuxDistro.AMAZON_LINUX.name:
            username = 'ec2-user'
        elif distro == LinuxDistro.UBUNTU.name:
            username = 'ubuntu'
        else:
            raise ValueError(f'Unexpected distro: {distro}')

    subprocess.run(['ssh',
                    '-i',
                    os.path.join(instance_path, server_key),
                    f'{username}@{server_ip}'], check=True)  # nosec (remove bandit warning)
