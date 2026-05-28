# Deployment Evidence — aws-ha-web-app

**Status:** Architecture deployed and verified via AWS API on 2026-05-28, then destroyed. **Repo retained as a reference; not the active portfolio focus.**

## What This Lab Demonstrates
Classic 3-tier HA web application pattern in a single VPC:
- **Application Load Balancer** in 2 public subnets across 2 AZs
- **Auto Scaling Group** of 2–4 Apache instances in 2 private subnets
- **RDS MySQL Multi-AZ** in 2 private subnets (synchronous standby in second AZ for failover)
- NAT Gateway for outbound from private subnets

It's the canonical reference architecture every cloud engineer is expected to be able to build. Included in this portfolio for completeness, not as the differentiating asset.

## Architecture Capture (2026-05-28)

Verified live via `aws describe-*`:

| Resource | Identifier | Notes |
|---|---|---|
| VPC | `aws_vpc.main` (in state) | 10.0.0.0/16 |
| ALB | `ha-web-app-alb` | DNS `ha-web-app-alb-685156503.us-east-1.elb.amazonaws.com`, state ACTIVE |
| Target group | `ha-web-app-tg` | HTTP 80, health-check path `/` |
| ASG | `ha-web-app-asg` | min/max/desired 2/4/2, 2 AZs (us-east-1a, us-east-1b) |
| Launch template | `lt-04696bc7bd872ec23` | Amazon Linux 2, t2.micro, Apache via user-data |
| RDS | `ha-web-app-db` | MySQL 8.0, Multi-AZ = `True`, db.t3.micro, in 2 private subnets via DB subnet group |
| Subnets | 2 public + 2 private | Across us-east-1a and us-east-1b |
| NAT GW | `aws_nat_gateway.main` | Outbound for private subnets |
| Security groups | ALB→Web (80), Web→RDS (3306) | Layered SG-to-SG references |

## Why This Lab Is Archived

The repo focuses on **network engineering**: BGP, IPSec VPN, VPC peering topology, flow log observability, reusable VPC modules. `ha-web-app` is **application architecture** that would belong in an AWS Solutions Architect portfolio more than a Cloud Network Engineer one. Kept here as a reference deployment any reviewer can verify against the Terraform code.

## How To Reproduce

```powershell
cd terraform
$env:TF_VAR_key_pair = "your-key-pair-name"
$env:TF_VAR_db_password = "your-strong-password"  # or use terraform.tfvars (gitignored)
terraform init
terraform apply
# … verify ALB DNS responds with Apache pages …
terraform destroy   # ~$78/mo, always destroy same-day
```

## Raw Evidence (this folder)
- `alb.json` — ALB describe
- `target-groups.json` — target group config
- `target-health.json` — target health snapshot
- `asg.json` — ASG full describe
- `rds.json` — RDS instance state snapshot
- `ec2.json` — EC2 launched by ASG

## Cost
~$78/mo if left running. Always destroy after capture.
