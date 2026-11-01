# Sky Height PG Backend — Render Deployment Guide

This guide covers deploying the **Sky Height PG** Node.js backend on [Render](https://render.com) using the GitHub repository.

---

## 1. Service Specification

| Setting | Value |
| :--- | :--- |
| **Service Type** | Web Service |
| **Language / Runtime** | Node |
| **Region** | Singapore / Frankfurt / Oregon (Choose closest to your users) |
| **Branch** | `master` (or your deployment branch) |
| **Root Directory** | `backend` |
| **Build Command** | `npm install` |
| **Start Command** | `npm start` |
| **Health Check Path** | `/health` (or `/api/health`) |
| **Instance Type** | Free |

---

## 2. Environment Variables Configuration

Render dynamically manages container ports via `PORT` (do **NOT** manually set `PORT`). 

Configure the following environment variables in the Render Dashboard under **Environment**:

| Variable Name | Required | Default / Example Value | Description |
| :--- | :---: | :--- | :--- |
| `NODE_ENV` | Yes | `production` | Enables production security headers, rate limiting, and sanitized error messages. |
| `MONGODB_URI` | Yes | `mongodb+srv://<user>:<password>@cluster0.abcde.mongodb.net/skyheightpg?retryWrites=true&w=majority` | Your MongoDB Atlas connection URI string. |
| `JWT_SECRET` | Yes | *32+ random characters* | Cryptographic secret for signing and verifying JSON Web Tokens. |
| `ALLOWED_ORIGINS` | No | `https://yourdomain.com` | Comma-separated list of web frontend origins allowed by CORS (mobile apps do not require this). |
| `CUSTOM_DNS` | No | `false` | Optional flag; set to `true` only if custom DNS servers (8.8.8.8) are required. |

> [!WARNING]
> **Zero Secrets Policy**: Never commit `.env` or paste real secrets into Git repositories or issue trackers. Always set secret values securely via the Render Dashboard.

---

## 3. Step-by-Step Deployment Instructions

### Method A: Deploy via Render Web Service (Recommended)

1. Log in to your [Render Dashboard](https://dashboard.render.com/).
2. Click **New +** and select **Web Service**.
3. Under **Connect a repository**, select your GitHub repository: `212myash/SkyHeightPG`.
4. Configure service parameters:
   - **Name:** `skyheightpg-backend`
   - **Root Directory:** `backend` *(Critical: Tells Render the Node project is in the `backend` folder)*
   - **Runtime:** `Node`
   - **Build Command:** `npm install`
   - **Start Command:** `npm start`
5. Scroll down to **Environment Variables** and add:
   - Key: `NODE_ENV`, Value: `production`
   - Key: `MONGODB_URI`, Value: *(Paste your MongoDB Atlas connection string)*
   - Key: `JWT_SECRET`, Value: *(Paste your strong random JWT secret string)*
6. Expand **Advanced**:
   - **Health Check Path:** `/health`
   - **Auto-Deploy:** `Yes`
7. Click **Create Web Service**.
8. Render will pull the code, run `npm install`, start `server.js`, and verify `/health`.

---

### Method B: Deploy via Render Blueprint (Infrastructure-as-Code)

If using the repository's root `render.yaml`:

1. In the Render Dashboard, click **New +** and select **Blueprint**.
2. Connect your GitHub repository `212myash/SkyHeightPG`.
3. Render reads `render.yaml` and preconfigures the `skyheightpg-backend` service.
4. Render will prompt you in the web UI for the `sync: false` variables:
   - `MONGODB_URI`
   - `JWT_SECRET`
5. Enter the values and click **Apply**.

---

## 4. Testing Your Deployed Backend

Once Render displays **Live**, your backend URL will look like:
`https://skyheightpg-backend.onrender.com`

### 1. Health Check
```bash
curl https://skyheightpg-backend.onrender.com/health
```
**Expected Response:**
```json
{
  "status": "healthy",
  "uptime": 42,
  "timestamp": "2026-11-01T17:15:00.000Z"
}
```

### 2. Root API Check
```bash
curl https://skyheightpg-backend.onrender.com/
```
**Expected Response:**
```json
{
  "success": true,
  "message": "Sky Height PG Backend is Running!",
  "environment": "production"
}
```

### 3. Public Settings Endpoint
```bash
curl https://skyheightpg-backend.onrender.com/api/settings
```
**Expected Response:**
```json
{
  "success": true,
  "data": {
    "pgName": "Sky Height PG",
    "electricityRatePerUnit": 12,
    ...
  }
}
```

---

## 5. Troubleshooting Common Deployment Errors

### 1. MongoDB Connection Timeout or Whitelist Error
- **Symptom:** Logs show `MongooseServerSelectionError: connect ECONNREFUSED` or `Server selection timed out`.
- **Cause:** MongoDB Atlas Network Access IP Whitelist does not allow connections from Render.
- **Solution:**
  1. Open [MongoDB Atlas](https://cloud.mongodb.com/).
  2. Go to **Network Access** under Security.
  3. Ensure IP address `0.0.0.0/0` (Allow Access from Anywhere) is added. Render uses dynamic outgoing IP addresses on the free tier.
  4. Ensure your database user credentials in `MONGODB_URI` are correct and password special characters are URL-encoded if applicable.

### 2. Service Crashes with Missing `JWT_SECRET` or `MONGODB_URI`
- **Symptom:** Startup fails or authentication returns 500 error.
- **Solution:** Double-check the **Environment** tab in Render Dashboard. Ensure variable names match exactly (case-sensitive): `MONGODB_URI`, `JWT_SECRET`, and `NODE_ENV`.

### 3. Build Fails in Root Directory
- **Symptom:** Logs show `package.json not found`.
- **Cause:** Root Directory was left blank instead of `backend`.
- **Solution:** In Render Dashboard, go to **Settings** -> **Root Directory**, enter `backend`, and save changes.

### 4. Free Tier Spin-Down / Sleep
- **Symptom:** The first request after 15 minutes of inactivity takes 30-50 seconds to respond.
- **Explanation:** Render free tier instances sleep after 15 minutes of idle time. The application wakes up automatically on the next incoming request.
- **Recommendation:** Use an external free monitoring service (e.g. UptimeRobot, BetterStack) to ping `https://your-service.onrender.com/health` every 10 minutes if continuous instant availability is required.
