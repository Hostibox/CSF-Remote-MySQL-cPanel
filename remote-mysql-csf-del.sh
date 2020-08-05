#!/bin/bash

# Configuration variables
CSF_CONFIG_FILE="/etc/csf/remotemysql.allow"
LOG_FILE="/var/log/remote-mysql-csf.log"

TMP_FILE="$(mktemp -p /tmp custom-script-data-XXXXXXXX)"

function log {
    local date=$(date +"%D %T")
    if [ -n "$1" ]; then
        echo "[$date] $@" >> $LOG_FILE
        $DEBUG && echo "[$date] $@"
    else
        while read data; do
            echo "[$date] $data" >> $LOG_FILE
            $DEBUG && echo "[$date] $data"
        done
    fi
}

function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

cat "${1:-/dev/stdin}" > $TMP_FILE

MYSQL_HOSTNAME=$(python -c "import sys, json; print json.load(open('$TMP_FILE'))['data']['args']['host']")

# Check if this is an IP
if valid_ip $MYSQL_HOSTNAME; then
    MYSQL_IP=$MYSQL_HOSTNAME
else
    # Try to convert to IP
    MYSQL_IP=$(getent hosts $MYSQL_HOSTNAME | awk '{ print $1 }' | head -n 1)

    if valid_ip $MYSQL_IP; then
        log "$MYSQL_HOSTNAME translated to $MYSQL_IP"
    else
        log "Unable to convert to IP address: $MYSQL_HOSTNAME"
        exit 1
    fi
fi

RULE="tcp|in|d=3306|s=$MYSQL_IP"

sed -i "/$RULE/d" "$CSF_CONFIG_FILE"
log "IP removed: $MYSQL_IP"
csf -r

rm -f $TMP_FILE