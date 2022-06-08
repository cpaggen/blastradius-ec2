# Blast-radius test setup

The aws_ec2.tf code deploys an EC2 instance in the AWS account and region specified in your local config/credentials file
The location is usually */home/user/.aws/config* and */home/user/.aws/credentials*

Because pushing those to Git is a big no-no, aws_ec2.tf uses a file provisioner to secure copy those files from your computer to the EC2 instance.

The aws_ec2.tf relies on EC2's cloudinit to perform initial configuration steps (see *user_data* section of resource aws_instance).
Terraform has no way to know whether cloudinit is done, so it's quite possible and likely that the file_provisioner and/or the remote-exec sections
complete before cloudinit is done, resulting in a botched deployment.

A simple workaround consists in having cloudinit touch a file which effectively becomes a semaphore that the remote-exec simply waits for before
proceeding further.

Once the EC2 instance is deployed, it contains itself a Terraform plan (aws.tf) which creates a simple EC2 instance in a new VPC.
That is simply meant to test blast-radius.


