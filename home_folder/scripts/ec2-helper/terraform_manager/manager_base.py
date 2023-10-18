"""Base functions for the terraform manager."""
import os


def base_path():
    """Return the path to the base folder of the ec2 script."""
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def manager_path():
    """Return the path to the managed folder, creating it if it doesn't exist."""
    manager_dir = os.path.join(base_path(), 'terraform_folders')

    if os.path.exists(manager_dir):
        if os.path.isfile(manager_dir):
            raise ValueError(f'"{manager_dir}" already exists, but it\'s a file, not a directory.')
    else:
        os.makedirs(manager_dir)

    return manager_dir
