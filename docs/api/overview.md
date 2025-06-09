# How to Use Our Code API

The Hackatime API lets you get your coding data with code. It works just like WakaTime's API.

## Quick Start

1. Get your API key from [Hackatime settings](https://hackatime.hackclub.com/my/settings)
2. Make requests to: `https://hackatime.hackclub.com/api/v1/`

## How to Log In With Code

Put your API key in your requests like this:

**Best way (Authorization Header)**:

```text
Authorization: Bearer YOUR_API_KEY
```

**Other way (in the URL)**:

```text
?api_key=YOUR_API_KEY
```

## Try It Out

Get your coding stats:

```bash
curl -H "Authorization: Bearer YOUR_API_KEY" \
  https://hackatime.hackclub.com/api/v1/stats
```

## Works With WakaTime Tools

Since Hackatime works like WakaTime's API, you can:

- Use any WakaTime code libraries
- Point WakaTime tools to Hackatime
- Move data between WakaTime and Hackatime

## Popular Endpoints

- **Your Stats**: `/api/v1/stats` - How much you've coded
- **Your Heartbeats**: `/api/v1/my/heartbeats` - Raw coding activity
- **User Stats**: `/api/v1/users/{username}/stats` - Someone else's public stats

## More Details

Want to see all the API commands? Check out our [complete API list](./endpoints.md). Most things work exactly like [WakaTime's API](https://wakatime.com/developers).
