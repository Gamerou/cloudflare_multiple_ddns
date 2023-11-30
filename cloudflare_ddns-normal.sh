#!/bin/bash

# https://github.com/Gamerou/cloudflare_multiple_ddns
# Gamerou

# Cloudflare API Details
CF_API_KEY="YOUR_CLOUDFLARE_API_KEY"
CF_API_EMAIL="YOUR_CLOUDFLARE_EMAIL"
CF_ZONE_ID="YOUR_CLOUDFLARE_ZONE_ID"

# Discord Webhook URL
DISCORD_WEBHOOK_URL="YOUR_DISCORD_WEBHOOK_URL"

# List of Cloudflare DNS records to update
DNS_RECORDS=("example.com" "subdomain.example.com")

# Loop through each DNS record and update with the current public IPv4 address
for RECORD in "${DNS_RECORDS[@]}"; do
    # Get the record ID from Cloudflare
    RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=A&name=$RECORD" -H "X-Auth-Email: $CF_API_EMAIL" -H "X-Auth-Key: $CF_API_KEY" | jq -r '.result[0].id')

    # Check if the record ID is not empty
    if [ -n "$RECORD_ID" ]; then
        # Get the current public IPv4 address from ipify
        CURRENT_PUBLIC_IPV4=$(curl -s https://api64.ipify.org?format=json | jq -r '.ip')

        # Update the DNS record with the new public IPv4 address
        RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
            -H "X-Auth-Email: $CF_API_EMAIL" \
            -H "X-Auth-Key: $CF_API_KEY" \
            -H "Content-Type: application/json" \
            --data '{"type":"A","name":"'"$RECORD"'","content":"'"$CURRENT_PUBLIC_IPV4"'","ttl":1,"proxied":true}')

        # Check if policy update was successful
        if [ "$(echo "${RESPONSE}" | jq -r '.success')" = "true" ]; then
            echo "Successfully updated DNS Record: ${RECORD}"
            # Send success message to Discord
            DISCORD_MESSAGE="Successfully updated Cloudflare DNS Record ${RECORD} with IPv4: ${CURRENT_PUBLIC_IPV4}"
            curl -H "Content-Type: application/json" -d "{\"content\": \"$DISCORD_MESSAGE\"}" "${DISCORD_WEBHOOK_URL}"
        else
            echo "Error updating DNS Record: ${RECORD}. Response: ${RESPONSE}"
            # Send error message to Discord
            DISCORD_MESSAGE="Error updating Cloudflare DNS Record ${RECORD}. Response: ${RESPONSE}"
            curl -H "Content-Type: application/json" -d "{\"content\": \"$DISCORD_MESSAGE\"}" "${DISCORD_WEBHOOK_URL}"
        fi

        # Add a delay of 0.5 seconds
        sleep 0.5
    else
        echo "Record ID not found for DNS Record: ${RECORD}. Skipping update."
    fi
done
