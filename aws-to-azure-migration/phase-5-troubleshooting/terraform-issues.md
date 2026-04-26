# Terraform Issues

Issues encountered during `terraform apply` on the AWS and Azure sides.

---

## Issue 1 - AccessDenied During Terraform Apply

**Phase:** 1 (AWS)

**Symptom:**

```
Error: AccessDenied: User is not authorized to perform: ec2:CreateSecurityGroup
```
or
```
Error: AccessDenied: User is not authorized to perform: iam:CreateRole
```

**Root Cause:**

The Terraform IAM user (`terraform-migrate-lab`) was created with `AmazonEC2FullAccess` and `AmazonVPCFullAccess` but no IAM permissions. Terraform needs to create IAM resources as part of the lab infrastructure - without explicit IAM permissions, every IAM-related resource creation fails with AccessDenied.

This is a least-privilege gap - EC2 access does not include IAM access even for users with broad EC2 permissions.

**Resolution:**

Go to **AWS Console → IAM → Users → terraform-migrate-lab → Add permissions**.

Add the following inline policy or attach a managed policy that includes:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:CreatePolicy",
        "iam:CreateUser",
        "iam:AttachRolePolicy",
        "iam:AttachUserPolicy",
        "iam:CreateInstanceProfile",
        "iam:AddRoleToInstanceProfile",
        "iam:CreateAccessKey",
        "iam:GetRole",
        "iam:GetPolicy",
        "iam:GetUser",
        "iam:ListRolePolicies",
        "iam:ListAttachedRolePolicies",
        "iam:PassRole",
        "iam:DeleteRole",
        "iam:DeletePolicy",
        "iam:DeleteUser",
        "iam:DetachRolePolicy",
        "iam:DetachUserPolicy",
        "iam:RemoveRoleFromInstanceProfile",
        "iam:DeleteInstanceProfile",
        "iam:DeleteAccessKey"
      ],
      "Resource": "*"
    }
  ]
}
```

Re-run `terraform apply` after permissions are updated.

> Scope the resource field to specific ARNs in a production environment rather than using `*`.

---

## Issue 2 - AMI Not Found / Empty Result Error

**Phase:** 1 (AWS)

**Symptom:**

```
Error: collecting instance settings: empty result
```

Terraform apply completes planning but fails during EC2 instance creation.

**Root Cause:**

The AMI ID for Windows Server 2022 is hardcoded in `variables.tf`. AMI IDs are region-specific and are regularly rotated by AWS when new versions are released. A hardcoded ID that was valid when the lab was written may no longer exist.

**Resolution:**

Retrieve the current valid AMI ID using the AWS CLI:

```powershell
aws ec2 describe-images `
    --region us-east-1 `
    --owners amazon `
    --filters "Name=name,Values=Windows_Server-2022-English-Full-Base-*" `
              "Name=state,Values=available" `
    --query "sort_by(Images, &CreationDate)[-1].ImageId" `
    --output text
```

Update `terraform.tfvars` with the returned ID:

```hcl
windows_ami = "ami-xxxxxxxxxxxxxxxxx"
```

Re-run `terraform apply`.

> Never hardcode AMI IDs in production Terraform. Use a `data` source to always fetch the latest valid image:
> ```hcl
> data "aws_ami" "windows_2022" {
>   most_recent = true
>   owners      = ["amazon"]
>   filter {
>     name   = "name"
>     values = ["Windows_Server-2022-English-Full-Base-*"]
>   }
> }
> ```

---

## Issue 3 — Terraform Apply Fails on Storage Account Name

**Phase:** 2 (Azure)

**Symptom:**

```
Error: A resource with the ID "/subscriptions/.../storageAccounts/stmigrate[yourname]"
already exists - to be managed via Terraform this resource needs to be imported into the State.
```

or

```
Error: the storage account name "stmigrate[yourname]" is already taken.
```

**Root Cause:**

Azure storage account names must be globally unique across all of Azure — not just within your subscription or resource group. The name `stmigrate[yourname]` may already be in use by another Azure customer if `yourname` is a common value.

Storage account names must also be 3–24 characters, lowercase letters and numbers only, no hyphens or underscores.

**Resolution:**

Update the `yourname` value in `terraform.tfvars` to something more unique:

```hcl
# azure-side/terraform.tfvars
yourname = "charles02"   # or add numbers, initials, or a random suffix
```

Alternatively, verify the name is available before applying:

```powershell
az storage account check-name --name stmigratecharles
# "nameAvailable": true = safe to use
# "nameAvailable": false = choose a different name
```

Re-run `terraform apply` after updating the name.
