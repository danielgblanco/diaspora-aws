# Diaspora on AWS
This project contains the resources necessary to spin up a [diaspora*](https://diasporafoundation.org/) pod, along with
all the resources needed, in AWS. It aims to provide a cost effective yet reliable infrastructure.
Due to the wide range of cost and reliability requirements, we can think of two possible architectures. One focused on
high reliability, and the other one focused on low cost.

It should be noted that, even though there are other *diaspora forks supporting Docker installations, this repo is based
on the original installation instructions.

# Low Cost Alternative
This is a simpler, low-cost architecture. While it still provides a reliable setup, it does not implement any high
availability features and downtime or low performance are possible. The advantage is that this stack can be run for less
than $20/month in Ireland (eu-west-1).

Please refer to the following [AWS Pricing Calculator estimate](https://calculator.aws/#/estimate?id=1966a424bb82d72b8f68622697035a8aab7428ed).

## Architecture
![Low-cost Infrastructure Diagram](./low_cost/infra-diagram.png)

Even though this solution is aimed at providing a low-cost alternative, it still keeps reliability and low-friction in
mind. It is based around the following components.

### VPC
The stack is deployed in a VPC with a public subnet, where the pod runs, and a private subnet group, where an Aurora RDS
cluster is hosted. In order to save costs on Load Balancers, this pod runs directly in a public subnet, relying on
a security group to only allow SSH and HTTP access from the VPC (using a bastion host).

### Pod Instance
This contains one instance running an AMI with all [components](https://wiki.diasporafoundation.org/Diasporas_components_explained)
installed, except database. The reason to run on a single instance instead of an ASG is purely cost related. Running
on an ASG would require either a load balancer in front (extra cost) or to automatically register an EIP at launch
exposing this as a public IP, which could be a security concern. There could be a third option, to still register an EIP
at launch and place the instance in a private subnet, but that would require a NAT Gateway for outbound traffic, also
incurring in extra costs.

The instance is created in a public subnet with no public IP assigned, so it is possible to connect to internet from
inside the instance.

The instance has a CloudWatch alarm configured to recover the instance automatically in case of a failure on the
underlying infrastructure. This is explained in more detail in the [official AWS documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-recover.html).

### API Gateway
The API Gateway acts as a proxy to do TLS termination using a certificate acquired from Certificate Manager. Along with
the API, there's a custom domain created that use Route53 to resolve to the API Gateway, a VPC Link to allow connection
from API Gateway to private resources in the VPC, and Cloud Map service registering the only instance. Cloud Map
is required to allow API Gateway to connect to private resources inside a VPC without using a load balancer.

### S3 Bucket
This bucket to host assets as explained in the diaspora* documentation on [hosting assets on S3](https://wiki.diasporafoundation.org/Asset_hosting_on_S3).

This installation uses S3FS via FUSE to store public assets and uploads on the S3 bucket mentioned above. This has a few
benefits:

* Access to S3 is done via an S3 VPC endpoint, minimising cost.
* The bucket is kept private, with no public access to files directly from S3.
* No CORS necessary.

### Aurora PostgreSQL
This PostgreSQL on Aurora database runs in private subnets. It is a serverless database, which reduces cost by only
paying for the periods of usage.

### ACM Certificate
An AWS Certificate Manager certificate is requested as part of the CloudFormation stack. If the domain used is not
hosted in Route53, there are some manual steps to follow during creating of the stack, otherwise it'll remain in
`CREATE_IN_PROGRESS` state. Please refer to the [official documentation](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-certificatemanager-certificate.html)
for more information.

### Amazon SES
We use Amazon SES to send emails from this diaspora* instance. In order to do so, domain and SMTP user details have
to be passed to the CloudFormation stack creation. There are a few preliminary steps that need to be followed:

* [Obtaining SMTP credentials](https://docs.aws.amazon.com/ses/latest/DeveloperGuide/smtp-credentials.html)
* [Verifying domain](https://docs.aws.amazon.com/ses/latest/DeveloperGuide/verify-domain-procedure.html)
* [Moving out of sandbox](https://docs.aws.amazon.com/ses/latest/DeveloperGuide/request-production-access.html)
* [Setting a custom MAIL FROM domain](https://docs.aws.amazon.com/ses/latest/DeveloperGuide/mail-from.html)

After SMTP credentials are created, they need to be stored in SSM Parameter Store so that they can be used during
stack creation.

## Installation

First install Packer as mentioned in the [official docs](https://www.packer.io/docs/install).

Create an AWS user for Packer with the [minimal est of permissions necessary](https://www.packer.io/docs/builders/amazon#iam-task-or-instance-role)
and configure it on your terminal ([named profiles](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html)
recommended). After that run (with your profile name) to enable it:

```
export AWS_PROFILE=packer
```

Create the AMI you will use for your pod. Replace `<base_ami_id>` and `<aws_region>` with your base AMI and region. The
scripts have been tested on Ubuntu 20.04 in eu-west-1.

```
cd low_cost/packer
packer build -var ami_id=<base_ami_id> -var region=<aws_region> packer_pod.json
```

If you want to re-create the AMI for a given version and delete any existing resources run:

```
packer build -var ami_id=<base_ami_id> -var region=<aws_region> -force_deregister -force_delete_snapshot packer_pod.json
```

Create parameters using [SSM Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
for database username and password. Use `SecureString` as the type for the password parameter. You can choose your own
parameter names, as these will be used later when spinning up the CloudFormation Stack.

To create the CloudFormation stack, go to the [CloudFormation Console](https://eu-west-1.console.aws.amazon.com/cloudformation/home)
and create a new stack using the `cf_template.yml` template provided.

The stack creation requires the Hosted Zone ID parent of the corresponding domain name to create.

## Upgrades
TODO: [Database replacement](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-rds-dbcluster.html)


# High Availability Alternative
*NOTE: This is a draft diagram with some initial ideas, no work has been carried out to deploy a reliable solution*

![Low-cost Infrastructure Diagram](high_availability/infra-diagram.png)