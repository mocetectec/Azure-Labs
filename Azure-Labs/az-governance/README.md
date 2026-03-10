## 🎬 [Watch Me Build This Lab!](https://www.loom.com/share/601ed6d9776648fdb84a8733fc158ce4)

# Azure Governance with RBAC, Policy, and Budgets

## Project Overview

This project demonstrates Azure governance by creating a restricted user with RBAC permissions, enforcing deployment rules using Azure Policy to block expensive resources, and setting up a cost management budget to monitor and control cloud spending. I will go over the following:

- Create a new user in **Microsoft Entra ID**
- Assign them limited permissions using **RBAC**
- Enforce rules using **Azure Policy** to prevent expensive deployments
- Set up a **Budget** to alert on spending

---

## Phase 1: Create a Resource Group

1. Log in to the **Azure Portal** using your main account.
2. Create a new **Resource Group** with the following settings:
   - **Name:** `rg-lab05-gov-[yourname]`
   - **Region:** `East US`
3. Click **Review + create** → **Create**

---

## Phase 2: RBAC (Role-Based Access Control)

We will simulate hiring a junior developer who should only be able to **view resources**, not modify them.

### Create a New User

1. Search for **Microsoft Entra ID** in the Azure Portal search bar
   
     <img width="761" height="479" alt="Screenshot 2026-03-07 190531" src="https://github.com/user-attachments/assets/85da7b34-e0c0-4bc8-836b-8155e20f5d48" />

2. In the left menu, click **Users** → **New user** → **Create new user**

    <img width="865" height="487" alt="Screenshot 2026-03-07 190559" src="https://github.com/user-attachments/assets/e7fc513b-bed9-4602-8925-c5f90a595197" />
   
3. Under **Basics**, enter:
   - **User principal name:** `junior-dev-[yourname]`  
     - The domain will auto-fill, such as `@yourtenant.onmicrosoft.com`
   - **Display name:** `Junior Developer`
   - **Password:** Uncheck **Auto-generate** and enter a password you will remember

      <img width="648" height="465" alt="Screenshot 2026-03-07 190614" src="https://github.com/user-attachments/assets/e59c5a88-2720-47f4-87e7-ee689c8c0606" />

4. Click **Review + create** → **Create**

### Assign the Reader Role

1. Go back to **Resource Groups** created in the previous step → `rg-lab05-gov-[yourname]`
2. Click **Access control (IAM)** on the left menu
   
     <img width="891" height="466" alt="Screenshot 2026-03-07 190820" src="https://github.com/user-attachments/assets/a6c139f5-49c0-4ad1-9c6c-59b79ceba4b5" />

3. Click **+ Add** → **Add role assignment**

     <img width="868" height="497" alt="Screenshot 2026-03-07 190858" src="https://github.com/user-attachments/assets/dbeab899-9e2e-4226-a340-8a74a8e0fcc4" />

4. For **Role**, search for and select **Reader**

     <img width="863" height="471" alt="Screenshot 2026-03-07 190908" src="https://github.com/user-attachments/assets/83742c6b-9058-4ef7-b9d7-9be0934c2125" />

5. Click **Next**
6. Under **Members**, click **+ Select members**

     <img width="876" height="451" alt="Screenshot 2026-03-07 190916" src="https://github.com/user-attachments/assets/5e27bf90-3065-4264-af77-5d7a51d4747a" />
   
7. Search for **Junior Developer** and select the user

     <img width="652" height="470" alt="Screenshot 2026-03-07 190926" src="https://github.com/user-attachments/assets/4ce01b4e-f53c-4bc6-ad1e-d2ba293c6b57" />
    
8. Click **Review + assign** → **Review + assign**

---

## Phase 3: Verify Access (The "Access Denied" Test)

1. Open a new **Incognito/Private** browser window
2. Go to `https://portal.azure.com`
3. Log in as `junior-dev-[yourname]@[yourdomain]`
4. Navigate to **Resource Groups** → `rg-lab05-gov-[yourname]`
5. Try to create a resource:
   - Click **+ Create** inside the resource group
   - Search for **Storage Account**
   - Attempt to create one

### Expected Result

Validation should fail, or the **Create** button will be greyed out. You may also see a red banner stating that you do not have authorization.

<img width="863" height="487" alt="Screenshot 2026-03-07 190947" src="https://github.com/user-attachments/assets/39c0c60e-7188-4bda-b9e2-53f2eb0f8858" />

<img width="686" height="513" alt="image" src="https://github.com/user-attachments/assets/95795548-6313-4812-ad02-f48372632df9" />

**Success:** You have successfully restricted this user. Close the Incognito window.

---

## Phase 4: Azure Policy

