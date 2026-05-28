# AWS Highly Available Web Application

![AWS](https://img.shields.io/badge/AWS-232F3E?logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?logo=terraform&logoColor=white)
![ALB](https://img.shields.io/badge/ALB-Load_Balancer-informational)
![Multi--AZ](https://img.shields.io/badge/Multi--AZ-HA-brightgreen)
![Status](https://img.shields.io/badge/Status-Complete-brightgreen)

A production-pattern highly available web application built on AWS: Application Load Balancer + Auto Scaling Group spanning two Availability Zones, with a Multi-AZ RDS instance in private subnets. Demonstrates the core AWS Solutions Architect Associate architecture: design for failure, remove single points of failure, and scale horizontally.

> ### Reference lab — not the active portfolio focus
>
> This portfolio centers on **network engineering** (BGP, IPSec, VPC topology, observability, reusable VPC modules). `ha-web-app` is included as a reference implementation of the AWS HA pattern any cloud engineer should know, but it isn't the differentiating asset.
>
> Architecture was deployed and verified on 2026-05-28, then destroyed. See [`screenshots/`](screenshots/) for the AWS describe-* evidence of the live deployment.

## The Problem

Single-instance deployments are a liability. An AZ outage, hardware failure, or spike in traffic can take down your entire application. This lab implements the AWS Well-Architected Framework's reliability pillar: redundancy at every layer so no single failure cascades to a full outage.

**Healthcare context:** Clinical applications need defined uptime SLAs. The architecture here supports 99.99% availability by surviving the failure of any single AZ.

## Architecture

```
                        Internet
                           │
                    ┌──────▼──────┐
                    │     ALB      │
                    │  (2 AZs)    │
                    └──────┬──────┘
               ┌───────────┴──────────┐
               │                      │
    ┌──────────▼──────────┐ ┌─────────▼───────────┐
    │  Public Subnet A    │ │  Public Subnet B     │
    │  us-east-1a         │ │  us-east-1b           │
    │                     │ │                      │
    │  ┌───────────────┐  │ │  ┌───────────────┐  │
    │  │  EC2 (ASG)    │  │ │  │  EC2 (ASG)    │  │
    │  │  Apache+AZ ID │  │ │  │  Apache+AZ ID │  │
    │  └───────────────┘  │ │  └───────────────┘  │
    └──────────┬──────────┘ └──────────┬───────────┘
               │                       │
    ┌──────────▼──────────┐ ┌──────────▼───────────┐
    │  Private Subnet A   │ │  Private Subnet B     │
    │  us-east-1a         │ │  us-east-1b           │
    │                     │ │                      │
    │  ┌───────────────┐  │ │  ┌───────────────┐  │
    │  │  RDS Primary  │  │ │  │  RDS Standby  │  │
    │  │  (active)     │  │ │  │  (sync repl.) │  │
    │  └───────────────┘  │ │  └───────────────┘  │
    └─────────────────────┘ └──────────────────────┘
```

*Full diagram: [docs/architecture.png](docs/architecture.png)*

| Component | Configuration |
|-----------|--------------|
| VPC | 10.0.0.0/16 |
| AZs | us-east-1a, us-east-1b |
| Public subnets | 10.0.1.0/24, 10.0.2.0/24 |
| Private subnets | 10.0.11.0/24, 10.0.12.0/24 |
| EC2 instances | t2.micro (Free Tier) |
| RDS engine | MySQL 8.0, db.t3.micro |
| ASG | Min: 2, Max: 4, Desired: 2 |

## How It Works

### ALB Target Group Health Checks

The ALB continuously health-checks each EC2 target on port 80. If a target fails two consecutive checks, the ALB stops sending traffic to it and routes all requests to healthy targets — automatically, with no manual intervention.

### Auto Scaling Group Across AZs

The ASG is configured with `vpc_zone_identifier` pointing to both public subnets. It distributes instances across AZs automatically. If AZ-a fails: the ASG detects the lost instance, launches a replacement in AZ-b, and the ALB routes traffic there while the replacement provisions.

### RDS Multi-AZ

Multi-AZ RDS maintains a synchronous standby replica in the second AZ. During failover, AWS updates the DNS endpoint to point to the standby — no IP change, connection strings stay the same. Promotion typically completes in 60–120 seconds.

### What the User Data Script Does

Each EC2 instance runs Apache with a page that displays its AZ. This lets you see the ALB load-balancing in action by refreshing the page and watching the AZ alternate.

## Prerequisites

- AWS account (some costs apply: RDS db.t3.micro is not Free Tier)
- Terraform >= 1.5
- AWS CLI configured

## Quick Start

```bash
git clone https://github.com/SalamoneJack/aws-ha-web-app.git
cd aws-ha-web-app/terraform

cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

The ALB DNS name appears in outputs. Visit it in a browser — refresh to see the AZ alternating.

## Deployment

### Variables

`terraform/terraform.tfvars.example`:
```hcl
region     = "us-east-1"
key_pair   = "your-key-pair-name"
db_password = "choose-a-strong-password"
```

### Estimated Provision Time

~8 minutes (RDS Multi-AZ takes the longest).

## Failover Testing

### Test 1: EC2 Instance Failure

1. Note which AZ is serving requests
2. Stop one EC2 instance in that AZ via the console
3. ALB routes to the healthy instance while ASG launches a replacement
4. Refresh page — traffic continues uninterrupted to the other AZ

### Test 2: ALB Health Check Failure Simulation

```bash
# SSH to an EC2 instance and stop Apache
sudo systemctl stop apache2
```

ALB removes the instance from the target group within ~30 seconds (2 failed health checks × 15s interval).

### Test 3: RDS Failover

From the RDS console: Actions → Reboot with failover. RDS promotes the standby, updates the endpoint DNS. Application reconnects after ~60–120 seconds.

## Cost

| Resource | Monthly Cost |
|----------|-------------|
| 2× t2.micro EC2 (Free Tier first 12 months) | $0 / ~$17 |
| RDS db.t3.micro Multi-AZ | ~$28 |
| ALB | ~$18 (base) + $0.008/LCU |
| NAT Gateway (for private subnets) | ~$32 |
| **Estimated Total** | **~$78/mo** |

Run `terraform destroy` when done. This is the most expensive lab — RDS and NAT Gateway are the big line items.

## Production Considerations

- Add CloudFront in front of the ALB for global CDN + DDoS protection
- Replace RDS MySQL with Aurora (better failover: 30 seconds vs 60–120 seconds)
- Add WAF to the ALB for OWASP Top 10 protection (critical for healthcare)
- Replace static EC2 user data with an AMI baked by Packer or a proper config management tool
- Enable RDS automated backups with point-in-time recovery
- For HIPAA: enable RDS encryption at rest, enable CloudTrail, store logs in a separate account

## What I Learned

- ALB health checks and ASG health checks are separate — both need to be configured correctly for automatic recovery to work end-to-end
- RDS Multi-AZ is synchronous replication, not async (like a Read Replica). That's why failover is fast and data loss is zero, but it doubles the cost
- NAT Gateway charges $0.045/hr regardless of traffic — it's the "hidden" cost in any multi-AZ setup with private subnets. At scale, you want VPC endpoints for AWS services to reduce that cost
- The AZ identifier in the Apache response is what proves load balancing is actually happening — without it you're just trusting that the ALB is doing its job

## Related Projects

- [aws-multi-vpc-hub-spoke](https://github.com/SalamoneJack/aws-multi-vpc-hub-spoke) — Network segmentation this app would live inside
- [terraform-aws-vpc-module](https://github.com/SalamoneJack/terraform-aws-vpc-module) — The reusable VPC module used here
- [aws-network-monitoring](https://github.com/SalamoneJack/aws-network-monitoring) — Observability for this application tier
