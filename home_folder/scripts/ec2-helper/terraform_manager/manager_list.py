"""Lists all instances and their info."""
import dataclasses
import os
from typing import List

from terraform_manager.instance_configuration import InstanceConfiguration, LinuxDistro
from terraform_manager.manager_base import manager_path


@dataclasses.dataclass
class CreatedInstance:
    """Represents an instance that has been created."""

    name: str
    instance_configuration: InstanceConfiguration
    creation_time: str


def _read_config_dir(instance_name: str, config_dir: str) -> CreatedInstance:
    with open(os.path.join(config_dir, "region"), 'r', encoding='utf-8') as region_file:
        region = region_file.read().strip()
    with open(os.path.join(config_dir, "ami-id"), 'r', encoding='utf-8') as ami_file:
        ami = ami_file.read().strip()
    with open(os.path.join(config_dir, "instance-type"), 'r', encoding='utf-8') as instance_type_file:
        instance_type = instance_type_file.read().strip()
    with open(os.path.join(config_dir, "distro"), 'r', encoding='utf-8') as distro_file:
        distro_name = distro_file.read().strip()
        if distro_name == LinuxDistro.AMAZON_LINUX.name:
            distro = LinuxDistro.AMAZON_LINUX
        elif distro_name == LinuxDistro.UBUNTU.name:
            distro = LinuxDistro.UBUNTU
        else:
            raise ValueError(f'Unexpected distro {distro_name} in {config_dir}')
    with open(os.path.join(config_dir, "creation_time"), 'r', encoding='utf-8') as creation_time_file:
        creation_time = creation_time_file.read().strip()

    return CreatedInstance(
        name=instance_name,
        instance_configuration=InstanceConfiguration(
            region=region,
            ami=ami,
            instance_type=instance_type,
            distro=distro
        ),
        creation_time=creation_time
    )


def _configurations() -> List[CreatedInstance]:
    configurations = []

    base = manager_path()
    for instance_dir in os.listdir(base):
        instance_path = os.path.join(base, instance_dir)

        if os.path.isdir(instance_path):
            config_dir = os.path.join(instance_path, 'config')
            try:
                configurations.append(_read_config_dir(instance_dir, config_dir))
            except FileNotFoundError as e:
                print(f'Missing file {e.filename} in {config_dir}')

    return configurations


def list_instance_configuration_folder():
    """List all instances in the configuration folder."""
    configurations = _configurations()

    if not configurations:
        print("No instances found.")
        return

    for configuration in configurations:
        print(f'Instance "{configuration.name}":')
        print(f'    Region: {configuration.instance_configuration.region}')
        print(f'    AMI: {configuration.instance_configuration.ami}')
        print(f'    Instance type: {configuration.instance_configuration.instance_type}')
        print(f'    Distro: {configuration.instance_configuration.distro.name}')
        print(f'    Creation time: {configuration.creation_time}')
        print()
