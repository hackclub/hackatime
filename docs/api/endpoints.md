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
