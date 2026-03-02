# 🔐 Azure SQL (PaaS) + Key Vault + Managed Identity

## 📌 Project Overview

This project demonstrates how to securely deploy a cloud-native application backend using Microsoft Azure services, following security best practices and the principle of least privilege.

## Environment Setup
- **Cloud Provider**: Azure
- **Services**: Virutal Machine, Key Vault, SQL Database (Platform as a Service), Azure Monitor

The goal of this lab was to eliminate hard-coded credentials, centralize secret management, and implement identity-based authentication between Azure resources.

---

## 🏗 Architecture Summary
<img width="1250" height="790" alt="Screenshot 2026-03-01 185622" src="https://github.com/user-attachments/assets/f8c09468-4a1b-4616-92b5-f3b9ad458514" />


**Core Components**

- Web Server VM inside Azure Virtual Network
- Azure SQL Database (PaaS, DTU-based Basic tier)
- Azure Key Vault (secret storage)
- Managed Identity for passwordless authentication
- Azure Monitor (metrics validation)

**Security Model**

1. SQL admin password stored in Key Vault  
2. VM authenticates to Key Vault using Managed Identity  
3. No credentials stored in code or configuration files  
4. Database accessed over encrypted TLS connection  

---

## 🚀 Deployment Phases

---

# Phase 1 – Deploy Azure SQL Database (PaaS)

### Configuration

- **Resource Group:** `rg-lab03-[yourname]`
- **Database Name:** `sqldb-app`
  
  <img width="550" height="790" alt="Screenshot 2026-03-01 185622" src="https://github.com/user-attachments/assets/32e5593c-ae33-4428-a403-60e87c3f08ec">

- **Server Name:** `sql-server-[yourname]`
  
  <img width="550" height="790" alt="Screenshot 2026-03-01 185622" src="https://github.com/user-attachments/assets/e0e45a9e-59f6-4e47-850e-2a0d28ca5563">

- **Region:** East US
- **Authentication:** SQL Authentication
- **Admin Login:** `sqladmin`
 
   <img width="650" height="790" alt="Screenshot 2026-03-01 185622" src="https://github.com/user-attachments/assets/a957dd04-ff8b-4d69-8f09-b5001d6b67d4">
- **Service Tier:** Basic (DTU-based)

  <img width="903" height="469" alt="Screenshot 2026-03-01 200023" src="https://github.com/user-attachments/assets/7d6ae12b-81ae-4482-9260-68f64f7f629c" />

- **Backup Redundancy:** Locally-redundant (LRS)
  
   <img width="884" height="478" alt="Screenshot 2026-03-01 200010" src="https://github.com/user-attachments/assets/07089999-558a-4230-88bc-4f7a9e872c02" />


### Cost Optimization

The Basic DTU tier was selected to:
- Minimize monthly cost (~$5/month)
- Support lab-scale workloads
- Demonstrate cost-conscious cloud deployment

### Networking Configuration

- Public endpoint enabled
  <img width="943" height="560" alt="Screenshot 2026-03-01 195817" src="https://github.com/user-attachments/assets/bcbd7742-91bd-4629-8eb4-f8f4b6637fec" />

- Azure services allowed
  <img width="910" height="533" alt="Screenshot 2026-03-01 195825" src="https://github.com/user-attachments/assets/1170708e-4059-4671-a30e-fb77ee1d1d45" />

- Client IP whitelisted for secure access
  <img width="869" height="503" alt="Screenshot 2026-03-01 195838" src="https://github.com/user-attachments/assets/dcf36750-c513-4bfb-9121-dabbabbc2430" />

---

# Phase 2 – Deploy Azure Key Vault

### Configuration

- **Key Vault Name:** `kv-lab03-[yourname]`
  <img width="892" height="581" alt="Screenshot 2026-03-01 201811" src="https://github.com/user-attachments/assets/9d0ad499-dc98-43d2-a260-d8514a304935" />

- **Region:** East US
- **Pricing Tier:** Standard
- **Permission Model:** Vault Access Policy
  <img width="938" height="468" alt="Screenshot 2026-03-01 201822" src="https://github.com/user-attachments/assets/4119ba8c-ec84-41e1-a0fb-e5ee1d8acf72" />

Key Vault is used to securely store sensitive data, eliminating the need to manually manage database credentials.

---

# Phase 3 – Secure Database Credentials

The SQL admin password was stored as a secret:

- **Secret Name:** `SqlAdminPassword`
- Stored securely within Azure Key Vault
- Access controlled via Access Policies
  <img width="877" height="537" alt="Screenshot 2026-03-01 202023" src="https://github.com/user-attachments/assets/c8917cc1-a0a0-4741-b81c-fa460ec97330" />

This prevents:
- Credential exposure in source code
- Password reuse
- Manual secret management

---

# Phase 4 – Enable Managed Identity

To allow secure access to Key Vault without storing credentials:

### Step 1: Enable System Assigned Managed Identity

- Enabled on VM `web-vm`
  
  <img width="805" height="529" alt="Screenshot 2026-03-01 202155" src="https://github.com/user-attachments/assets/e14afaad-0dbe-46d1-841c-2d01d8c69cdf" />

- Azure automatically registers the VM in Azure AD

### Step 2: Grant Key Vault Permissions

Access policy configured with:

- Secret Permissions:
  - Get
  - List
    <img width="932" height="501" alt="Screenshot 2026-03-01 202624" src="https://github.com/user-attachments/assets/91e796ad-d1d4-4614-b147-bf57114782db" />

- Principal:
  - `web-vm`
    <img width="922" height="391" alt="Screenshot 2026-03-01 202633" src="https://github.com/user-attachments/assets/904d4e4b-35ab-4b7c-b269-b7efc9f91274" />

### Result

The VM can now:

- Authenticate to Azure AD
- Retrieve secrets from Key Vault
- Avoid hard-coded passwords entirely

This implements identity-based access control and aligns with Zero Trust principles.

---

# Phase 5 – Observability & Validation

To validate deployment health:

1. Navigated to `sqldb-app`
2. Opened **Azure Monitor → Metrics**

   <img width="317" height="760" alt="Screenshot 2026-03-01 203546" src="https://github.com/user-attachments/assets/5ae8a602-5886-42af-b90b-b66316262b72" />

3. Selected metric:
   - DTU Percentage
   - Aggregation: Max

This confirmed:

- Database availability
- Monitoring integration
- Operational visibility

---

# 🔐 Security Best Practices Implemented

✔ Centralized secret management  
✔ No credentials stored in application code  
✔ Managed Identity for passwordless authentication  
✔ Role-based access control  
✔ Encrypted database connections (TLS)  
✔ Monitoring via Azure Monitor  

---


# 🎯 Project Outcome

This lab demonstrates the ability to:

- Deploy secure Azure infrastructure
- Implement identity-based access control
- Apply cloud security best practices
- Configure monitoring and validation
- Optimize for cost without sacrificing architecture integrity


