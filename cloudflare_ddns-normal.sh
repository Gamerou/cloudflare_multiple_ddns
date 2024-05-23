#!/bin/bash

# https://github.com/Gamerou/cloudflare_multiple_ddns
# Gamerou

# Cloudflare API Details
CF_API_KEY="YOUR_CLOUDFLARE_API_KEY"
CF_API_EMAIL="YOUR_CLOUDFLARE_EMAIL"
CF_ZONE_ID="YOUR_CLOUDFLARE_ZONE_ID"

# Discord Webhook URL
DISCORD_WEBHOOK_URL="YOUR_DISCORD_WEBHOOK_URL"

# Debug mode
DEBUG=false

# List of Cloudflare DNS records to update
proxied_dns_records=("example1.com") # Leave this empty if there are no proxied records
non_proxied_dns_records=("example2.com") # Leave this empty if there are no non-proxied records

# Function to log debug messages
log_debug() {
    if [ "$DEBUG" = true ]; then
        echo "DEBUG: $1"
    fi
}

# Get current IPv4 address from ipify.org
log_debug "Fetching current IPv4 address from ipify.org..."
response=$(curl -s https://api64.ipify.org?format=json)

log_debug "Response: $response"

# Extract the current IPv4 address
current_ipv4=$(echo $response | jq -r '.ip')
log_debug "Current IPv4: $current_ipv4"

# Check if IP addresses have changed
if [ -f "ip_addresses_ddns.txt" ]; then
  previous_ip=$(cat ip_addresses_ddns.txt)
  log_debug "Previous IPv4: $previous_ip"

  if [ "$previous_ip" == "$current_ipv4" ] && [ "$DEBUG" == "false" ]; then
    echo "IPv4 address has not changed. Skipping policy update."
    exit
  fi
fi

echo "$current_ipv4" > ip_addresses_ddns.txt

# Function to update DNS record
update_dns_record() {
    local record=$1
    local proxied=$2

    log_debug "Updating DNS record: $record"
    # Get the record ID from Cloudflare
    record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=A&name=$record" -H "X-Auth-Email: $CF_API_EMAIL" -H "X-Auth-Key: $CF_API_KEY" | jq -r '.result[0].id')
    log_debug "Record ID: $record_id"

    # Check if the record ID is not empty
    if [ -n "$record_id" ]; then

        # Update the DNS record with the new IPv4 address
        response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$record_id" \
        -H "X-Auth-Email: $CF_API_EMAIL" \
        -H "X-Auth-Key: $CF_API_KEY" \
        -H "Content-Type: application/json" \
        --data '{"type":"A","name":"'"$record"'","content":"'"$current_ipv4"'","ttl":1,"proxied":'"$proxied"'}')
        log_debug "Update response: $response"

        # Check if DNS record update was successful
        if [ "$(echo "${response}" | jq -r '.success')" = "true" ]; then
            echo "Successfully updated DNS Record: ${record}"
            # Send success message to email
            if [ "$DEBUG" = false ]; then
                DISCORD_MESSAGE="Successfully updated Cloudflare DNS Record ${record} with IPv4: ${current_ipv4}\n"
            fi
        else
            echo "Error updating DNS Record: ${record}. Response: ${response}"
            # Send error message to email
            if [ "$DEBUG" = false ]; then
                DISCORD_MESSAGE="Error updating Cloudflare DNS Record ${record}. Response: ${response}\n"
            fi
        fi

        # Add a delay of 0.5 seconds
        sleep 0.5
    else
        log_debug "Record ID not found for DNS Record: ${record}. Skipping update."
        # Append message to the email body
        if [ "$DEBUG" = false ]; then
            DISCORD_MESSAGE="Record ID not found for DNS Record ${record}. Skipping update.\n"
        fi
    fi
}

# Update proxied DNS records
if [ ${#proxied_dns_records[@]} -eq 0 ]; then
    echo "No proxied DNS records to update."
else
    for record in "${proxied_dns_records[@]}"; do
        update_dns_record $record true
    done
fi

# Update non-proxied DNS records
if [ ${#non_proxied_dns_records[@]} -eq 0 ]; then
    echo "No non-proxied DNS records to update."
else
    for record in "${non_proxied_dns_records[@]}"; do
        update_dns_record $record false
    done
fi

# Send consolidated discord message 
if [ "$DEBUG" = false ]; then
    curl -H "Content-Type: application/json" -d "{\"content\": \"$DISCORD_MESSAGE\"}" "${DISCORD_WEBHOOK_URL}"
else
    echo "Current IPv4: $current_ipv4"
    echo "Updated DNS records: ${proxied_dns_records[@]} ${non_proxied_dns_records[@]}"
fi
