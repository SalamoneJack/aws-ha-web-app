# Architecture Diagram

Add your draw.io architecture diagram here as `architecture.png`.

## Suggested draw.io Elements

- VPC box (10.0.0.0/16)
- Two AZ columns (us-east-1a, us-east-1b)
- Public subnets with EC2 instances in each AZ
- Private subnets with RDS Primary (AZ-a) and RDS Standby (AZ-b)
- ALB spanning both public subnets at the top
- Internet Gateway above the ALB
- NAT Gateway in public subnet AZ-a with arrow to private subnets
- Bidirectional sync arrow between RDS Primary and Standby labeled "synchronous replication"
- Auto Scaling Group boundary around the EC2 instances

## Export

Export as PNG at 1200px wide, save as `docs/architecture.png`.
Update the README image reference: `![Architecture](docs/architecture.png)`
