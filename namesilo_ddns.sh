#!/bin/bash

## Domain name:
domain="example.com"

## Host name (subdomain). Optional.
subdomain="sub1"

## apikey obtained from Namesilo:
apikey="apikey"

## Update DNS record in Namesilo:
full_name=$domain
if [ ! -z "${subdomain}" ]; then
  full_name=$subdomain.$domain
fi

ip_file="/tmp/$full_name.lastip"

cur_ip=$(curl -s https://ip-info.oncook.top/client-ip | jq -r  '.content.ip')

known_ip=""
if [ -f $ip_file ]; then
  known_ip=$(cat $ip_file)
fi

if [ "$cur_ip" != "$known_ip" ]; then
  echo $cur_ip > $ip_file
  logger -t ddns_check -- subdomain ip changed to $cur_ip for $full_name, let\'s try updating

  ## Update DNS record in Namesilo:
  record_id=$(curl -s "https://www.namesilo.com/api/dnsListRecords?version=1&type=json&key=${apikey}&domain=${domain}" | jq -r --arg host ${full_name} '.reply.resource_record[] | select(.host==$host).record_id')
  if [ -z "${record_id}" ]; then
    logger -t ddns_check -- update failed: record_id is empty \(add domain to the registar firts\)!
    exit 1
  fi

  response_code=$(curl -s "https://www.namesilo.com/api/dnsUpdateRecord?version=1&type=json&key=${apikey}&domain=${domain}&rrid=${record_id}&rrsubdomain=${subdomain}&rrvalue=${cur_ip}&rrttl=3600" | jq -r '.reply.code')

  case $response_code in
    300)
      logger -t ddns_check -- update success;;
    280)
      logger -t ddns_check -- no update necessary;;
    *)
      echo $known_ip > $ip_file
      logger -t ddns_check -- update failed \($response_code\)!
      exit 1;;
  esac
fi

exit 0
