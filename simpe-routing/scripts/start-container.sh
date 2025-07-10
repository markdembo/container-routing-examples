#!/bin/bash

# Usage: ./start-container.sh <container_id> <hostname>
if [ $# -ne 2 ]; then
    echo "Usage: $0 <container_id> <hostname>"
    echo "Example: $0 my_container localhost:8787"
    exit 1
fi

CONTAINER_ID=$1
HOSTNAME=$2

## Call our start endpoint with basic auth and location hint
curl -X POST http://cf:testing@$HOSTNAME/admin/container/$CONTAINER_ID/start -H "Content-Type: application/json" -d '{"location": "wnam"}'

# Wait for container to be ready
sleep 2


