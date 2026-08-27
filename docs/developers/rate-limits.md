---
title: API rate limits
---

Hackatime rate limits API requests to keep integrations responsive without making applications on a shared server compete for the same primary allowance.

## Limits

| Requests | Limit | Shared by |
|----------|-------|-----------|
| User-authenticated APIs | 300 requests per minute | Hackatime user |
| Admin API with an Admin API key | 300 requests per minute | Admin API key |
| Admin API with OAuth | 300 requests per minute | Hackatime user |
| Public and legacy API routes | 300 requests per minute | Client IP address |
| All `/api/` routes | 10,000 requests per hour | Client IP address |

The 10,000-per-hour limit is a secondary abuse limit. It applies in addition to the relevant primary limit, including for authenticated requests.

User-authenticated APIs include:

- OAuth endpoints under `/api/v1/authenticated/`
- personal heartbeat endpoints under `/api/v1/my/heartbeats`
- WakaTime-compatible endpoints under `/api/hackatime/v1/`

All OAuth access tokens and API keys belonging to the same user share one allowance across these routes. Rotating a key or using another OAuth application does not create a new allowance. Each Admin API key has its own allowance, while Admin API OAuth tokens are grouped by the authorising user.

Each HTTP request counts once. For example, one bulk heartbeat request counts as one request, not as one request per heartbeat in its body.

Unauthenticated POST requests outside these authenticated API families also have a limit of 60 requests per five minutes per client IP address.

## Handling a rate-limit response

An exceeded limit returns HTTP `429 Too Many Requests` with a JSON response and a `Retry-After` header. `Retry-After` is the number of seconds to wait before trying again.

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json
Retry-After: 60
```

```json
{
  "error": "Rate limit exceeded"
}
```

Responses from the IP-based limits also include `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` and `X-RateLimit-Reset-At` headers. These headers are not currently sent with every successful API response, so clients should treat a `429` and `Retry-After` as the source of truth.

When your integration receives a `429`:

1. Stop sending requests for the duration in `Retry-After`.
2. Retry after that delay instead of immediately or in parallel.
3. Use exponential backoff if a later request is also rate limited.
4. Cache repeated reads and use bulk endpoints where available.

Do not rotate credentials to work around a limit. User credentials intentionally share one allowance.
