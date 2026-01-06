# All the API Commands

Here are all the ways you can get data from Hackatime with code.

## How to Log In

All requests need your API key:

- **Best way**: `Authorization: Bearer YOUR_API_KEY` in the header
- **Other way**: Add `?api_key=YOUR_API_KEY` to the URL

Get your API key from [Hackatime settings](https://hackatime.hackclub.com/my/settings).

## For WakaTime Tools

These work with existing WakaTime apps and libraries.

### Get Today's Time

```bash
GET /api/hackatime/v1/users/{user_id}/statusbar/today
```

Shows how much you've coded today.

**What you get back**:

```json
{
  "data": {
    "grand_total": {
      "total_seconds": 7200.0,
      "text": "2 hrs"
    }
  }
}
```

## Hackatime-Only Commands

These are special to Hackatime.

### Leaderboards (Admin Only)

Daily and weekly leaderboards of total coding time.

```bash
GET /api/v1/leaderboard           # alias for daily
GET /api/v1/leaderboard/daily
GET /api/v1/leaderboard/weekly
```

Authentication:

- Requires the Stats API key: use `Authorization: Bearer STATS_API_KEY` or `?api_key=STATS_API_KEY`
- In development, these endpoints may work without a key

Response (example):

```json
{
  "period": "daily",
  "start_date": "2025-12-20T00:00:00Z",
  "date_range": "Sat, Dec 20, 2025",
  "generated_at": "2025-12-20T00:05:12Z",
  "entries": [
    {
      "rank": 1,
      "user": {
        "id": 123,
        "username": "alice",
        "avatar_url": "https://.../avatar.png"
      },
      "total_seconds": 14400
    },
    {
      "rank": 2,
      "user": {
        "id": 456,
        "username": "bob",
        "avatar_url": "https://.../avatar.png"
      },
      "total_seconds": 10800
    }
  ]
}
```

Notes:

- `weekly` uses a 7-day window and returns `period: "last_7_days"` with a multi-day `date_range`
- If the leaderboard is still generating, returns `503` with `{ "error": "Leaderboard is being generated" }`
- If the API key is invalid or missing, returns `401` with `{ "error": "Unauthorized" }`

### Your Coding Stats

```bash
GET /api/v1/stats
```

Get how much you've coded overall.

### Someone Else's Stats

```bash
GET /api/v1/users/{username}/stats
```

See someone else's public coding stats.

**What you get back**:

```json
{
  "user": "username",
  "total_seconds": 86400,
  "languages": [
    { "name": "Python", "seconds": 43200 },
    { "name": "JavaScript", "seconds": 28800 }
  ],
  "projects": [{ "name": "my-app", "seconds": 36000 }]
}
```

### Your Raw Activity Data

```bash
GET /api/v1/my/heartbeats
GET /api/v1/my/heartbeats/most_recent
```

Get the raw data about when you coded.

**Options you can add**:

- `start` - Start date
- `end` - End date
- `limit` - How many results (max 100)

### Find Users

```bash
GET /api/v1/users/lookup_email/{email}
GET /api/v1/users/lookup_slack_uid/{slack_uid}
```

Find users by their email or Slack ID.

### User Trust Factor

```bash
GET /api/v1/users/{username}/trust_factor
```

Get a user's trust factor.

**What you get back**:

```json
{
  "trust_level": "yellow",
  "trust_value": 0
}
```

## Try These Examples

### See Your Recent Activity

```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  "https://hackatime.hackclub.com/api/v1/my/heartbeats?limit=10"
```

### See Today's Time

```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  "https://hackatime.hackclub.com/api/hackatime/v1/users/current/statusbar/today"
```

## Limits

- **Heartbeats**: WakaTime plugins wait 30 seconds between sends
- **API Requests**: No hard limits, but don't go crazy

## When Things Go Wrong

Errors look like this:

```json
{
  "error": "Invalid API key"
}
```

Common problems:

- `401` - Bad or missing API key
- `404` - That thing doesn't exist
- `500` - Something broke on our end
