[![Terraform pipeline](https://github.com/cpaggen/blastradius-ec2/actions/workflows/terraform-pipeline.yaml/badge.svg?branch=dev)](https://github.com/cpaggen/blastradius-ec2/actions/workflows/terraform-pipeline.yaml)

# Blast-radius test setup

This repo is automated through a Github workflow. The workflow consists in:
- Terraform (TF) lint
- TF validate
- TF init
- TF plan
- Static analysis with Checkov
- Upload SARIF to Security tab of repo
- TF apply
- Test EC2 connectivity

To replicate this, please populate the necessary env variables for Terraform as Github secrets:
- AWS_ACCESS_KEY_ID
- AWS_ECRET_KEY_ID
- AWS_REGION

The code deploys an EC2 instance with a tool called blast-radius to visually represent Terraform's graph.
This EC2 instance itself creates an EC2 instance using Terraform in order to generate a graph locally.

The aws_ec2.tf relies on EC2's cloudinit to perform initial configuration steps (see *user_data* section of resource aws_instance) and prepare the instance to run blast-radius. 

Once the EC2 instance is deployed, it contains itself a Terraform plan (aws.tf) which creates a simple EC2 instance in a new VPC. That is simply meant to test blast-radius. **Note: automating the execution of a Terraform plan in the second EC2 instance requires passing AWS credentials to that instance. This is not trivial and we are not taking care of the problem in this simple repo.**

Therefore, please SSH into your cloud instance (replace the name of the SSH keypair in aws_ec2.tf with yours), populate your ~/.aws/credentials file, launch Terraform to create the second cloud instance and start blast-radius manuallylike so >blast-radius --serve ./ --port 8888 

**Using a remote backend is strongly encouraged; without one you will have a hard time destroying your infrastructure using Terraform!**

This repo is linked to a spacelift.io stack.
