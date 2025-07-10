#!/bin/bash

# Color codes for output
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m" # No Color

# Force color support
export CLICOLOR_FORCE=1

# Usage: ./test-multiple-containers.sh <hostname:port>
if [ $# -ne 1 ]; then
    echo -e "${RED}Usage: $0 <hostname:port>${NC}"
    echo -e "${YELLOW}Example: $0 localhost:8787${NC}"
    exit 1
fi

HOSTNAME=$1
NUM_CONTAINERS=3

# Function to start a container
start_container() {
    local container_id=$1
    echo -e "\n${GREEN}Starting container $container_id...${NC}"
    
    # Make the request and capture status code
    http_status=$(curl -s -o /dev/null -w "%{http_code}" -X POST -u cf:testing http://$HOSTNAME/admin/container/$container_id/start \
        -H "Content-Type: application/json" \
        -d '{"location": "wnam"}')
    
    if [ "$http_status" = "200" ]; then
        echo -e "${GREEN}✓ Container $container_id started successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to start container $container_id${NC}"
        echo -e "${RED}Status: $http_status${NC}"
        return 1
    fi
}

# Function to update text in a container
update_container_text() {
    local container_id=$1
    local new_text=$2
    echo -e "\n${GREEN}Updating text in container $container_id...${NC}"
    
    # Make the request and capture status code
    http_status=$(curl -s -o /dev/null -w "%{http_code}" -X POST -H "Content-Type: application/json" \
        -d "{\"text\": \"$new_text\"}" \
        -u cf:testing \
        "http://$HOSTNAME/admin/container/$container_id/update-text")
    
    if [ "$http_status" = "200" ]; then
        echo -e "${GREEN}✓ Text updated successfully in container $container_id${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to update text in container $container_id${NC}"
        echo -e "${RED}Status: $http_status${NC}"
        return 1
    fi
}

# Function to verify container content
verify_container_content() {
    local container_id=$1
    local expected_text=$2
    echo -e "\n${GREEN}Verifying content in container $container_id...${NC}"
    
    # Construct the sandbox URL directly without authentication
    sandbox_url="http://$container_id.$HOSTNAME"
    
    # Don't show the URL, just verify the content
    
    # Try to get the content with a timeout and follow redirects
    content=$(curl -s -L -m 10 $sandbox_url 2>/dev/null || echo "CURL_ERROR")
    
    if [[ "$content" == *"$expected_text"* ]]; then
        echo -e "${GREEN}✓ Container $container_id has the expected content${NC}"
        return 0
    else
        echo -e "${RED}✗ Container $container_id content verification failed${NC}"
        echo -e "${YELLOW}Expected to find: $expected_text${NC}"
        echo -e "${YELLOW}Actual content: $content${NC}"
        return 1
    fi
}

# Function to stop a container
stop_container() {
    local container_id=$1
    echo -e "\n${GREEN}Stopping container $container_id...${NC}"
    
    # Make the request and capture status code
    http_status=$(curl -s -o /dev/null -w "%{http_code}" -X POST -u cf:testing http://$HOSTNAME/admin/container/$container_id/stop)
    
    if [ "$http_status" = "200" ]; then
        echo -e "${GREEN}✓ Container $container_id stopped successfully${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Warning: Failed to stop container $container_id${NC}"
        echo -e "${YELLOW}Status: $http_status${NC}"
        return 1
    fi
}

# Main test logic
echo -e "${GREEN}Starting comprehensive container isolation test...${NC}"

# Create an array to store container IDs
container_ids=()

# 1. Start multiple containers
echo -e "\n${GREEN}1. Starting containers...${NC}"
for i in $(seq 1 $NUM_CONTAINERS); do
    container_id="test$i"
    container_ids+=($container_id)
    if ! start_container $container_id; then
        echo -e "${RED}Test failed at container start${NC}"
        exit 1
    fi

done

echo -e "\n${GREEN}All containers started successfully${NC}"

# 2. Update each container with unique content
echo -e "\n${GREEN}2. Updating containers with unique content...${NC}"
for container_id in "${container_ids[@]}"; do
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    update_container_text $container_id "Unique content for container $container_id at $timestamp"
    if [ $? -ne 0 ]; then
        echo -e "${RED}Test failed at container update${NC}"
        exit 1
    fi

done

echo -e "\n${GREEN}All containers updated successfully${NC}"

# 3. Verify each container shows only its own content
echo -e "\n${GREEN}3. Verifying container isolation...${NC}"
for container_id in "${container_ids[@]}"; do
    expected_text="Unique content for container $container_id"
    if ! verify_container_content $container_id "$expected_text"; then
        echo -e "${RED}Test failed at container isolation verification${NC}"
        exit 1
    fi

done

echo -e "\n${GREEN}All containers show correct isolated content${NC}"

# 4. Clean up - stop all containers
echo -e "\n${GREEN}4. Cleaning up...${NC}"
failed_cleanup=false
for container_id in "${container_ids[@]}"; do
    if ! stop_container $container_id; then
        failed_cleanup=true
    fi
done

if [ "$failed_cleanup" = true ]; then
    echo -e "\n${YELLOW}Warning: Some containers failed to stop properly${NC}"
    echo -e "${YELLOW}Please check and manually stop any remaining containers${NC}"
else
    echo -e "\n${GREEN}All tests completed successfully! Containers have been cleaned up.${NC}"
fi

exit 0
