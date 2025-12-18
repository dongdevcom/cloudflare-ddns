#!/bin/sh

# Cloudflare DDNS
# A bash script to update Cloudflare DNS

dir=$(dirname $(readlink -f "$0"))
# Load config from config.conf
. $dir/config.conf

#Regex ip from cloudflare cdn-cgi/trace
ip_regex="[0-9a-fA-F:.]+"

#Get cloudflare zone_id
cloudflare_zone_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$(echo "$cloudflare_record_name" | awk -F\. '{print $(NF-1) FS $NF}')" \
	-H "Authorization: Bearer $cloudflare_api_token" \
	-H "Content-Type: application/json" |
	grep -o '"id":"[^"]*' | sed 's/"id":"//' | head -n 1)

a_record_update() {
	#Get ipv4
	ipv4_request=$(curl -s -X GET https://1.1.1.1/cdn-cgi/trace)
	ipv4=$(echo $ipv4_request | sed -E "s/.*ip=($ip_regex).*/\1/")

	if [ "$ipv4" = "" ]; then
		return
	fi
	dns_record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$cloudflare_zone_id/dns_records?type=A&name=$cloudflare_record_name" \
		-H "Authorization: Bearer $cloudflare_api_token" \
		-H "Content-Type: application/json")
	if echo "$dns_record" | grep -q '"count":0'; then
		dns_add_record=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$cloudflare_zone_id/dns_records/" \
			-H "Authorization: Bearer $cloudflare_api_token" \
			-H "Content-Type: application/json" \
			--data "{\"type\":\"A\",\"name\":\"$(echo "$cloudflare_record_name" | awk -F. '{OFS="."; NF-=2; print}')\",\"content\":\"$ipv4\",\"ttl\":1,\"proxied\":false}")
		if echo "$dns_add_record" | grep -q '"success":true'; then
			log "Create A record ${cloudflare_record_name}!"
		fi
		return
	fi
	old_ipv4=$(echo $dns_record | sed -E "s/.*\"content\":\"($ip_regex)\".*/\1/")
	if [ "$ipv4" = "$old_ipv4" ]; then
		return
	fi
	a_record_id=$(echo "$dns_record" | sed -E 's/.*"id":"(\w+)".*/\1/')
	dns_update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$cloudflare_zone_id/dns_records/$a_record_id" \
		-H "Authorization: Bearer $cloudflare_api_token" \
		-H "Content-Type: application/json" \
		--data "{\"type\":\"A\",\"name\":\"$cloudflare_record_name\",\"content\":\"$ipv4\",\"ttl\":1,\"proxied\":false}")
	if echo "$dns_update" | grep -q '"success":false'; then
		log "Updating A record to ${ipv4} failed!"
		return
	fi
	log "Updating A record to ${ipv4} was successful!"
}

aaaa_record_update() {
	ipv6_request=$(curl -s -X GET https://[2606:4700:4700::1111]/cdn-cgi/trace)
	ipv6=$(echo $ipv6_request | sed -E "s/.*ip=($ip_regex).*/\1/")

	if [ "$ipv6" = "" ]; then
		return
	fi
	dns_record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$cloudflare_zone_id/dns_records?type=AAAA&name=$cloudflare_record_name" \
		-H "Authorization: Bearer $cloudflare_api_token" \
		-H "Content-Type: application/json")
	if echo "$dns_record" | grep -q '"count":0'; then
		dns_add_record=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$cloudflare_zone_id/dns_records/" \
			-H "Authorization: Bearer $cloudflare_api_token" \
			-H "Content-Type: application/json" \
			--data "{\"type\":\"AAAA\",\"name\":\"$(echo "$cloudflare_record_name" | awk -F. '{OFS="."; NF-=2; print}')\",\"content\":\"$ipv6\",\"ttl\":1,\"proxied\":false}")
		if echo "$dns_add_record" | grep -q '"success":true'; then
			log "Create AAAA record ${cloudflare_record_name}!"
		fi
		return
	fi
	old_ipv6=$(echo $dns_record | sed -E "s/.*\"content\":\"($ip_regex)\".*/\1/")
	if [ "$ipv6" = "$old_ipv6" ]; then
		return
	fi
	aaaa_record_id=$(echo "$dns_record" | sed -E 's/.*"id":"(\w+)".*/\1/')
	dns_update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$cloudflare_zone_id/dns_records/$aaaa_record_id" \
		-H "Authorization: Bearer $cloudflare_api_token" \
		-H "Content-Type: application/json" \
		--data "{\"type\":\"AAAA\",\"name\":\"$cloudflare_record_name\",\"content\":\"$ipv6\",\"ttl\":1,\"proxied\":false}")
	if echo "$dns_update" | grep -q '"success":false'; then
		log " Updating AAAA record to ${ipv6} failed!"
		return
	fi
	log "Updating AAAA record to ${ipv6} was successful!"
}

log() {
	echo "$(date '+%Y-%m-%dT%T.%3N') - $1"
}

main() {
	if [ "$event_log" = "true" ]; then
		filename=$(date '+%Y-%m')
		if [ ! -e $dir/logs ]; then
			mkdir $dir/logs
		fi
		if [ "$cloudflare_a_record" = "true" ]; then
			a_res=$(a_record_update)
			if [ -n "$a_res" ]; then
				echo "$a_res" >>$dir/logs/$filename.log
			fi
		fi
		if [ "$cloudflare_aaaa_record" = "true" ]; then
			aaaa_res=$(aaaa_record_update)
			if [ -n "$aaaa_res" ]; then
				echo "$aaaa_res" >>$dir/logs/$filename.log
			fi
		fi
	else
		if [ "$cloudflare_a_record" = "true" ]; then
			a_record_update
		fi
		if [ "$cloudflare_aaaa_record" = "true" ]; then
			aaaa_record_update
		fi
	fi
}

main
