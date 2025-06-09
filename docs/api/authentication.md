# How to Log In With Code

Here's how to use your API key to access Hackatime data with code.

## Get Your API Key

Every API request needs your personal API key.

### Finding Your API Key

1. Log in to [Hackatime](https://hackatime.hackclub.com)
2. Go to [Settings](https://hackatime.hackclub.com/my/settings)
3. Copy your API key from the page

### Using Your API Key

Put your API key in the Authorization header:

```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
     https://hackatime.hackclub.com/api/v1/stats
```

## Other Ways to Send Your Key

### In the URL

You can also put your API key in the URL:

```bash
curl "https://hackatime.hackclub.com/api/v1/stats?api_key=YOUR_API_KEY"
```

**Note**: The Authorization header way is safer.

## Test Your Key

Try your API key with this simple request:

```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
     https://hackatime.hackclub.com/api/v1/stats
```

If it works, you'll get something like:

```json
{
  "total_seconds": 12345,
  "languages": [...],
  "projects": [...]
}
```

## What Happens When Something Goes Wrong

### Wrong API Key

```json
{
  "error": "Invalid API key"
}
```

### No API Key

```json
{
  "error": "API key required"
}
```

## Rate Limits

We don't enforce hard limits right now, but be reasonable:

- Don't make thousands of requests per minute
- The WakaTime plugin automatically limits heartbeats to every 30 seconds

## Keep Your Key Safe

- **Never put API keys in your code** that others can see
- **Use environment variables** to store your API key
- **Only use HTTPS** (never HTTP) for API requests
- **Get a new key** if you think yours was stolen

## Need Help?

Having trouble with your API key? Check:

1. You copied the whole key correctly
2. You're using the right website URL
3. Your request looks like the examples above

Still stuck? Ask for help in [Hack Club Slack](https://hackclub.slack.com) (#hackatime-dev channel)!
