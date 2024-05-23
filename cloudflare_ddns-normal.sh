#!/bin/bash

# https://github.com/Gamerou/cloudflare_multiple_ddns
# Gamerou

# Cloudflare API Details
CF_API_KEY="YOUR_CLOUDFLARE_API_KEY"
CF_API_EMAIL="YOUR_CLOUDFLARE_EMAIL"
CF_ZONE_ID="YOUR_CLOUDFLARE_ZONE_ID"

# Discord Webhook URL
DISCORD_WEBHOOK_URL="YOUR_DISCORD_WEBHOOK_URL"

# List of proxied and non-proxied Cloudflare DNS records to update
PROXIED_DNS_RECORDS=("DOMAIN_A" "DOMAIN_B") # Leave this empty if there are no proxied records
NON_PROXIED_DNS_RECORDS=("DOMAIN_C" "DOMAIN_D") # Leave this empty if there are no non-proxied records

# Function to update DNS record
update_dns_record() {
    local record=$1
    local proxied=$2

    echo "Updating DNS record: $record"
    # Get the record ID from Cloudflare
    record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=A&name=$record" -H "X-Auth-Email: $CF_API_EMAIL" -H "X-Auth-Key: $CF_API_KEY" | jq -r '.result[0].id')

    # Check if the record ID is not empty
    if [ -n "$record_id" ]; then
        # Get the current public IPv4 address from ipify
        current_public_ipv4=$(curl -s https://api64.ipify.org?format=json | jq -r '.ip')

        # Update the DNS record with the new public IPv4 address
        response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$record_id" \
            -H "X-Auth-Email: $CF_API_EMAIL" \
            -H "X-Auth-Key: $CF_API_KEY" \
            -H "Content-Type: application/json" \
            --data '{"type":"A","name":"'"$record"'","content":"'"$current_public_ipv4"'","ttl":1,"proxied":'"$proxied"'}')

        # Check if policy update was successful
        if [ "$(echo "${response}" | jq -r '.success')" = "true" ]; then
            echo "Successfully updated DNS Record: ${record}"
            # Send success message to Discord
            discord_message="Successfully updated Cloudflare DNS Record ${record} with IPv4: ${current_public_ipv4}"
            curl -H "Content-Type: application/json" -d "{\"content\": \"$discord_message\"}" "${DISCORD_WEBHOOK_URL}"
        else
            echo "Error updating DNS Record: ${record}. Response: ${response}"
            # Send error message to Discord
            discord_message="Error updating Cloudflare DNS Record ${record}. Response: ${response}"
            curl -H "Content-Type: application/json" -d "{\"content\": \"$discord_message\"}" "${DISCORD_WEBHOOK_URL}"
        fi

        # Add a delay of 0.5 seconds
        sleep 0.5
    else
        echo "Record ID not found for DNS Record: ${record}. Skipping update."
    fi
}

# Update proxied DNS records
if [ ${#PROXIED_DNS_RECORDS[@]} -gt 0 ]; then
    for record in "${PROXIED_DNS_RECORDS[@]}"; do
        update_dns_record $record true
    done
fi

# Update non-proxied DNS records
if [ ${#NON_PROXIED_DNS_RECORDS[@]} -gt 0 ]; then
    for record in "${NON_PROXIED_DNS_RECORDS[@]}"; do
        update_dns_record $record false
    done
fi
