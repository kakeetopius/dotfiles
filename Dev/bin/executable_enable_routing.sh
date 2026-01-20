#!/usr/bin/env bash

if [[ "$EUID" -ne "0" ]]; then 
    echo "This script must be run with root priviledges"
    exit 1
fi

echo "Enabling kernel routing...."
sysctl -w net.ipv4.ip_forward=1

echo "Configuring firewall rules."
firewall-cmd --zone=FedoraWorkstation --add-forward
firewall-cmd --zone=FedoraWorkstation --add-masquerade

