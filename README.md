## 🎬 [Watch Me Build This Lab!](https://www.loom.com/share/b90d82baf12940c88a73b3653772c65c)

# Secure 2-Tier Web Application in Microsoft Azure

## Overview

This project demonstrates how to build a secure **2-tier web application architecture** in Microsoft Azure using:

- Azure Virtual Network (VNet)
- Subnet segmentation
- Linux Virtual Machines
- Public and Private IP configuration
- Network Security Group (NSG) rules

The architecture separates the **web tier (public-facing)** from the **database tier (private backend)** and restricts access using subnet-level firewall rules.

---

## Architecture Diagram
<img width="864" height="493" alt="Screenshot 2026-02-23 203417" src="https://github.com/user-attachments/assets/f770a820-a182-4591-bbee-63db75bb9314" />

---

## Environment Setup
- **Cloud Provider**: Azure
- **Services**: Azure Virtual Network,  Azure Network Security Groups, SSH Authentication (Key Pair), Virutal Machines
- **Virtual Machine Image**: Ubuntu Server 20.04 LTS
- **Virtual Machine Size**: Standard_D2s_v3
---

# Deployment Guide

## Phase 1 — Network Foundation
1. Create Virtual Network
   - Search for **Virtual Networks**
     <img width="1895" height="425" alt="Screenshot 2026-02-23 205704" src="https://github.com/user-attachments/assets/1e004c2e-b1d8-4787-993c-367a5b9e3f50" />
   - Click **Create**
     <img width="1731" height="607" alt="Screenshot 2026-02-23 205737" src="https://github.com/user-attachments/assets/51273bc1-d4ed-4c8a-a4e4-397593d23d5f" />
   - **Resource Group:** Creat a new resource group
     <img width="1253" height="1113" alt="Screenshot 2026-02-23 205833" src="https://github.com/user-attachments/assets/80ed1535-f1f4-4d63-a868-0b974858229b" />
   - **Region:** `East US`
   - **Virtual Netowrk Name**: `vnet-lab02`
     <img width="1180" height="224" alt="Screenshot 2026-02-23 205917" src="https://github.com/user-attachments/assets/67045141-4c6f-4463-9b25-a81457c6201f" />
   - **IP addresses**: We will be creating 2 additonal subnets, one for the web and one for the database.

      | Name       | Address Range   | Purpose |
      |------------|-----------------|----------|
      | default  | 10.0.0.0/16  | virtual network |
      | snet-web   | 10.0.1.0/24     | Web Tier |
      | snet-db    | 10.0.2.0/24     | DB Tier  |

    - Click **Review + Create**

---

# Phase 2 — Deploy Web Server (Frontend)

1. Create Virtual Machine
    - Search → **Virtual Machines**
      <img width="2204" height="370" alt="Screenshot 2026-02-23 210838" src="https://github.com/user-attachments/assets/0248f293-9f01-4111-996d-bc0f8a4e99e3" />
    - Click **Create**, Select **Virtual Machine**
    <img width="991" height="968" alt="Screenshot 2026-02-23 210856" src="https://github.com/user-attachments/assets/055225f2-4306-4844-9e9c-222af8812ce9" />

    - **Resource Group:** select the resource group created in the previous step
    - **Virtual Machine Name:** `vm-web`  
    - **Region:** `East US`
    - **Security Type:** `Standard`
    - **Image:** `Ubuntu Server 20.04 LTS`
    - **Size:** `Standard_B1s`
    - **Authntication Type:** `SSH Public Key`
      - create a new SSH key pair
      - You can provide a name or leave it as generated
    - **Inbound Ports:**
      - Check **Allow selected ports**
      - Select Port 22 (SSH) and Port 80 (HTTP) 
    - **Netowrking:**
      -   **Virtual Network:** We're going to use the virtual network that was created in the previous step.
      -   **Subnet:** `snet-web` --> We're using the subnet we created for the web
      -   **Public IP:** Standard (New)
          <img width="1210" height="1014" alt="Screenshot 2026-02-23 211535" src="https://github.com/user-attachments/assets/f44f7e06-6d8e-4c33-ba27-3555db6458a9" />
    - Click **Review + Create**

---

# Phase 3 — Deploy Database Server (Backend)
1. Create Virtual machine
    - **Resource Group:** select the resource group created in the previous step
    - **Virtual Machine Name:** `vm-db`  
    - **Region:** `East US`
    - **Security Type:** `Standard`
    - **Image:** `Ubuntu Server 20.04 LTS`
    - **Size:** `Standard_B1s`
    - **Authntication Type:** SSH Public Key
      - use existing key stord in Azure
        <img width="1204" height="913" alt="Screenshot 2026-02-23 212042" src="https://github.com/user-attachments/assets/f25e5d31-b80d-4edd-8388-2b8737437780" />
    - **Inbound Ports:**
      - Public Incoming Ports: set to None --> because it's on the backend, we do not want public access to this VM.
      - Select Port 22 (SSH) 
    - **Netowrking:**
      -   **Virtual Network:** We're going to use the virtual network that was created in the previous step.
      -   **Subnet:** `snet-db` --> We're using the subnet we created for the database
      -   **Public IP:**  **None** --> This ensures the database server remains private.
      -   Click **Review + Create**

---

# Phase 4 — Validate Internal Connectivity

### Get DB Private IP
      -  Navigate to `vm-db`, Copy Private IP (Example: `10.0.2.4`) and save it for the next step
          <img width="1789" height="382" alt="Screenshot 2026-02-23 212335" src="https://github.com/user-attachments/assets/50789589-7ce6-4953-ada7-5bea31367e88" />

### SSH into Web Server

- Navigate to `web-db`, Click `Connect`
  <img width="1082" height="393" alt="Screenshot 2026-02-23 212411" src="https://github.com/user-attachments/assets/25005705-5c3c-4f4d-972b-c1b20dd47dc1" />
- Copy the generated SSH command, `ssh -i <privae-key-file-path> azureuser@<web-public-ip`
- Open Terminal, navigate to the folder where you downloaded the key pair file
  - type in the command you copied and then hit Enter
    <img width="1180" height="1207" alt="Screenshot 2026-02-23 212622" src="https://github.com/user-attachments/assets/d8f11e0a-e8e8-4445-8008-33733925c20e" />
  - After hitting yes, we have verified that we can connect successully.
 
### Testing connecting to the Database Server

- ping the database server, `Ping 10.0.2.4` 
  <img width="921" height="459" alt="Screenshot 2026-02-23 212706" src="https://github.com/user-attachments/assets/394eb9db-886c-4c8e-ae32-5a605882aec2" />
- Pinging the database server shows successful pings

**If you want to see how to SSH into the DB Server from the Web Server , please watch the lab video.**
