import boto3
import dataclasses
import json
import os
import subprocess
import sys

from typing import List, Optional

from .instance_configuration import LinuxDistro, fzf_select
from .manager_base import manager_path, terraform_folders_path


@dataclasses.dataclass
class SyncInstanceConfiguration:
    name: Optional[str]
    instance_id: str
    instance_type: str
    region: str
    public_ip: Optional[str]
    distro: str

    # String
    def __str__(self):
        return f"{self.name or '<No Name>'} ({self.instance_type}, {self.public_ip}) ({self.instance_id})"


def _retrieve_instance_configurations(
    region: Optional[str]
) -> List[SyncInstanceConfiguration]:
    if region:
        ec2 = boto3.resource("ec2", region_name=region)
        ec2_client = boto3.client("ec2", region_name=region)
    else:
        ec2 = boto3.resource("ec2")
        ec2_client = boto3.client("ec2")

    # Retrieve all EC2 instances that are active
    instances = ec2.instances.filter(
        Filters=[{"Name": "instance-state-name", "Values": ["running"]}]
    )

    configurations = []
    for instance in instances:
        # For each instance, print its ID, type, and name
        # The name is a tag with the key "Name"
        name = ""
        if instance.tags:
            name_tag = [tag["Value"] for tag in instance.tags if tag["Key"] == "Name"]
            if name_tag:
                name = name_tag[0]

        if instance.image_id:
            image = ec2_client.describe_images(ImageIds=[instance.image_id])["Images"][
                0
            ]
            description = image.get("Description", "").lower()
            if "ubuntu" in description:
                distro = "Ubuntu"
            elif "amzn" in description or "amazon linux" in description:
                distro = "Amazon Linux"
            elif "kubernetes worker ami" in description:
                distro = "EKS AMI"
            else:
                distro = f"Unknown - {description}"

        configurations.append(
            SyncInstanceConfiguration(
                name=name,
                instance_id=instance.id,
                instance_type=instance.instance_type,
                region=instance.placement["AvailabilityZone"][:-1],
                public_ip=instance.public_ip_address,
                distro=distro,
            )
        )

    return configurations


def sync_ec2_instances(region: Optional[str]):
    instance_configurations = _retrieve_instance_configurations(region)

    instance_configurations.sort(key=lambda x: not x.name)

    selected_config = fzf_select([str(x) for x in instance_configurations])

    if not selected_config:
        return

    selected_config = [x for x in instance_configurations if str(x) == selected_config][
        0
    ]

    if not selected_config.name:
        raise Exception("TODO")

    # terraformer import aws --resources=ec2_instance --filter="Name=id;Value=i-0450bdd70834f2294" --regions=us-east-1 --profile=deployment-tests --compact --path-output test --path-pattern "{output}/"
    with subprocess.Popen(
        [
            "terraformer",
            "import",
            "aws",
            "--resources=ec2_instance",
            f"--filter=Name=id;Value={selected_config.instance_id}",
            f"--profile={os.environ['AWS_PROFILE']}",
            "--compact",
            "--path-pattern",
            f"{terraform_folders_path()}/ec2-{selected_config.name}",
        ],
        cwd=manager_path(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ) as process:
        _, stderr = process.communicate()
        if process.returncode != 0:
            sys.stderr.write(stderr.decode("utf-8"))
            raise ValueError("Terraformer failed.")

    # terraform state replace-provider -auto-approve "registry.terraform.io/-/aws" "hashicorp/aws"
    with subprocess.Popen(
        [
            "terraform",
            "state",
            "replace-provider",
            "-auto-approve",
            "registry.terraform.io/-/aws",
            "hashicorp/aws",
        ],
        cwd=os.path.join(terraform_folders_path(), f"ec2-{selected_config.name}"),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ) as process:
        _, stderr = process.communicate()
        if process.returncode != 0:
            sys.stderr.write(stderr.decode("utf-8"))
            raise ValueError("Terraform state replace-provider failed.")

    with subprocess.Popen(
        ["terraform", "init"],
        cwd=os.path.join(terraform_folders_path(), f"ec2-{selected_config.name}"),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ) as process:
        _, stderr = process.communicate()
        if process.returncode != 0:
            sys.stderr.write(stderr.decode("utf-8"))
            raise ValueError("Terraform init failed.")

    with subprocess.Popen(
        ["terraform", "validate", "-json"],
        cwd=os.path.join(terraform_folders_path(), f"ec2-{selected_config.name}"),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ) as process:
        terraform_validate_output, stderr = process.communicate()
        if stderr:
            sys.stderr.write(stderr.decode("utf-8"))
            raise ValueError("Terraform validate failed.")

    terraform_validate_json = json.loads(terraform_validate_output.decode("utf-8"))

    line_numbers = [
        diagnostic["range"]["start"]["line"]
        for diagnostic in terraform_validate_json.get("diagnostics", [])
        if "range" in diagnostic and "start" in diagnostic["range"]
    ]

    # Remove line numbers from the 'resources.tf' file:
    with open(
        os.path.join(
            terraform_folders_path(), f"ec2-{selected_config.name}", "resources.tf"
        ),
        "r",
        encoding="utf-8",
    ) as resources_file:
        resources_contents = resources_file.read()

    resources_lines = resources_contents.split("\n")
    resources_lines = [
        line
        for line_number, line in enumerate(resources_lines, start=1)
        if line_number not in line_numbers
    ]

    with open(
        os.path.join(
            terraform_folders_path(), f"ec2-{selected_config.name}", "resources.tf"
        ),
        "w",
        encoding="utf-8",
    ) as resources_file:
        resources_file.write("\n".join(resources_lines))
