# Blast-radius test setup

This repo is automated through a Github workflow.
To replicate this, please populate the necessary env variables for Terraform as Github secrets:
- AWS_ACCESS_KEY_ID
- AWS_ECRET_KEY_ID
- AWS_REGION
The code deploys an EC2 instance with a tool called blast-radius to visually represent Terraform's graph.
This EC2 instance itself creates an EC2 instance using Terraform in order to generate a graph locally.

Terraform SSHs into the first master blast-radius instance using a remote-exec provisioner due to Terraform's inability to determine the state of cloud-init, so you need to pass the private key as another env variable. In this repo, it is
- TF_VAR_FRANKFURTKEY

The aws_ec2.tf relies on EC2's cloudinit to perform initial configuration steps (see *user_data* section of resource aws_instance). Terraform has no way to know whether cloudinit is done, so it's quite possible and likely that the remote-exec sections complete before cloudinit is done, resulting in a botched deployment.

A simple workaround consists in having cloudinit touch a file which effectively becomes a semaphore that the remote-exec simply waits for before proceeding further.

Once the EC2 instance is deployed, it contains itself a Terraform plan (aws.tf) which creates a simple EC2 instance in a new VPC. That is simply meant to test blast-radius. **Note: automating the execution of a Terraform plan in the second EC2 instance requires passing AWS credentials to that instance. This is not trivial and we are not taking care of the problem in this simple repo.**

Therefore, please SSH into your cloud instance (replace the name of the SSH keypair in aws_ec2.tf with yours), populate your ~/.aws/credentials file, launch Terraform to create the second cloud instance and start blast-radius manuallylike so >blast-radius --serve ./ --port 8888 

[![Deploy Infrastructure](https://github.com/cpaggen/blastradius-ec2/actions/workflows/terraform-pipeline.yaml/badge.svg?branch=dev&event=workflow_run)](https://github.com/cpaggen/blastradius-ec2/actions/workflows/terraform-pipeline.yaml)
