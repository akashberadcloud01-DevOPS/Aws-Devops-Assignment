Project Overview

This project demonstrates AWS infrastructure provisioning using Terraform, a sample web application hosted on EC2, and automated Terraform validation using GitHub Actions.

Architecture

VPC: Isolated AWS network.

Public subnets: Host the Application Load Balancer.

Private application subnets: Host EC2 instances managed by an Auto Scaling Group.

Private database subnets: Host Amazon RDS for MySQL.

Amazon S3: Stores the sample application HTML file and ALB access logs.

AWS Secrets Manager: Stores database credentials.

IAM: Provides permissions to EC2 instances to access required S3 objects.

NAT Gateway: Allows private instances to access the internet for required outbound traffic.

GitHub Actions: Checks Terraform formatting and validates the configuration.

Technologies Used

AWS

Terraform

Linux

Nginx

Amazon EC2

Application Load Balancer

Auto Scaling Group

Amazon RDS for MySQL

Amazon S3

AWS Secrets Manager

Git and GitHub Actions

Project Structure

aws-devops-assignment/
├── .github/
│   └── workflows/
│       └── terraform-ci.yml
├── app/
│   └── index.html
└── terraform/
    ├── main.tf
    ├── outputs.tf
    ├── providers.tf
    ├── variables.tf
    ├── versions.tf
    └── .terraform.lock.hcl

Deployment

Configure AWS credentials securely on the deployment machine.

Initialize Terraform:

terraform init

Check Terraform formatting:

terraform fmt -check -recursive

Validate the configuration:

terraform validate

Review the infrastructure changes:

terraform plan

Apply the reviewed changes:

terraform apply

Run Terraform commands from the terraform/ directory. Review the plan before applying changes.

Application Access

The sample application is served by Nginx on EC2 instances in private subnets. Users access it through the Application Load Balancer.

The current configuration uses HTTP on port 80. HTTPS and a custom domain are not configured.

CI Workflow

GitHub Actions automatically checks Terraform formatting, initializes Terraform without a backend, and validates the configuration for matching pushes and pull requests.

The workflow validates configuration; it does not automatically deploy infrastructure.

Security Notes

Keep AWS credentials and database passwords out of Git.

Do not commit Terraform state files or plan files.

Restrict security group rules to required traffic.

Review IAM permissions and database access settings.

Cleanup

After completing the assignment, review the resources and costs in AWS. When the environment is no longer required, destroy the Terraform-managed infrastructure from the correct Terraform directory after reviewing the plan:

terraform destroy
