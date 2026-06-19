# Deploy Centaurion to Render - Step by Step

## Step 1: Connect GitHub to Render

1. Go to [dashboard.render.com](https://dashboard.render.com)
2. Click **"New +"** → **"Web Service"**
3. Click **"Connect a repository"**
4. Authorize GitHub if prompted
5. Find and select **"Centaurion"** repo
6. Click **"Connect"**

## Step 2: Configure Web Service

Fill in these settings:

| Setting | Value |
|---------|-------|
| **Name** | centaurion |
| **Environment** | Docker |
| **Region** | Choose closest to you |
| **Branch** | main |

## Step 3: Build Settings

> **Note:** A `render.yaml` Blueprint at the repo root already encodes these
> settings. Connecting via Blueprint is preferred over filling them in by hand.

| Setting | Value |
|---------|-------|
| **Dockerfile Path** | `Dockerfile` (the root Dockerfile — React frontend + FastAPI backend) |
| **Docker Context** | `./` |

## Step 4: Environment Variables

Click **"Advanced"** → **"Environment Variables"**

Add these variables:

| Key | Value |
|-----|-------|
| `PORT` | `8000` |

## Step 5: Deploy

1. Click **"Create Web Service"**
2. Wait for build (~3-5 minutes)
3. Live at `https://centaurion.onrender.com`

---

## Updating Deploy

Just push to GitHub - Render auto-deploys!

```bash
git add .
git commit -m "Update"
git push origin main
```
