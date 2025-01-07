# GitLab and Jenkins Integration Guide

This document provides detailed steps to integrate GitLab and Jenkins for seamless CI/CD workflows.

---

## 1. Log in to GitLab and Create API Tokens

### Project-Level Token
1. Log in to your GitLab account.
2. Navigate to the specific project for which you want to create a token.
3. Go to **Settings > Access Tokens**.
4. Add a token name, set its expiration date (optional), and assign necessary scopes (`read_api`, `write_repository`, etc.).
5. Click **Create Personal Access Token** and copy the token. **Store this securely.**

### Group-Level Token
1. Log in to your GitLab account.
2. Navigate to the group where the projects are housed.
3. Go to **Settings > Access Tokens** under the group settings.
4. Follow the same steps as above to create the token.

---

## 2. Install GitLab Plugins in Jenkins

Ensure your Jenkins server has the following plugins installed:
- **GitLab Plugin**
- **GitLab API Token Plugin**

### Installation Steps
1. Log in to your Jenkins server.
2. Go to **Manage Jenkins > Plugin Manager**.
3. Search for the above plugins in the **Available Plugins** tab.
4. Install the plugins and restart Jenkins.

---

## 3. Configure GitLab in Jenkins

### Step 1: Add GitLab in Jenkins System Configuration
1. Go to **Manage Jenkins > System Configuration**.
2. Scroll to the **GitLab** section.
3. Provide a **name** for the connection (e.g., `MyGitLab`).
4. Add the **GitLab server host URL** (e.g., `https://gitlab.com`).

### Step 2: Add GitLab Credentials
1. Click **Add Credentials**.
2. Select:
   - **Kind**: GitLab API Token
   - **Domain**: Global credentials
   - **Scope**: Global
3. Paste the API token created earlier.
4. Assign a unique **ID** and name.
5. Click **Test Connection** to verify the integration.

### Step 3: Save and Apply
Once the connection is verified, click **Save** and **Apply**.

---

## 4. Configure GitLab Project for Jenkins Integration

### Step 1: Set Up Integration in GitLab
1. Go to your project in GitLab.
2. Navigate to **Settings > Integrations**.
3. Select **Jenkins** from the list of available integrations.
4. Enable the integration by ticking **Enable Integration**.

### Step 2: Configure Integration Settings
- **Triggers**: Select triggers (e.g., `Push Events`, `Merge Request Events`).
- **Jenkins Server URL**: Add your Jenkins server base URL (e.g., `http://jenkins-server.local`).
- **Project Name**: Enter the exact Jenkins job/project name.
- **Credentials**: Add credentials (either username/password or a secret token).

### Step 3: Save and Verify Connection
- Save the configuration.
- Test the connection to verify the integration.

---

## 5. Create a Webhook in GitLab for Jenkins

If required, manually configure webhooks for Jenkins.

### Step 1: Enable Outbound Requests in GitLab
1. Log in to GitLab as an admin.
2. Go to **Admin > Settings > Network**.
3. Under **Outbound Requests**, enable **Allow requests to the local network from hooks and services**.

### Step 2: Add a New Webhook
1. In your GitLab project, go to **Settings > Webhooks**.
2. Click **Add Webhook**.
3. Configure the webhook:
   - **URL**: Use the Jenkins pipeline URL (found in **Build Triggers > Advanced > Secret Token**).
   - **Triggers**: Select the events to trigger the webhook (e.g., `Push Events`, `Merge Requests`).
   - **Token**: Generate a secret token in Jenkins and add it here.
4. Save the webhook.

---

## 6. Troubleshooting Common Issues

### 403: Anonymous Missing Job Build Permission
1. Go to **Manage Jenkins > Configure Global Security**.
2. Under **Authorization**, uncheck **Enable authentication for '/project' endpoint**.
3. If using GitLab EE:
   - Use username and password for webhook authentication.
   - Alternatively, allow **Anonymous Users** to perform actions (**for testing purposes only**).

### Ensure Jenkins Server Host is Resolved in GitLab
- Verify that the Jenkins server hostname resolves correctly from the GitLab server.
- Use `ping` or `nslookup` to confirm.

### Token Authentication
1. In Jenkins, go to **Job > Configure > Build Triggers > Advanced**.
2. Generate a **Secret Token** at the bottom of the **Build Triggers** section.
3. Use this token in the GitLab webhook settings.

---

## Additional Notes
- Ensure your Jenkins server is accessible from the GitLab server.
- Use secured communication (e.g., HTTPS) for production environments.
- Regularly review and update API tokens for security.

---

## References
- [GitLab Documentation](https://docs.gitlab.com)
- [Jenkins Documentation](https://www.jenkins.io/doc)
