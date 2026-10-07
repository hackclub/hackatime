---
title: API rate limits
---

Hackatime rate limits API requests by who is making them. Requests without credentials are limited by IP address, while authenticated requests get a higher allowance per user, so integrations on a shared server do not compete for the same allowance.

## Limits

| Requests | Limit | Shared by |
|----------|-------|-----------|
| Without credentials | 300 requests per minute and 10,000 per hour | Client IP address |
| Authenticated with an API key or OAuth token | 600 requests per minute | Hackatime user |
| Admin API with an Admin API key | 5,000 requests per minute | Admin API key |
| Admin API with OAuth | 5,000 requests per minute | Hackatime user |
| Rejected credentials | 300 requests per minute | Client IP address |
| OAuth token endpoint (`POST /oauth/token`) | 300 requests per minute | OAuth application and client IP address |
| OAuth token endpoint (`POST /oauth/token`) | 1,200 requests per five minutes | Client IP address |

Authenticated requests are not counted towards IP address limits on these routes:

- OAuth endpoints under `/api/v1/authenticated/`
- personal heartbeat endpoints under `/api/v1/my/heartbeats`
- WakaTime-compatible endpoints under `/api/hackatime/v1/`
- public user stats under `/api/v1/users/:username/`, such as `stats` and `projects`, when you send credentials
- Admin API endpoints under `/api/admin/`, `/api/v1/stats` and `/api/v1/users/lookup_*`

Other API routes are always limited by IP address.

All OAuth access tokens and API keys belonging to the same user share one allowance across these routes. Rotating a key or using another OAuth application does not create a new allowance. Each Admin API key has its own allowance, while Admin API OAuth tokens are grouped by the authorising user. Admin API requests do not count towards the user's regular allowance.

Requests to these routes with credentials that are invalid, expired or lack permission count towards the rejected credentials limit for the client IP address. Once it is reached, every request with credentials to these routes from that address is rejected until the window resets, so fix or remove invalid credentials instead of retrying them. On public user stats, invalid credentials still count even though the response falls back to public data.

Each OAuth application has its own token exchange allowance from each IP address, so an integration that signs in many users from one server does not share an allowance with other traffic from that address.

Each HTTP request counts once. For example, one bulk heartbeat request counts as one request, not as one request per heartbeat in its body.

POST requests without credentials, apart from the OAuth token endpoint, also have a limit of 60 requests per five minutes per client IP address.

## Handling a rate-limit response

An exceeded limit returns HTTP `429 Too Many Requests` with a JSON response and a `Retry-After` header. `Retry-After` is the number of seconds to wait before trying again.

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json
Retry-After: 30
X-RateLimit-Limit: 600
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1710948630
X-RateLimit-Reset-At: 2024-03-20T15:30:30Z
```

```json
{
  "error": "Rate limit exceeded",
  "message": "Woah there, way too fast, take a chill pill speedy gonzales!",
  "retry_after": 30,
  "reset_at": "2024-03-20T15:30:30Z"
}
```

Rate-limit responses include `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` and `X-RateLimit-Reset-At` headers. `X-RateLimit-Reset` is the Unix timestamp when the current window resets. These headers are not currently sent with every successful API response, so clients should treat a `429` and `Retry-After` as the source of truth.

When your integration receives a `429`:

1. Stop sending requests for the duration in `Retry-After`.
2. Retry after that delay instead of immediately or in parallel.
3. Use exponential backoff if a later request is also rate limited.
4. Cache repeated reads and use bulk endpoints where available.

Do not rotate credentials to work around a limit. User credentials intentionally share one allowance.
