#!/bin/bash
set -e

# Create or update config file
cat > ~/.wakatime.cfg << EOL
[settings]
api_url = https://hackatime.hackclub.com/api/hackatime/v1
api_key = ${HACKATIME_API_KEY}
EOL

echo "Config file created at ~/.wakatime.cfg"

# Read values from config to verify
if [ ! -f ~/.wakatime.cfg ]; then
  echo "Error: Config file not found"
  exit 1
fi

API_URL=$(sed -n 's/.*api_url = \(.*\)/\1/p' ~/.wakatime.cfg)
API_KEY=$(sed -n 's/.*api_key = \(.*\)/\1/p' ~/.wakatime.cfg)

if [ -z "$API_URL" ] || [ -z "$API_KEY" ]; then
  echo "Error: Could not read api_url or api_key from config"
  exit 1
fi

echo "Successfully read config:"
echo "API URL: $API_URL"
echo "API Key: ${API_KEY:0:8}..." # Show only first 8 chars for security

# Send test heartbeat using values from config
echo "Sending test heartbeat..."
response=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/users/current/heartbeats" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "[{\"type\":\"file\",\"time\":$(date +%s),\"entity\":\"test.txt\",\"language\":\"Text\"}]")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" = "200" ] || [ "$http_code" = "202" ]; then
  echo -e "\nTest heartbeat sent successfully"
else
  echo -e "\nError sending heartbeat: $body"
  exit 1
fi 