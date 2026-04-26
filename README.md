# ☁️ Azure Cloud Labs

Welcome to my Azure Cloud Labs repository.

This repository documents my progression from foundational Azure labs to a full **end-to-end cross-cloud migration project**, demonstrating real-world cloud engineering, infrastructure design, and troubleshooting.

---

## 🚀 Featured Project

### 🔁 AWS to Azure Migration (End-to-End)

A complete cross-cloud migration of a Windows Server workload from **AWS EC2 to Azure** using **Azure Migrate, Azure Site Recovery, and Terraform**.

This project implements the full migration lifecycle:
- Infrastructure provisioning (AWS + Azure via Terraform)
- Discovery and assessment (WinRM/WMI)
- Replication (Azure Site Recovery)
- Test migration and cutover
- Post-migration validation and troubleshooting

**Highlights:**
- Cross-cloud migration without VPN (public endpoint communication)
- Deep troubleshooting of WinRM, WMI, DNS, and replication issues
- Identification and resolution of undocumented behavior (mobility agent private IP hardcoding)
- Structured troubleshooting knowledge base (Phase 5)

**Key Concepts:**
- Hybrid / multi-cloud architecture
- Migration workflows and replication pipelines
- OS-level vs network-level troubleshooting
- Infrastructure as Code (Terraform)

👉 [View Project →](./aws-to-azure-migration/README.md)

---

## 📂 Other Azure Labs

### 🐧 Linux VM Deployment via Azure CLI
Deploy and manage a Linux VM using Azure CLI.

**Concepts:**
- Resource groups
- VM provisioning
- SSH access

---

### 🌐  Static Website Hosting on Azure Storage
Host a static website using Azure Blob Storage.

**Concepts:**
- Serverless hosting
- Storage accounts
- Public endpoints

---

### 🔐 Secure 2-Tier Web Application
Build a secure web + database architecture using VNets and NSGs.

**Concepts:**
- Network segmentation
- Security controls
- Private vs public tiers

---

### 🛡️ Azure Governance (RBAC, Policy, Budgets)
Implement governance controls for access, compliance, and cost.

**Concepts:**
- Least privilege access
- Policy enforcement
- Cost management

---

### 🔑  Azure SQL + Key Vault + Managed Identity
Secure backend architecture using Azure PaaS services.

**Concepts:**
- Managed identity
- Secretless authentication
- Secure service communication
---

### 🏗️ Terraform Azure Networking Lab
Deploy Azure networking resources using Terraform.

**Concepts:**
- Infrastructure as Code
- Automation
- Declarative configuration

---

## 🧠 Skills Demonstrated

- Cross-Cloud Migration (AWS → Azure)
- Cloud Architecture Design
- Azure Networking & Security
- Identity & Access Management (IAM)
- Infrastructure as Code (Terraform)
- Troubleshooting Distributed Systems
- Azure Migrate & Azure Site Recovery
- CLI-Based Automation

---

## 📌 Notes

- These labs are for learning and demonstration purposes.
- Some deployments may incur Azure costs — always clean up resources after use.

---

## 📬 Contact

Feel free to connect or reach out if you have questions or feedback!
