#!/bin/bash

# Cloudflare API Details
CF_API_KEY="YOUR_CLOUDFLARE_API_KEY"
CF_API_EMAIL="YOUR_CLOUDFLARE_EMAIL"
CF_ZONE_ID="YOUR_CLOUDFLARE_ZONE_ID"

# HomeAssistant API Details
HA_BASE_URL="YOUR_HOMEASSISTANT_BASE_URL"
HA_TOKEN="YOUR_HOMEASSISTANT_TOKEN"
HA_SENSOR="YOUR_HOMEASSISTANT_SENSOR"

# Discord Webhook URL
DISCORD_WEBHOOK_URL="YOUR_DISCORD_WEBHOOK_URL"

# List of Cloudflare DNS records to update
PROXIED_DNS_RECORDS=("DOMAIN_A" "DOMAIN_B")
NON_PROXIED_DNS_RECORDS=("DOMAIN_C" "DOMAIN_D")

# Function to update DNS record
update_dns_record() {
    local record=$1
    local proxied=$2

    echo "Updating DNS record: $record"
    # Get the record ID from Cloudflare
    record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=A&name=$record" -H "X-Auth-Email: $CF_API_EMAIL" -H "X-Auth-Key: $CF_API_KEY" | jq -r '.result[0].id')

    # Check if the record ID is not empty
    if [ -n "$record_id" ]; then
        # Get the current IPv4 address from HomeAssistant
        current_ipv4=$(curl -s -X GET "$HA_BASE_URL/api/states/$HA_SENSOR" -H "Authorization: Bearer $HA_TOKEN" | jq -r '.state')

        # Update the DNS record with the new IPv4 address
        response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$record_id" \
            -H "X-Auth-Email: $CF_API_EMAIL" \
            -H "X-Auth-Key: $CF_API_KEY" \
            -H "Content-Type: application/json" \
            --data '{"type":"A","name":"'"$record"'","content":"'"$current_ipv4"'","ttl":1,"proxied":'"$proxied"'}')

        # Check if policy update was successful
        if [ "$(echo "${response}" | jq -r '.success')" = "true" ]; then
            echo "Successfully updated DNS Record: ${record}"
            # Send success message to Discord
            discord_message="Successfully updated Cloudflare DNS Record ${record} with IPv4: ${current_ipv4}"
            curl -H "Content-Type: application/json" -d "{\"content\": \"$discord_message\"}" "${DISCORD_WEBHOOK_URL}"
        else
            echo "Error updating DNS Record: ${record}. Response: ${response}"
            # Send error message to Discord
            discord_message="Error updating Cloudflare DNS Record ${record}. Response: ${response}"
            curl -H "Content-Type: application/json" -d "{\"content\": \"$discord_message\"}" "${DISCORD_WEBHOOK_URL}"
        fi

        # Add a delay of 0.5 seconds against rate limits
        sleep 0.5
    else
        echo "Record ID not found for DNS Record: ${record}. Skipping update."
    fi
}

# Update proxied DNS records
for record in "${PROXIED_DNS_RECORDS[@]}"; do
    update_dns_record $record true
done

# Update non-proxied DNS records if the list is not empty
if [ ${#NON_PROXIED_DNS_RECORDS[@]} -gt 0 ]; then
    for record in "${NON_PROXIED_DNS_RECORDS[@]}"; do
        update_dns_record $record false
    done
fi
