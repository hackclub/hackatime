# OAuth Apps

Build integrations with Hackatime using OAuth 2.0. Create an OAuth app to let users authorize your application to access their Hackatime data.

## Overview

Hackatime uses [OAuth 2.0](https://oauth.net/2/) (powered by Doorkeeper) to let third-party applications access user data on their behalf. This is the recommended way to build integrations -- users authorize your app through a consent screen and you receive an access token to make API requests.

## Creating an OAuth App

1. Sign in to your Hackatime account
2. Go to [My OAuth Apps](https://hackatime.hackclub.com/oauth/applications)
3. Click **New Application**
4. Fill in the form:
   - **Name** -- a human-readable name for your app (shown on the consent screen)
   - **Redirect URIs** -- one URI per line where users are sent after authorizing (e.g. `https://orpheus.gg/auth/callback`)
   - **Scopes** -- the permissions your app needs (see [Scopes](#scopes) below)
   - **Confidential** -- check this if your app can keep a client secret safe (server-side apps). Leave unchecked for native/mobile/SPA apps.
5. Click **Submit**

After creation you will see your **Client ID** (UID) and **Client Secret**. Store the secret securely -- you won't be able to view it again.

## Scopes

Scopes control what data your app can access. Request only the scopes you need.

| Scope | Description | Granted by Default |
|-------|-------------|-------------------|
| `profile` | Access basic profile information (user ID, email addresses, Slack ID, GitHub username, trust factor) | Yes |
| `read` | View basic info about the user's Hackatime account | No |

If you don't specify any scopes, only the `profile` scope is granted.

When requesting scopes in the authorization URL, separate multiple scopes with spaces:

```
scope=profile+read
```

## Authorization Flow

Hackatime supports the standard **Authorization Code** flow. PKCE (Proof Key for Code Exchange) is also supported for public clients.

### Step 1: Redirect Users to Authorize

Send users to the authorization endpoint:

```
GET https://hackatime.hackclub.com/oauth/authorize
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `client_id` | Yes | Your app's UID |
| `redirect_uri` | Yes | Must match one of your registered redirect URIs |
| `response_type` | Yes | Set to `code` |
| `scope` | No | Space-separated list of scopes (defaults to `profile`) |
| `state` | Recommended | A random string to prevent CSRF attacks. You should verify this matches when the user is redirected back. |
| `code_challenge` | For PKCE | The code challenge for PKCE |
| `code_challenge_method` | For PKCE | The method used to generate the challenge (e.g. `S256`) |

**Example:**

```
https://hackatime.hackclub.com/oauth/authorize?client_id=YOUR_CLIENT_ID&redirect_uri=https://example.com/auth/callback&response_type=code&scope=profile+read&state=random_string
```

The user sees a consent screen showing your app name and the permissions you are requesting. If your app is not verified, a warning is displayed to the user.

### Step 2: Handle the Callback

After the user authorizes (or denies), they are redirected to your `redirect_uri` with a `code` parameter:

```
https://example.com/auth/callback?code=AUTHORIZATION_CODE&state=random_string
```

If the user denies authorization, the callback includes an `error` parameter instead.

### Step 3: Exchange the Code for a Token

Make a `POST` request to the token endpoint to exchange the authorization code for an access token:

```
POST https://hackatime.hackclub.com/oauth/token
```

**Parameters (form-encoded body):**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `client_id` | Yes | Your app's UID |
| `client_secret` | Yes (confidential apps) | Your app's secret |
| `code` | Yes | The authorization code from the callback |
| `redirect_uri` | Yes | Must match the URI used in the authorization request |
| `grant_type` | Yes | Set to `authorization_code` |
| `code_verifier` | For PKCE | The original code verifier if you used PKCE |

**Example response:**

```json
{
  "access_token": "abc123...",
  "token_type": "Bearer",
  "expires_in": 504576000,
  "scope": "profile read",
  "created_at": 1700000000
}
```

Access tokens are long-lived (approximately 16 years) so you typically don't need to worry about refreshing them.

### Step 4: Make API Requests

Use the access token in the `Authorization` header:

```
GET https://hackatime.hackclub.com/api/v1/authenticated/me
Authorization: Bearer YOUR_ACCESS_TOKEN
```

## OAuth-Authenticated API Endpoints

All endpoints below require a valid OAuth access token in the `Authorization: Bearer <token>` header.

### GET /api/v1/authenticated/me

Returns information about the authenticated user.

**Response:**

```json
{
  "id": 123,
  "emails": ["user@example.com"],
  "slack_id": "U01234ABC",
  "github_username": "octocat",
  "trust_factor": {
    "trust_level": "green",
    "trust_value": 2
  }
}
```

### GET /api/v1/authenticated/hours

Returns total coding time for a date range.

**Query parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `start_date` | 7 days ago | Start date (YYYY-MM-DD) |
| `end_date` | Today | End date (YYYY-MM-DD) |

**Response:**

```json
{
  "start_date": "2025-01-01",
  "end_date": "2025-01-07",
  "total_seconds": 36000
}
```

### GET /api/v1/authenticated/streak

Returns the user's current coding streak.

**Response:**

```json
{
  "streak_days": 14
}
```

### GET /api/v1/authenticated/projects

Returns the user's projects with time totals.

**Query parameters:**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `include_archived` | `false` | Set to `true` to include archived projects |

**Response:**

```json
{
  "projects": [
    {
      "name": "my-project",
      "total_seconds": 72000,
      "most_recent_heartbeat": "2025-01-07T15:30:00Z",
      "languages": ["Ruby", "JavaScript"],
      "archived": false
    }
  ]
}
```

### GET /api/v1/authenticated/heartbeats/latest

Returns the user's most recent heartbeat.

**Response:**

```json
{
  "id": 456,
  "created_at": "2025-01-07T15:30:00Z",
  "time": 1736264400.0,
  "category": "coding",
  "project": "my-project",
  "language": "Ruby",
  "editor": "VS Code",
  "operating_system": "Mac",
  "machine": "MacBook-Pro",
  "entity": "app/models/user.rb"
}
```

### GET /api/v1/authenticated/api_keys

Returns the user's Hackatime API key (creates one if none exists).

**Response:**

```json
{
  "token": "abc123..."
}
```

## Revoking Access

### As a User

Users can revoke access to your app at any time:

1. Go to [Authorized Applications](https://hackatime.hackclub.com/oauth/authorized_applications)
2. Click **Revoke** next to the app

### Programmatically

You can revoke a token by calling the revoke endpoint:

```
POST https://hackatime.hackclub.com/oauth/revoke
```

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `token` | Yes | The access token to revoke |
| `client_id` | Yes | Your app's UID |
| `client_secret` | Yes (confidential apps) | Your app's secret |

## PKCE for Public Clients

If your app cannot securely store a client secret (mobile apps, desktop apps, SPAs), use PKCE:

1. Generate a random `code_verifier` (43-128 characters, URL-safe)
2. Create a `code_challenge` by computing `BASE64URL(SHA256(code_verifier))`
3. Include `code_challenge` and `code_challenge_method=S256` in the authorization URL
4. Include `code_verifier` when exchanging the code for a token

You can also leave the **Confidential** checkbox unchecked and omit the `client_secret` in your token requests.

## App Verification

New OAuth apps are marked as **unverified**. Unverified apps trigger a warning on the consent screen telling users the app has not been reviewed. To get your app verified, shoot Mahad a DM on the Slack! Verified apps:

- Don't show an "unverified" warning during authorization
- Have their name locked to prevent impersonation (only admins can rename them)

## Need help?

- Check the [interactive API docs](https://hackatime.hackclub.com/api-docs) for full endpoint details.
- Ask in [#hackatime-help](https://hackclub.slack.com/archives/C07MQ845X1F) on Slack.
- [Open an issue](https://github.com/hackclub/hackatime/issues) on GitHub.
