## 🎬 [Watch Me Build This Lab!](https://www.loom.com/share/8987ab76277744c69d1cb369bf995c12)

# Hosting a Static Website on an Azure Storage Account

This guide explains how to create a static website using Azure Blob Storage.

## Environment Setup
- **Cloud Provider**: Azure
- **Service**: Azure Blob Storage

### Step 1: Create Azure Storage Account
- In Azure portal, search and click **Storage Accounts**
  ![StaticWeb0 1](https://github.com/user-attachments/assets/2246e6b6-43c1-4766-9026-9bd22a61d68e)

- Click **Create**
  <img width="1130" height="767" alt="StaticWeb" src="https://github.com/user-attachments/assets/48686095-610b-4cc1-9ab3-b9d29d4edeaa" />

- Create a **new Resource group**
  ![StaticWeb1 1](https://github.com/user-attachments/assets/ae249a23-52f8-4e6d-9a93-680d9a64b9ad)

- Click **OK**
  ![StaticWeb2](https://github.com/user-attachments/assets/497d785d-0966-45ff-8f1c-8ed4fa28e9fc)

- Click **Storage account name** and create a name, all lowercase
  <img width="1165" height="675" alt="StaticWeb1" src="https://github.com/user-attachments/assets/329fea99-ba30-49ad-ad99-37a8c927113b" />

- Click **Preferred Storage Type** and select **Azure Blob Storage**. **Performance** should stay as **Standard** and **Redundancy** should be **Geo-Redundant Storage**
  ![StaticWeb3](https://github.com/user-attachments/assets/1f8428bd-6e3a-48c9-9302-9d198f0e12a3)

- Click **Review + create**, you will see a validation progress bar before you can create the account.
  <img width="1213" height="604" alt="StaticWeb4" src="https://github.com/user-attachments/assets/6e1162a0-7570-4d0b-bd9f-3bd5753f2940" />

  <img width="1191" height="410" alt="Screenshot 2026-02-23 152722" src="https://github.com/user-attachments/assets/18588018-d786-4855-9002-2a4a00f703f1" />

-   Click **Create**. You will see the window change to deployment in progress.
![StaticWeb5](https://github.com/user-attachments/assets/edd43216-feff-4983-bc48-1e009d8db8c6)

<img width="1089" height="570" alt="Screenshot 2026-02-23 152735" src="https://github.com/user-attachments/assets/b00bcf84-7d90-47c6-8fdd-5a37d16bcf11" />

###  Step 2: Configure the Storage Account to host web content

- Once the deployment is completed. Click **Go to resource**
 ![StaticWeb11](https://github.com/user-attachments/assets/8877b0ac-3d6a-4cd5-b6ae-c06faa2e6451)

- On the left, Click **Data management**
  ![StaticWeb12](https://github.com/user-attachments/assets/17e83927-7ec5-408e-a74a-df33f22e6484)

- Click **Static website**
  ![StaticWeb13](https://github.com/user-attachments/assets/73f35d77-4434-411b-8c9d-671e3e267a24)

- **Enable** Static Website
  ![StaticWeb14](https://github.com/user-attachments/assets/ecb129ea-169e-420c-8b37-61d1a1fea3f1)

- Click **Index document name** and type in **index.html**. Click **Error document path** and type in **404.html**. Click **Save**. Once saved, you will see the primary endpoint generate a URL.
  <img width="820" height="800" alt="image" src="https://github.com/user-attachments/assets/3f298251-c85c-4816-a2a9-ce04c8347371" />

### Step 3: Upload html file to storage account.
- On the left, Click **Data storage**
  ![StaticWeb19](https://github.com/user-attachments/assets/2e615323-0894-4272-b2ad-253abf75f1e7)

- Click **Containers**
  ![StaticWeb20](https://github.com/user-attachments/assets/3f879771-a662-47ea-991e-3aaf1c7e9296)

- Click **$web**
  ![StaticWeb21](https://github.com/user-attachments/assets/e52563ec-7623-4741-96c5-b89a21d7a470)

- Click **Upload**, Click **Browse for files**, and upload the index.html file you created
  <img width="1331" height="587" alt="Screenshot 2026-02-23 155754" src="https://github.com/user-attachments/assets/12b48b14-cf85-44ad-bd6d-74b9f3031152" />


### Step 4: Verify website is functional and displays properly.
- Copy the Primary endpoint link that was generated when you enabled the static website. Open a new tab, and paste the link. You'll know you did everything correct when you can successfully display your index.html file.
  <img width="2048" height="490" alt="Screenshot 2026-02-23 143506" src="https://github.com/user-attachments/assets/27b8bcff-9dcd-4922-8d53-beffc3ec10eb" />



