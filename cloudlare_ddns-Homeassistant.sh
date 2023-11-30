#!/bin/bash

# https://github.com/Gamerou/cloudflare_multiple_ddns
# by Gamerou

# Cloudflare API Details
CF_API_KEY="YOUR_CLOUDFLARE_API_KEY"
CF_API_EMAIL="YOUR_CLOUDFLARE_EMAIL"
CF_ZONE_ID="YOUR_CLOUDFLARE_ZONE_ID"

# HomeAssistant API Details
HA_BASE_URL="YOUR_HOMEASSISTANT_"
HA_TOKEN="YOUR_HOMEASSISTANT_TOKEN"
HA_SENSOR="YOUR_HOMEASSISTANT_SENSOR"

# Discord Webhook URL
DISCORD_WEBHOOK_URL="YOUR_DISCORD_WEBHOOK_URL"

# List of Cloudflare DNS records to update
DNS_RECORDS=("example.com" "subdomain.example.com")

# Loop through each DNS record and update with the current IPv4 address
for RECORD in "${DNS_RECORDS[@]}"; do
    # Get the record ID from Cloudflare
    RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=A&name=$RECORD" -H "X-Auth-Email: $CF_API_EMAIL" -H "X-Auth-Key: $CF_API_KEY" | jq -r '.result[0].id')

    # Check if the record ID is not empty
    if [ -n "$RECORD_ID" ]; then
        # Get the current IPv4 address from HomeAssistant
        CURRENT_IPV4=$(curl -s -X GET "$HA_BASE_URL/api/states/$HA_SENSOR" -H "Authorization: Bearer $HA_TOKEN" | jq -r '.state')

        # Update the DNS record with the new IPv4 address
        RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
            -H "X-Auth-Email: $CF_API_EMAIL" \
            -H "X-Auth-Key: $CF_API_KEY" \
            -H "Content-Type: application/json" \
            --data '{"type":"A","name":"'"$RECORD"'","content":"'"$CURRENT_IPV4"'","ttl":1,"proxied":true}')

        # Check if policy update was successful
        if [ "$(echo "${RESPONSE}" | jq -r '.success')" = "true" ]; then
            echo "Successfully updated DNS Record: ${RECORD}"
            # Send success message to Discord
            DISCORD_MESSAGE="Successfully updated Cloudflare DNS Record ${RECORD} with IPv4: ${CURRENT_IPV4}"
            curl -H "Content-Type: application/json" -d "{\"content\": \"$DISCORD_MESSAGE\"}" "${DISCORD_WEBHOOK_URL}"
        else
            echo "Error updating DNS Record: ${RECORD}. Response: ${RESPONSE}"
            # Send error message to Discord
            DISCORD_MESSAGE="Error updating Cloudflare DNS Record ${RECORD}. Response: ${RESPONSE}"
            curl -H "Content-Type: application/json" -d "{\"content\": \"$DISCORD_MESSAGE\"}" "${DISCORD_WEBHOOK_URL}"
        fi

        # Add a delay of 0.5 seconds against rate limits
        sleep 0.5
    else
        echo "Record ID not found for DNS Record: ${RECORD}. Skipping update."
    fi
done