Now, back in your **Admin** account, you will ensure nobody, including you, can deploy expensive virtual machines in this lab resource group.

1. Search for **Policy** in the Azure Portal search bar

    <img width="869" height="493" alt="Screenshot 2026-03-07 191012" src="https://github.com/user-attachments/assets/b91605d5-dcb0-42a6-ae0e-a2d4347505fd" />

2. Under **Authoring**, click **Assignments**
3. Click **Assign policy**
   
    <img width="862" height="439" alt="Screenshot 2026-03-07 191056" src="https://github.com/user-attachments/assets/fce2303e-dcf1-49ef-99e2-91978ad0add8" />

### Basics

- **Scope:** Click the `...` button  
  - Select your **subscription**
  - Specifically select `rg-lab05-gov-[yourname]` as the **Resource Group**

    <img width="558" height="480" alt="Screenshot 2026-03-07 191122" src="https://github.com/user-attachments/assets/8265d9d3-c245-4b22-b01a-06c0d946b556" />

  - This ensures the policy only applies to the lab group

- **Policy definition:** Click `...`  
  - Search for **Allowed virtual machine size SKUs**
  - Select it

    <img width="873" height="594" alt="Screenshot 2026-03-07 191145" src="https://github.com/user-attachments/assets/fc5a8682-48ec-4b23-888d-647d2a2fc416" />
    
- **Assignment name:** `Restrict-VM-Sizes`

### Parameters

1. Uncheck **Only show parameters that need input**
2. For **Allowed Size SKUs**, select **only**:
   - `Standard_B1s`
   - `Standard_B1ms`

    <img width="758" height="479" alt="Screenshot 2026-03-07 191211" src="https://github.com/user-attachments/assets/55b237de-611d-4125-b7dd-e6c8ab191f68" />

This means that if anyone tries to deploy a **D-series** or **G-series** VM, the deployment will be blocked.

3. Click **Review + create** → **Create**

**Note:** Policies can take **15–30 minutes** to take effect. If the test below does not work immediately, wait and try again later.

---

## Phase 5: Test the Policy

1. Go to `rg-lab05-gov-[yourname]`
2. Click **Create** → **Virtual Machine**

### Basics

- **Name:** `vm-policy-test`
- **Image:** `Ubuntu Server`
- **Size:** Change the size to any size that is **not** `B1s` or `B1ms`
3. Click **Review + create**

### Expected Result

You should see a **Validation Failed** error.

  <img width="723" height="485" alt="Screenshot 2026-03-07 191219" src="https://github.com/user-attachments/assets/a0a35f4a-8bf3-4763-87f1-8151acefeec8" />

Click the error message. It should indicate:

- **Policy check failed**
- The reason is **Restrict-VM-Sizes**

    <img width="666" height="491" alt="Screenshot 2026-03-07 191226" src="https://github.com/user-attachments/assets/a0a76113-b2b9-4e19-9913-ffda020e21f0" />

**Success:** You have governed the environment.

---

## Phase 6: Cost Management

1. Go to `rg-lab05-gov-[yourname]`
2. On the left menu, search for **Budgets** under **Cost Management**

    <img width="788" height="424" alt="Screenshot 2026-03-07 191240" src="https://github.com/user-attachments/assets/a8bba1ef-32c3-4855-80f6-fe86c1edd868" />

3. Click **+ Add**

    <img width="868" height="493" alt="Screenshot 2026-03-07 191250" src="https://github.com/user-attachments/assets/b318e846-22be-4a52-ae2a-d85df7a1983c" />

### Create Budget

Enter the following settings:

- **Name:** `Monthly-Lab-Budget`
- **Reset period:** `Billing month`
- **Creation date:** `Today`
- **Expiration date:** `1 year from now`
- **Amount:** `50` dollars

    <img width="548" height="462" alt="Screenshot 2026-03-07 191259" src="https://github.com/user-attachments/assets/22255e20-4c81-4973-aca5-d2e9f3ee751d" />

4. Click **Next**

### Set Alerts

- **Type:** `Actual`
- **% of budget:** `80`
- **Alert recipients (email):** Enter your personal email address

    <img width="481" height="452" alt="Screenshot 2026-03-07 191313" src="https://github.com/user-attachments/assets/376662c8-d37b-4cea-bc49-8940d0a072b9" />

5. Click **Create**

---

## Outcome

By completing this lab, you have:

- ✅Created a lab-specific **Resource Group**
- ✅Created a **Microsoft Entra ID** user
- ✅Restricted that user with the **Reader** RBAC role
- ✅Applied an **Azure Policy** to block expensive VM sizes
- ✅Created a **Budget** to monitor lab spending
