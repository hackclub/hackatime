# Hackatime Desktop companion site

The SvelteKit site students use with Hackatime Desktop: sign in with Hackatime, pair a Mac (`/pair`), see their Macs (`/devices`) and shipped projects with each reviewer view (`/ships`). The Mac app opens it in its own window. It talks to Hackatime's `/api/v1/authenticated/desktop` endpoints with the student's OAuth token, which it keeps in an encrypted cookie.

## Register the OAuth application

1. Sign in to Hackatime and open `/oauth/applications/new`.
2. Give it a name, add the redirect URI `<site origin>/auth/callback` (for example `http://localhost:5173/auth/callback` in development) and tick the `profile` and `desktop` scopes.
3. The site signs in with PKCE, so a public (non-confidential) application works. For a confidential one, also set `OAUTH_CLIENT_SECRET`.
4. Copy the application's UID into `OAUTH_CLIENT_ID`.

## Environment variables

`src/env.ts` defines them. `bun run build` checks them too, so set the two required ones before building (any client ID and a 32-character secret will do for a build that is not deployed).

| Variable | Required | Meaning |
| --- | --- | --- |
| `OAUTH_CLIENT_ID` | yes | UID of the OAuth application above. |
| `SESSION_SECRET` | yes | At least 32 random characters. Encrypts the session cookies; changing it signs everyone out. |
| `OAUTH_CLIENT_SECRET` | no | Only for a confidential OAuth application. |
| `HACKATIME_URL` | no | Public Hackatime origin the browser is sent to for sign-in. Default `https://hackatime.hackclub.com`. |
| `HACKATIME_API_URL` | no | Origin for server-to-server API calls, when it differs from `HACKATIME_URL` (for example the Rails container). |
| `SITE_URL` | no | This site's public origin, when a proxy hides it. Used for the OAuth redirect URI. |
| `DESKTOP_DOWNLOAD_URL` | no | Where the Mac app is downloaded from. Default: the latest GitHub release. |

Generate a session secret with `openssl rand -base64 48`.

## Develop

With Hackatime running locally (see `DEVELOPMENT.md` at the repository root):

```sh
cd desktop/site
bun install
HACKATIME_URL=http://localhost:3000 OAUTH_CLIENT_ID=… SESSION_SECRET=… bun run dev
```

`bun run check` type-checks the site.

## Deploy

```sh
bun run build      # with the variables above set
node build         # @sveltejs/adapter-node; reads the variables again at start
```
