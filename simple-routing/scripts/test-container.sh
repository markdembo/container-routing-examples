#!/bin/bash

# Get the container URL from the first argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <container-url>"
    echo "Example: $0 http://7.localhost:8787"
    exit 1
fi

CONTAINER_URL=$1
CONTAINER_ID=$(echo $CONTAINER_URL | sed -E 's#https?://([^.]*)\..*#\1#g')

# Test the container
echo "Testing container at $CONTAINER_URL..."
echo "Container ID: $CONTAINER_ID"

# 1. Test initial page load
echo "\n1. Testing initial page load..."
INITIAL_RESPONSE=$(curl -s $CONTAINER_URL)
if echo "$INITIAL_RESPONSE" | grep -q "Hello, Beautiful World!"; then
    echo "Initial page load successful"
else
    echo "Initial page load failed"
    echo "Response received:"
    echo "$INITIAL_RESPONSE"
    exit 1
fi

# 2. Update text via admin route
echo "\n2. Updating text via admin route..."
NEW_TEXT="Updated at $(date)"
UPDATE_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"text\": \"$NEW_TEXT\"}" \
    -u cf:testing \
    "$CONTAINER_URL/admin/container/$CONTAINER_ID/update-text")

if echo "$UPDATE_RESPONSE" | grep -q "Text updated successfully"; then
    echo "Admin route update successful"
else
    echo "Admin route update failed"
    echo "Response received:"
    echo "$UPDATE_RESPONSE"
    exit 1
fi

# 3. Verify updated text
echo "\n3. Verifying updated text..."
FINAL_RESPONSE=$(curl -s $CONTAINER_URL)
if echo "$FINAL_RESPONSE" | grep -q "$NEW_TEXT"; then
    echo "Updated text verified"
else
    echo "Updated text not found"
    echo "Response received:"
    echo "$FINAL_RESPONSE"
    exit 1
fi

echo "\nAll tests passed successfully!"
