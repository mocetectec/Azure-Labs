# Phase 1 — AWS Source Infrastructure

This phase provisions the AWS environment that serves as the source workload for the migration. It deploys a Windows Server 2022 EC2 instance inside a public VPC — the machine that will be discovered, assessed, and migrated to Azure in the phases that follow.

All infrastructure in this phase is managed with Terraform.

---

## What This Phase Builds

| Resource | Details |
|---|---|
| VPC | 10.0.0.0/16 — isolated network boundary |
| Public Subnet | 10.0.1.0/24 — hosts the EC2 instance |
| Internet Gateway | Provides public internet access |
| Route Table | Routes 0.0.0.0/0 traffic through the internet gateway |
| Security Group | Inbound rules required for the working Azure Migrate discovery and replication flow |
| EC2 Instance | Windows Server 2022 — the source workload |
| EBS Volume | 30GB gp3 root volume — this is the disk that gets replicated |

---

## Prerequisites

- AWS Account
- IAM user with programmatic access (recommended instead of root)
- AWS CLI installed and configured (`aws configure`)
- Terraform installed (`terraform -version` to verify)

Your Terraform IAM user needs the following permissions at minimum:

```
ec2:*
vpc:*  (covered under ec2:*)
```

> **Note:** If your IAM user does not have sufficient permissions, Terraform apply will fail with `AccessDenied`. See the [Troubleshooting](#troubleshooting) section below.

---

## File Structure

```
phase-1-aws-infrastructure/
├── main.tf                    # All AWS resources
├── variables.tf               # Input variable definitions
├── outputs.tf                 # EC2 IP, instance ID outputs
├── terraform.tfvars.example   # Template — copy and fill in your values
└── README.md
```
---

## How to Deploy

**Step 1 — Copy the example vars file and fill in your values:**

```powershell
copy terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region     = "us-east-1"
yourname       = "your-name-here"
admin_password = "YourSecureP@ssword123!"
```

> Password requirements: minimum 12 characters, must include uppercase, lowercase, numbers, and symbols. AWS will reject weak passwords.

**Step 2 — Initialize Terraform:**

```powershell
terraform init
```

**Step 3 — Review the plan:**

```powershell
terraform plan
```

**Step 4 — Deploy:**

```powershell
terraform apply
```

Deployment takes 3–5 minutes. Windows instances take an additional 5 minutes to fully initialize after Terraform completes — wait before attempting RDP.

---

## Key Design Decisions

**Why a public subnet?**
The EC2 instance needs a publicly reachable IP address. Azure Migrate appliances in Azure communicate with the source machine over the public internet — there is no VPN between the two clouds in this lab. `map_public_ip_on_launch = true` ensures the instance gets a public IP automatically at launch.

**Why these security group ports?**
Each port serves a specific role in the migration process:

| Port | Protocol | Purpose | Phase Used |
|------|----------|---------|------------|
| 443 | TCP | HTTPS — appliance control plane communication | Discovery & Replication |
| 3389 | TCP | RDP — admin access for verification | All phases |
| 5985 | TCP | WinRM HTTP — OS-level discovery | Discovery |
| 445 | TCP | SMB — mobility service file transfer | Replication |
| 9443 | TCP | ASR replication data — Mobility Agent to Process Server | Replication |

> **Note:** Azure Migrate discovery depends on both network connectivity and OS-level configuration. Even with the correct ports open, discovery can fail if WinRM or authentication settings are misconfigured.

In this implementation, only the ports required for the working discovery and replication flow were opened. Additional ports (such as 135 or 5986) may be required in other environments but were not necessary for this lab.

> Opening these ports to `0.0.0.0/0` is acceptable for a short-lived lab. In production, restrict to known IP ranges.

**Why this instance type?**
Windows Server requires a minimum of 2 vCPUs and 4GB RAM to run without being unusably slow. 

In this lab, I used an `m7i-flex.large` instance due to AWS free tier constraints, but any instance type meeting the minimum requirements will work for the migration process.

**Why gp3 for the EBS volume?**
gp3 is the current generation general purpose SSD in AWS. It provides better baseline performance than gp2 at the same or lower cost. This is the disk that gets replicated to Azure — the volume type does not affect the migration process itself.

**Why use `user_data`?**
The EC2 instance uses a PowerShell `user_data` block to perform first-boot configuration automatically. In this project, it was used to:

- Set the local Administrator password
- Enable and configure WinRM for remote discovery
- Prepare the instance for Azure Migrate connectivity testing

This reduced manual setup after launch and made the EC2 instance immediately usable for RDP access and later discovery workflows.

---

## Verify Deployment

After `terraform apply` completes, retrieve the outputs:

```powershell
terraform output ec2_public_ip
terraform output ec2_instance_id
```

Save these values — you will need them in Phase 3.

**Connect via RDP to confirm the instance is running:**

Log in with:
- **Username:** `Administrator`
- **Password:** the value you set in `terraform.tfvars`

A standard Windows Server desktop confirms the source machine is ready.

---

## Estimated Cost

| Resource | Estimated Cost |
|---|---|
| EC2 m7i-flex.large (Windows) | Varies (region/free-tier dependent) |
| EBS gp3 30GB | ~$0.10/day |
| Internet Gateway | No hourly cost |
| **Total for a 6-hour lab** | **~$0.50–1.00** |

Destroy all resources immediately after completing the lab.

---

## Teardown

```powershell
terraform destroy
```

Confirm with `yes` when prompted. All 10 resources will be destroyed.

> Destroy the AWS side **before** the Azure side to avoid any dependency issues during cleanup.

---

## Troubleshooting

**AccessDenied during terraform apply**

```
Error: AccessDenied: User is not authorized to perform: ec2:CreateSecurityGroup
```

Your Terraform IAM user is missing EC2 permissions. Go to IAM → Users → your Terraform user → Add permissions. Attach the `AmazonEC2FullAccess` and `AmazonVPCFullAccess` managed policies, then re-run `terraform apply`.

---

**AMI not found / empty result error**

```
Error: collecting instance settings: empty result
```

The AMI ID in `variables.tf` is hardcoded and may no longer be valid. AMI IDs are region-specific and updated frequently by AWS. Retrieve the current valid ID:

```powershell
aws ec2 describe-images `
  --region us-east-1 `
  --owners amazon `
  --filters "Name=name,Values=Windows_Server-2022-English-Full-Base-*" `
            "Name=state,Values=available" `
  --query "sort_by(Images, &CreationDate)[-1].ImageId" `
  --output text
```

Update the `windows_ami` value in `terraform.tfvars` with the returned ID.

---

**RDP not connecting after deployment**

Windows Server takes 5–7 minutes to fully initialize after Terraform reports completion. Wait and retry. If it still fails after 10 minutes, verify port 3389 is open in the security group and that the instance is in a `running` state in the AWS console.

## Next Phase

Once you have confirmed RDP access to the EC2 instance, proceed to:

**[Phase 2 — Azure Infrastructure →](../phase-2-azure-infrastructure/README.md)**
