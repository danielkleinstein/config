"""Encapsulates logic for retrieving user configuration of an EC2 instance."""
from typing import Optional, Tuple
import boto3
import dataclasses
import enum
import subprocess  # nosec (remove bandit warning)


class LinuxDistro(enum.Enum):
    """Represents a Linux distribution."""

    AMAZON_LINUX = "Amazon Linux"
    UBUNTU = "Ubuntu"


class CpuArchitecture(enum.Enum):
    """Represents a CPU architecture."""

    X86_64 = "x86_64"
    ARM64 = "arm64"

    @staticmethod
    def from_aws_architecture(aws_arch: str) -> "CpuArchitecture":
        """Return the CpuArchitecture corresponding to the given AWS architecture."""
        if aws_arch == "x86_64":
            return CpuArchitecture.X86_64
        if aws_arch == "arm64":
            return CpuArchitecture.ARM64
        raise ValueError(f"Unexpected AWS architecture: {aws_arch}")


@dataclasses.dataclass
class InstanceConfiguration:
    """Represents the configuration needed to create an EC2 instance."""

    region: str
    ami: str
    instance_type: str
    distro: LinuxDistro


def fzf_select(options, header=""):
    """Return the option selected by the user using fzf."""
    with subprocess.Popen(
        ["fzf", "--header=" + header],  # nosec (remove bandit warning)
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
    ) as process:
        stdout, _ = process.communicate(input="\n".join(options).encode("utf-8"))
    return stdout.decode("utf-8").strip()


def _instance_configuration_region(ec2_client, chosen_region: Optional[str]) -> str:
    regions = [
        region["RegionName"] for region in ec2_client.describe_regions()["Regions"]
    ]

    if chosen_region:
        if chosen_region not in regions:
            raise ValueError(
                f'Region "{chosen_region}" not found in AWS regions {regions}'
            )
        return chosen_region

    # Make us-east-1 the top choice
    priority_region = "us-east-1"
    regions = [priority_region] + [
        region for region in regions if region != priority_region
    ]
    selected_region = fzf_select(regions, "Select an AWS region:") or priority_region

    return selected_region


def _get_all_instance_types(ec2_client):
    paginator = ec2_client.get_paginator("describe_instance_types")
    iterator = paginator.paginate()

    instance_types = []

    for page in iterator:
        for it in page["InstanceTypes"]:
            if it["InstanceType"].startswith(("c", "m", "t")):
                instance_types.append(it)

    return instance_types


def _instance_configuration_instance_type(
    ec2_client, chosen_instance_type: Optional[str]
) -> Tuple[str, CpuArchitecture]:
    instance_types = _get_all_instance_types(ec2_client)

    available_instance_types = [it["InstanceType"] for it in instance_types]

    if chosen_instance_type:
        if chosen_instance_type not in available_instance_types:
            raise ValueError(
                f'Instance type "{chosen_instance_type}" not found in available instance types '
                f"{sorted(available_instance_types)}"
            )

        # Fetch the architecture
        chosen_instance_architecture = [
            it["ProcessorInfo"]["SupportedArchitectures"][0]
            for it in instance_types
            if it["InstanceType"] == chosen_instance_type
        ][0]
        return chosen_instance_type, CpuArchitecture.from_aws_architecture(
            chosen_instance_architecture
        )

    instance_details = [
        f'{it["InstanceType"]} - {it["VCpuInfo"]["DefaultVCpus"]} vCPUs, {it["MemoryInfo"]["SizeInMiB"]/1024} GiB RAM'
        for it in instance_types
    ]
    chosen_instance_desc = fzf_select(sorted(instance_details))
    chosen_instance = chosen_instance_desc.split("-", maxsplit=1)[0].strip()

    chosen_instance_architecture = [
        it["ProcessorInfo"]["SupportedArchitectures"][0]
        for it in instance_types
        if it["InstanceType"] == chosen_instance
    ][0]

    return chosen_instance, CpuArchitecture.from_aws_architecture(
        chosen_instance_architecture
    )


def _instance_configuration_ami(
    ec2_client,
    chosen_distro: Optional[str],
    chosen_instance_architecture: CpuArchitecture,
) -> Tuple[str, LinuxDistro]:
    # Get the Amazon Linux AMI
    response = ec2_client.describe_images(
        Owners=["amazon"],
        Filters=[
            {
                "Name": "description",
                "Values": ["Amazon Linux 2023 AMI 2023* x86_64 HVM kernel-6.1"],
            }
        ],
    )
    amazon_linux_ami = sorted(
        response["Images"], key=lambda x: x["CreationDate"], reverse=True
    )[0]["ImageId"]

    # Get the Ubuntu AMI
    response = ec2_client.describe_images(
        Owners=["amazon"],
        Filters=[{"Name": "description", "Values": ["*Ubuntu*22.04*LTS*"]}],
    )

    ubuntu_images = [
        img
        for img in response["Images"]
        if "UNSUPPORTED" not in img["Description"]
        and "Pro" not in img["Description"]
        and "Minimal" not in img["Description"]
        and img["Architecture"] == chosen_instance_architecture.value
    ]
    ubuntu_ami = sorted(ubuntu_images, key=lambda x: x["CreationDate"], reverse=True)[
        0
    ]["ImageId"]

    if chosen_distro:
        if chosen_distro == "ubuntu":
            return (ubuntu_ami, LinuxDistro.UBUNTU)
        if chosen_distro == "amazon-linux":
            return (amazon_linux_ami, LinuxDistro.AMAZON_LINUX)
        raise ValueError(f"Unexpected distro: {chosen_distro}")

    ami_options = [f"Amazon Linux AMI: {amazon_linux_ami}", f"Ubuntu AMI: {ubuntu_ami}"]
    chosen_ami_desc = fzf_select(ami_options)
    if "Amazon Linux" in chosen_ami_desc:
        distro = LinuxDistro.AMAZON_LINUX
    elif "Ubuntu" in chosen_ami_desc:
        distro = LinuxDistro.UBUNTU
    else:
        raise ValueError(f"Unexpected AMI description: {chosen_ami_desc}")

    chosen_ami = chosen_ami_desc.rsplit(":", maxsplit=1)[-1].strip()

    return (chosen_ami, distro)


def instance_configuration(
    chosen_region: Optional[str],
    chosen_distro: Optional[str],
    chosen_instance_type: Optional[str],
) -> InstanceConfiguration:
    """Return an InstanceConfiguration object with the settings chosen by the user."""
    session = boto3.session.Session()
    ec2_client = session.client("ec2")

    region = _instance_configuration_region(ec2_client, chosen_region)
    ec2_client_in_region = session.client("ec2", region_name=region)

    # It's important to choose the instance type before the AMI - so that we find an AMI matching the instance
    # type's architecture
    (
        chosen_instance,
        chosen_instance_architecture,
    ) = _instance_configuration_instance_type(
        ec2_client_in_region, chosen_instance_type
    )
    ami, distro = _instance_configuration_ami(
        ec2_client_in_region, chosen_distro, chosen_instance_architecture
    )

    return InstanceConfiguration(
        region=region, ami=ami, instance_type=chosen_instance, distro=distro
    )
