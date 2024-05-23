#!/bin/bash

# https://github.com/Gamerou/cloudflare_multiple_ddns
# by Gamerou

# Cloudflare API Details
CF_API_KEY="YOUR_CLOUDFLARE_API_KEY"
CF_API_EMAIL="YOUR_CLOUDFLARE_EMAIL"
CF_ZONE_ID="YOUR_CLOUDFLARE_ZONE_ID"

# HomeAssistant API Details
HA_BASE_URL="YOUR_HOMEASSISTANT_URL"
HA_TOKEN="YOUR_HOMEASSISTANT_TOKEN"
HA_SENSOR="YOUR_HOMEASSISTANT_SENSOR"

# Email settings
recipient_email="YOUR_RECIPIENT_EMAIL"
sender_email="YOUR_SENDER_EMAIL"
mail_subject="Cloudflare DNS Record Update"

# List of Cloudflare DNS records to update
proxied_dns_records=("DOMAIN_A" "DOMAIN_B")
non_proxied_dns_records=("DOMAIN_C" "DOMAIN_D")


# Get current IPv4 address from HomeAssistant
echo "Fetching current IPv4 address from HomeAssistant..."
response=$(curl -s -X GET "$HA_BASE_URL/api/states/$HA_SENSOR" -H "Authorization: Bearer $HA_TOKEN")

echo "Response: $response"

# Extract the current IPv4 address
current_ipv4=$(echo $response | jq -r '.state')
echo "Current IPv4: $current_ipv4"

# Check if IP addresses have changed
if [ -f "ip_addresses_ddns.txt" ]; then
  previous_ip=$(cat ip_addresses_ddns.txt)
  echo "Previous IPv4: $previous_ip"

  if [ "$previous_ip" == "$current_ipv4" ]; then
    echo "IPv4 address has not changed. Skipping policy update."
    exit
  fi
fi

echo "$current_ipv4" > ip_addresses_ddns.txt

# Initialize the email body
email_body=""

# Function to update DNS record
update_dns_record() {
    local record=$1
    local proxied=$2

    echo "Updating DNS record: $record"
    # Get the record ID from Cloudflare
    record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=A&name=$record" -H "X-Auth-Email: $CF_API_EMAIL" -H "X-Auth-Key: $CF_API_KEY" | jq -r '.result[0].id')
    echo "Record ID: $record_id"

    # Check if the record ID is not empty
    if [ -n "$record_id" ]; then
        # Update the DNS record with the new IPv4 address
        response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$record_id" \
        -H "X-Auth-Email: $CF_API_EMAIL" \
        -H "X-Auth-Key: $CF_API_KEY" \
        -H "Content-Type: application/json" \
        --data '{"type":"A","name":"'"$record"'","content":"'"$current_ipv4"'","ttl":1,"proxied":'"$proxied"'}')
        echo "Update response: $response"

        # Check if DNS record update was successful
        if [ "$(echo "${response}" | jq -r '.success')" = "true" ]; then
            echo "Successfully updated DNS Record: ${record}"
            # Append success message to the email body
            email_body+="Successfully updated Cloudflare DNS Record ${record} with IPv4: ${current_ipv4}\n"
        else
            echo "Error updating DNS Record: ${record}. Response: ${response}"
            # Append error message to the email body
            email_body+="Error updating Cloudflare DNS Record ${record}. Response: ${response}\n"
        fi

        # Add a delay of 0.5 seconds
        sleep 0.5
    else
        echo "Record ID not found for DNS Record: ${record}. Skipping update."
        # Append message to the email body
        email_body+="Record ID not found for DNS Record ${record}. Skipping update.\n"
    fi
}

# Update proxied DNS records
for record in "${proxied_dns_records[@]}"; do
    update_dns_record $record true
done

# Update non-proxied DNS records
for record in "${non_proxied_dns_records[@]}"; do
    update_dns_record $record false
done

# Send consolidated email
echo -e "${email_body}" | mail -s "${mail_subject}" -r "${sender_email}" "${recipient_email}"
