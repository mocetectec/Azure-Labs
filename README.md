## 🎬 [Watch Me Build This Lab!](https://www.loom.com/share/9c99918305424387ad71142a716f8974)

# Terraform Azure Networking Lab

This lab demonstrates how to use **Terraform in Azure Cloud Shell** to deploy basic Azure networking resources:

- Resource Group
- Virtual Network
- Subnet
- Network Security Group (NSG)

I will create the first 3 resources and then demonstrate what it looks like to add a resource to the existing configuration.

---
## Architecture Design
<img width="750" height="800" alt="image" src="https://github.com/user-attachments/assets/28c5859c-d5ec-45c2-8688-4a1533cddde0" />

---

# Step 1 – Open Azure Cloud Shell

1. Log in to the **Azure Portal**
2. Click the **Cloud Shell icon** in the top-right menu (`>_`)

   <img width="325" height="103" alt="Screenshot 2026-03-06 112727" src="https://github.com/user-attachments/assets/5155fce2-ad17-45c3-a486-abf0daf4666a" />

3. Wait for the terminal to initialize

Cloud Shell already has **Terraform installed**, so no installation is required.

---

# Step 2 – Create a Project Directory

Create a directory for the Terraform lab.

```bash
mkdir terraform-lab
cd terraform-lab
```
# Step 3 – Create the Terraform Configuration File

Open the built-in code editor. This will also create the main.tf as well.

```bash
code main.tf
```
Paste your code into the editor. Save and exit the editor.
```
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# 2. Define the Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-lab04-tf-mocete"  # CHANGE THIS TO YOUR NAME
  location = "East US"
}

# 3. Define the Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-terraform"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

#Define a subnet
resource "azurerm_subnet" "subnet" {
  name                 = "snet-backend"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}
```
```bash
Ctrl + S   # Save the file
Ctrl + Q   # Close the editor
```

# Step 4 – Initialize Terraform

Initialize the working directory and download the required Azure provider.

```bash
terraform init
```
<img width="750" height="579" alt="image" src="https://github.com/user-attachments/assets/5150e486-2c8d-4655-9d7c-34b5632dad2a" />


# Step 5 – Preview the Deployment Plan

Generate a plan to review the infrastructure changes before deployment.

```bash
terraform  plan
```

The output will display a summary of how many resouces will be added to our environment.

<img width="572" height="68" alt="image" src="https://github.com/user-attachments/assets/088d66e8-7074-4ce6-97f5-1328bdf9c962" />

Terraform is clear to create:
- 1 Resource Group
- 1 Virtual Network
- 1 Subnet


# Step 6 – Deploy the Infrastructure

Apply the Terraform configuration.

```bash
terraform  apply
```

Terraform will ask for confirmation.

<img width="725" height="222" alt="image" src="https://github.com/user-attachments/assets/b0d43b91-f267-47bd-8553-d3b4855bff6e" />

Type: `yes` Terraform will now create the Azure resources.

<img width="804" height="275" alt="image" src="https://github.com/user-attachments/assets/4d839a1b-76a8-4030-bf7f-c241c80cd57c" />

# Step 7 - Add another resource to create

- Open the built-in code editor.

  ```bash
  code main.tf
  ```
- Put in the code to add Network Security Group to the configuration file
  
    ```bash
    #Define a Network Security Group
    resource "azurerm_network_security_group" "nsg" {
      name                = "nsg-web"
      location            = azurerm_resource_group.rg.location
      resource_group_name = azurerm_resource_group.rg.name
    }
    ```

- Generate a plan to review infrastructure changes using `terraform plan`. We see the plan shows the Network Security Group resource will be added to our current infrastructe setup. 
  
  <img width="602" height="78" alt="image" src="https://github.com/user-attachments/assets/27564d04-13c2-4e1b-bba7-b16a697021d4" />
  
- Apply the changes to create the resource using `terraform apply`.
  
  <img width="825" height="128" alt="image" src="https://github.com/user-attachments/assets/f7e8a442-12fe-4ae3-aa9e-d9256c423f74" />

# Step 8 – Verify the Deployment

You can verify the deployed infrastructure in the Azure Portal:

1. Navigate to Resource Groups
2. Open resource group created
3. Confirm the following resources exist:
- Virtual Network
- Subnet
- Network Security Group

<img width="2071" height="552" alt="image" src="https://github.com/user-attachments/assets/41c5cb55-a31d-4166-a5a1-8ea90c47661f" />

# Step 9 – Clean Up Resources (Optional)

To delete all resources created in the lab: `terraform destroy`
Confirm the deletion by typing: `yes`

<img width="986" height="220" alt="image" src="https://github.com/user-attachments/assets/05aca7a1-968c-4fc8-bbf8-2a4578b2b445" />

Confirmation that resources are deleted.

<img width="735" height="424" alt="image" src="https://github.com/user-attachments/assets/6a63a3c4-6d3a-4bc8-9f87-e650c193cba1" />

  
