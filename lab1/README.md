# Lab 1: AWS CLI Scripts

These four scripts create and remove the test resources for Lab 1. They run on my EC2 workstation, which gets its AWS permissions from LabInstanceProfile, so no access keys are stored anywhere.

## create-security-group.sh
Looks up the public IP of the machine running the script using checkip.amazonaws.com, creates a security group called acs730-week1-sg, and adds one inbound rule that allows SSH (port 22) only from that single IP as a /32. It prints the new security group ID at the end.

## create-instance.sh
Gets the latest Amazon Linux 2023 AMI ID from AWS Systems Manager Parameter Store, then launches one t3.micro instance with LabInstanceProfile attached and a Name tag of acs730-week1. It prints the new instance ID.

## delete-instance.sh
Finds any instances tagged acs730-week1 that are pending, running or stopped, and terminates them. If none are found it prints "Nothing to delete." instead of failing, so it can be run more than once safely.

## delete-security-group.sh
Deletes the acs730-week1-sg security group by name and prints a confirmation. If the group was already deleted, AWS returns an error, so this script is meant to be run once after the instance is gone.
