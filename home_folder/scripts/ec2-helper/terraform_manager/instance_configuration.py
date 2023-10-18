"""Encapsulates logic for retrieving user configuration of an EC2 instance."""
import boto3
import dataclasses
import subprocess  # nosec (remove bandit warning)


@dataclasses.dataclass
class InstanceConfiguration:
    """Represents the configuration needed to create an EC2 instance."""

    region: str
    ami: str
    instance_type: str


def _fzf_select(options, header=""):
    with subprocess.Popen(['fzf', '--header=' + header],  # nosec (remove bandit warning)
                          stdin=subprocess.PIPE, stdout=subprocess.PIPE) as process:
        stdout, _ = process.communicate(input="\n".join(options).encode('utf-8'))
    return stdout.decode('utf-8').strip()


def _instance_configuration_region(ec2_client) -> str:
    regions = [region['RegionName'] for region in ec2_client.describe_regions()['Regions']]

    # Make us-east-1 the top choice
    priority_region = "us-east-1"
    regions = [priority_region] + [region for region in regions
                                   if region != priority_region]
    selected_region = _fzf_select(regions, "Select an AWS region:") \
        or priority_region

    return selected_region


def _instance_configuration_ami(ec2_client) -> str:
    # Get the Amazon Linux AMI
    response = ec2_client.describe_images(
        Owners=['amazon'],
        Filters=[{"Name": "description", "Values": ["Amazon Linux 2023 AMI 2023* x86_64 HVM kernel-6.1"]}]
    )
    amazon_linux_ami = sorted(response['Images'], key=lambda x: x['CreationDate'], reverse=True)[0]['ImageId']

    # Get the Ubuntu AMI
    response = ec2_client.describe_images(
        Owners=['amazon'],
        Filters=[{"Name": "description", "Values": ["*Ubuntu*22.04*LTS*"]}]
    )

    ubuntu_images = [img for img in response['Images'] if 'UNSUPPORTED' not in img['Description']
                     and 'Pro' not in img['Description'] and 'Minimal' not in img['Description']]
    ubuntu_ami = sorted(ubuntu_images, key=lambda x: x['CreationDate'], reverse=True)[0]['ImageId']

    ami_options = [f"Amazon Linux AMI: {amazon_linux_ami}", f"Ubuntu AMI: {ubuntu_ami}"]
    chosen_ami_desc = _fzf_select(ami_options)
    chosen_ami = chosen_ami_desc.rsplit(':', maxsplit=1)[-1].strip()

    return chosen_ami


def _instance_configuration_instance_type(ec2_client) -> str:
    response = ec2_client.describe_instance_types()
    instance_types = [
        it for it in response['InstanceTypes']
        if it['InstanceType'].startswith('c') or it['InstanceType'].startswith('m')
    ]
    instance_details = [
        f"{it['InstanceType']} - {it['VCpuInfo']['DefaultVCpus']} vCPUs, {it['MemoryInfo']['SizeInMiB']/1024} GiB RAM"
        for it in instance_types
    ]
    chosen_instance_desc = _fzf_select(sorted(instance_details))
    chosen_instance = chosen_instance_desc.split('-', maxsplit=1)[0].strip()

    return chosen_instance


def instance_configuration() -> InstanceConfiguration:
    """Return an InstanceConfiguration object with the settings chosen by the user."""
    session = boto3.session.Session()
    ec2_client = session.client('ec2')

    region = _instance_configuration_region(ec2_client)
    ec2_client_in_region = session.client('ec2', region_name=region)

    ami = _instance_configuration_ami(ec2_client_in_region)
    chosen_instance = _instance_configuration_instance_type(ec2_client_in_region)

    return InstanceConfiguration(region=region, ami=ami, instance_type=chosen_instance)
