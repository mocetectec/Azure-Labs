# How to Create a Linux VM in Azure via CLI

## Overview
This guide walks through creating a Linux Virtual Machine (VM) in Azure using the Azure CLI. 

## Environment Setup
- **Cloud Provider**: Azure
- **Services**: Virutal Machine
- **Virtual Machine Image**: Ubuntu2204
- **Virtual Machine Size**: Standard_D2s_v3

---

## Install Azure CLI (if not already installed)

Follow the official installation guide for your OS:  https://learn.microsoft.com/en-us/cli/azure/install-azure-cli

Verify installation: `az version`

## Login to Azure
 After installing Azure CLI, login to your Azure account using the `az login` command. This will open a browser window to authenticate.

 ## Set the Default Subscription (if you have multiple)
 If you have multiple subscriptions, you can run the command, `az account list --output table`, to display your subcriptions and their ID. 
   - Set the desired subscription: `az account set --subscription "sub-id"`
     - Replace "sub-id" with your actual subscription ID.

---

 ## Create a New Resource Group
 `az group create --name <resource-group-name> --location <region>`
 
 <img width="485" height="151" alt="image" src="https://github.com/user-attachments/assets/8b9a56ec-f2b0-400e-ad38-cb51c65c92cd" />

  Explanation of tags used:
   - `--name`: name of the resource group
   - `--location`: Region where you want the resources located
  
  To view a list of resource groups, use the command: `az group list`

 ## Create the Linux VM

 `az vm create --resource-group <resource-group-name> --location <region> --name <vm-name> --image Ubuntu2204 --size <vm-size> --generate-ssh-keys --admin-username <username>`

 Explanation of tags used:
   - `--resource-group`: Specifices what resource group you want the VM to reside in  
   - `--location`: Region where you want the resources located
   - `--name`: name of the VM
   - `--image`: Operating System image
   - `--size`: VM hardware specs
   - `--admin-username`: name of Administrator account
   - `--generate-ssh-keys`: creates an ssh key for the VM
 
 <img width="2039" height="111" alt="image" src="https://github.com/user-attachments/assets/3cbe6fe6-5bbe-47bf-ac68-2450462947d1" />

 Output when successfully created.
 <img width="2131" height="321" alt="image" src="https://github.com/user-attachments/assets/11e76174-8b66-417c-a995-e7a77ac74860" />

  You can also use this command to provide information on a specifc VM in your resource group. `az vm show --resource-group <resource-group-name> --name <vm-name> --output table`
  <img width="1033" height="133" alt="image" src="https://github.com/user-attachments/assets/44e30d06-c270-4fbb-8e56-4bb0c6e73e6e" />

  ## Confirm the Public IP Address
 ` az vm list-ip-addresses --resource-group <resource-group-name> --name <vm-name> --output table `
  <img width="1084" height="104" alt="image" src="https://github.com/user-attachments/assets/b93adc38-2f3b-4f3f-b214-7f8606446667" />

 ## Connect to the VM via SSH
 Use the command to connect to the VM: `ssh <username>@<public-ip-address>`

 <img width="750" height="750" alt="image" src="https://github.com/user-attachments/assets/73029507-d4d1-4f54-bc4e-683b4a934cb5" />

 ## ✅ Done!

Successfully created and connected to a Linux VM in Azure using the CLI.

## Clean Up Resources

To delete the VM and resource group when finished: `az group delete --name <resource-group-name> --yes --no-wait` If run the command `az group list`, you will see that the provisioning state of the group is in the process of deleting.

Explanation of tags used:
   - `--yes`: skips the confirmation prompt
   - `--no-wait`: deletes the resource-group in the background and gives the temrinal control back to you

<img width="1089" height="630" alt="image" src="https://github.com/user-attachments/assets/69c12e12-5079-447b-9cf1-fc368628b48b" />
