"""Destroy an instance."""
import os
import shutil
import subprocess  # nosec (remove bandit warning)
import sys

from terraform_manager.manager_base import manager_path


def destroy_instance_configuration_folder(name: str):
    """Destroy the given instance."""
    instance_path = os.path.join(manager_path(), f'ec2-{name}')

    if not os.path.exists(instance_path):
        raise ValueError(f"Folder '{instance_path}' does not exist")

    with subprocess.Popen(['terraform', 'destroy', '-auto-approve'],  # nosec (remove bandit warning)
                          cwd=instance_path, stdout=subprocess.PIPE) as process:
        _, stderr = process.communicate()
        if process.returncode != 0:
            sys.stderr.write(stderr.decode('utf-8'))
            raise ValueError(f"terraform init failed in '{instance_path}'.")

    shutil.rmtree(instance_path)
