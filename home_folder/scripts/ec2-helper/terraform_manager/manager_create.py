"""Manages the folder of terraform folders corresponding to created EC2 instances."""
import os
import shutil
import subprocess  # nosec (remove bandit warning)
import sys
import time

from terraform_manager.instance_configuration import InstanceConfiguration
from terraform_manager.manager_base import base_path, manager_path
from terraform_manager.manager_connect import connect_instance_configuration_folder


def _create_config_folder(instance_path: str, instance_config: InstanceConfiguration):
    # Create config folder if it doesn't exist
    config_dir = os.path.join(instance_path, 'config')
    if not os.path.exists(config_dir):
        os.makedirs(config_dir)

    # Create "config/server_key.txt" based on terraform output
    with open(os.path.join(config_dir, 'server_key.txt'), 'w', encoding='utf-8') as key_name_file:
        with subprocess.Popen(['terraform', 'output', 'server_key'],  # nosec (remove bandit warning)
                              cwd=instance_path, stdout=subprocess.PIPE) as process:
            stdout, stderr = process.communicate()
            if process.returncode != 0:
                sys.stderr.write(stderr.decode('utf-8'))
                raise ValueError(f'terraform init failed in "{instance_path}".')

        key_name = stdout.decode('utf-8').strip().strip('"')

        subprocess.run(['chmod', '400', os.path.join(instance_path, key_name)],  # nosec (remove bandit warning)
                       check=True)

        key_name_file.write(key_name)

    # Create "config/server_ip.txt" based on terraform output
    with open(os.path.join(config_dir, 'server_ip.txt'), 'w', encoding='utf-8') as ip_file:
        with subprocess.Popen(['terraform', 'output', 'server_ip'],  # nosec (remove bandit warning)
                              cwd=instance_path, stdout=subprocess.PIPE) as process:
            stdout, stderr = process.communicate()
            if process.returncode != 0:
                sys.stderr.write(stderr.decode('utf-8'))
                raise ValueError(f'terraform output failed in "{instance_path}".')
        ip_file.write(stdout.decode('utf-8').strip().strip('"'))

    # Create config/distro based on instance_config
    with open(os.path.join(config_dir, 'distro'), 'w', encoding='utf-8') as distro_file:
        distro_file.write(instance_config.distro.name)

    # Create config/instance_type based on instance_config
    with open(os.path.join(config_dir, 'instance_type'), 'w', encoding='utf-8') as instance_type_file:
        instance_type_file.write(instance_config.instance_type)

    # Create config/region based on instance_config
    with open(os.path.join(config_dir, 'region'), 'w', encoding='utf-8') as instance_type_file:
        instance_type_file.write(instance_config.region)

    # Create config/ami-id based on instance_config
    with open(os.path.join(config_dir, 'ami-id'), 'w', encoding='utf-8') as instance_type_file:
        instance_type_file.write(instance_config.ami)

    # Create config/creation_date based on the current date
    with open(os.path.join(config_dir, 'creation_date'), 'w', encoding='utf-8') as date_file:
        date_file.write(time.strftime('%Y-%m-%d %H:%M:%S'))


def create_instance_configuration_folder(name: str, aws_account_id: str, instance_config: InstanceConfiguration):
    """Create a folder for the given instance configuration."""
    instance_path = os.path.join(manager_path(), f'ec2-{name}')

    if os.path.exists(instance_path):
        raise ValueError(f"Folder '{instance_path}' already exists.")

    os.makedirs(instance_path)

    with open(os.path.join(base_path(), 'ec2-terraform-template.tf'), encoding='utf-8') as terraform_file:
        terraform_contents = terraform_file.read()

    terraform_contents = terraform_contents.replace('$NAME', name)
    terraform_contents = terraform_contents.replace('$REGION', instance_config.region)
    terraform_contents = terraform_contents.replace('$AMI', instance_config.ami)
    terraform_contents = terraform_contents.replace('$INSTANCE_TYPE', instance_config.instance_type)
    terraform_contents = terraform_contents.replace('$ACCOUNT', aws_account_id)

    with open(os.path.join(instance_path, 'main.tf'), 'w', encoding='utf-8') as instance_file:
        instance_file.write(terraform_contents)
    shutil.copy2(os.path.join(base_path(), 'ec2-terraform-template-user-data.sh'), instance_path)

    # Run terraform init and terraform apply in the instance folder
    with subprocess.Popen(['terraform', 'init'],  # nosec (remove bandit warning)
                          cwd=instance_path, stdout=subprocess.PIPE) as process:
        _, stderr = process.communicate()
        if process.returncode != 0:
            sys.stderr.write(stderr.decode('utf-8'))
            raise ValueError(f'terraform init failed in "{instance_path}".')

    with subprocess.Popen(['terraform', 'apply', '-auto-approve'],  # nosec (remove bandit warning)
                          cwd=instance_path, stdout=subprocess.PIPE) as process:
        _, stderr = process.communicate()
        if process.returncode != 0:
            sys.stderr.write(stderr.decode('utf-8'))
            raise ValueError(f'terraform apply failed in "{instance_path}".')

    _create_config_folder(instance_path, instance_config)

    time.sleep(10)
    connect_instance_configuration_folder(name)
