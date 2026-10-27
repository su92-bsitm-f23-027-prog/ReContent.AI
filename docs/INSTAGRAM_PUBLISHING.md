# Instagram photo publishing

ReContent can publish an Instagram feed photo and caption from the content editor. It uses Meta's official Instagram API. The Instagram account must be a Creator or Business account. A personal account cannot use this publishing flow.

## Meta setup required

1. Create a Meta developer app and add the Instagram API with Instagram Login.
2. In the Meta app's Instagram login settings, allow this exact callback URL:
   `https://YOUR_PUBLIC_API_HOST/api/integrations/instagram/callback/`
3. Enable `instagram_business_basic` and `instagram_business_content_publish` for the app. The account used during development must have a role on the Meta app. Meta app review/advanced access is needed before unrelated users can connect.
4. Copy the app ID and app secret into the backend's private environment settings. Never put the app secret in Flutter, a screenshot, or Git.

## Backend environment

Set these values in `backend/.env` for local development and in the backend host's environment dashboard for deployment:

```dotenv
INSTAGRAM_APP_ID=your-meta-app-id
INSTAGRAM_APP_SECRET=your-meta-app-secret
INSTAGRAM_REDIRECT_URI=https://YOUR_PUBLIC_API_HOST/api/integrations/instagram/callback/
INSTAGRAM_GRAPH_VERSION=v25.0
PUBLIC_API_ORIGIN=https://YOUR_PUBLIC_API_HOST
```

`INSTAGRAM_REDIRECT_URI` must match the URL entered in the Meta app exactly, including `https://`, path, and trailing slash. `PUBLIC_API_ORIGIN` must be the public HTTPS origin of the same backend that receives image uploads. Instagram's servers must be able to fetch the uploaded image; a `localhost` or `127.0.0.1` URL cannot be fetched by Meta.

## Run and use

Install backend dependencies and apply the new database migrations:

```powershell
cd C:\Users\HP\Documents\ReContent.AI\backend
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe manage.py migrate
```

Start the Flutter web app with `API_BASE_URL` set to the deployed HTTPS backend, not localhost, if you intend to publish. Then open an Instagram content item, choose a photo, connect the Creator/Business account, and select **Publish now**. ReContent asks for confirmation before it sends the post. Instagram performs the publishing; ReContent does not receive or store your Instagram password.

The existing calendar only stores planned times/reminders. This integration publishes immediately when **Publish now** is confirmed; automatic scheduled publishing requires a separately deployed background worker.

## Meta API flow

The backend exchanges Instagram OAuth codes for a long-lived token, encrypts the token in the database, uploads a signed temporary HTTPS image URL to Meta's media container endpoint, waits for media processing, and calls `media_publish`. Meta's official API collection documents the professional-account requirement and the media-container then publish flow: [Instagram API on Meta's Postman workspace](https://www.postman.com/meta/instagram/documentation/6yqw8pt/instagram-api).
