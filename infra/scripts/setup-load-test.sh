#!/bin/bash
# Setup script for Azure Load Testing
# This script creates the load test and uploads the JMeter test plan
#
# Usage: ./setup-load-test.sh <resource-group> <load-test-resource-name> <target-webapp-url>
# Example: ./setup-load-test.sh rg-sre-agent-demo lt-sreagent app-sreagent.azurewebsites.net

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="${1:-rg-sre-agent-demo}"
LOAD_TEST_RESOURCE="${2:-lt-sreagent}"
TARGET_URL="${3:-app-sreagent.azurewebsites.net}"
TEST_ID="sre-agent-load-test"
ENGINE_INSTANCES=1
VIRTUAL_USERS=50
DURATION_SECONDS=1800
RAMP_UP_SECONDS=60

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JMX_FILE="${SCRIPT_DIR}/../tests/sre-agent-load-test.jmx"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Azure Load Testing Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Configuration:"
echo "  Resource Group:      $RESOURCE_GROUP"
echo "  Load Test Resource:  $LOAD_TEST_RESOURCE"
echo "  Target URL:          https://$TARGET_URL"
echo "  Test ID:             $TEST_ID"
echo "  Virtual Users:       $VIRTUAL_USERS"
echo "  Duration:            $DURATION_SECONDS seconds ($(($DURATION_SECONDS / 60)) minutes)"
echo "  Ramp-up:             $RAMP_UP_SECONDS seconds"
echo ""

# Check if JMX file exists
if [ ! -f "$JMX_FILE" ]; then
    echo -e "${RED}Error: JMX file not found at $JMX_FILE${NC}"
    exit 1
fi

# Install/update Azure Load Testing extension
echo -e "${YELLOW}Installing Azure Load Testing CLI extension...${NC}"
az extension add --name load --yes 2>/dev/null || az extension update --name load --yes 2>/dev/null
echo -e "${GREEN}✓ Extension ready${NC}"
echo ""

# Check if load test resource exists
echo -e "${YELLOW}Verifying Load Testing resource exists...${NC}"
if ! az load show --name "$LOAD_TEST_RESOURCE" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    echo -e "${RED}Error: Load Testing resource '$LOAD_TEST_RESOURCE' not found in resource group '$RESOURCE_GROUP'${NC}"
    echo "Please deploy the infrastructure first using:"
    echo "  az deployment sub create --location <location> --template-file infra/main.bicep --parameters infra/main.parameters.json"
    exit 1
fi
echo -e "${GREEN}✓ Load Testing resource found${NC}"
echo ""

# Create a temporary JMX file with the target URL configured
echo -e "${YELLOW}Configuring JMX test plan with target URL...${NC}"
TEMP_JMX="$(mktemp /tmp/sre-agent-load-test-XXXXXX.jmx)"
sed -e "s/app-sreagent\.azurewebsites\.net/$TARGET_URL/g" "$JMX_FILE" > "$TEMP_JMX"
echo -e "${GREEN}✓ JMX configured for https://$TARGET_URL${NC}"
echo ""

# Create or update the load test
echo -e "${YELLOW}Creating load test: $TEST_ID...${NC}"
if az load test show --load-test-resource "$LOAD_TEST_RESOURCE" --resource-group "$RESOURCE_GROUP" --test-id "$TEST_ID" &>/dev/null; then
    echo "Test already exists, updating..."
    az load test update \
        --load-test-resource "$LOAD_TEST_RESOURCE" \
        --resource-group "$RESOURCE_GROUP" \
        --test-id "$TEST_ID" \
        --display-name "SRE Agent Load Test" \
        --description "Automated load test for SRE Agent demo - simulates user traffic with random button clicks" \
        --engine-instances "$ENGINE_INSTANCES" \
        --test-plan "$TEMP_JMX"
else
    az load test create \
        --load-test-resource "$LOAD_TEST_RESOURCE" \
        --resource-group "$RESOURCE_GROUP" \
        --test-id "$TEST_ID" \
        --display-name "SRE Agent Load Test" \
        --description "Automated load test for SRE Agent demo - simulates user traffic with random button clicks" \
        --engine-instances "$ENGINE_INSTANCES" \
        --test-plan "$TEMP_JMX"
fi
echo -e "${GREEN}✓ Load test created/updated${NC}"
echo ""

# Cleanup temp file
rm -f "$TEMP_JMX"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Load test '$TEST_ID' is ready to run."
echo ""
echo "To run the test via Azure CLI:"
echo -e "${YELLOW}  az load test-run create \\${NC}"
echo -e "${YELLOW}    --load-test-resource $LOAD_TEST_RESOURCE \\${NC}"
echo -e "${YELLOW}    --resource-group $RESOURCE_GROUP \\${NC}"
echo -e "${YELLOW}    --test-id $TEST_ID \\${NC}"
echo -e "${YELLOW}    --test-run-id \"run-\$(date +%Y%m%d-%H%M%S)\"${NC}"
echo ""
echo "Or run from the Azure Portal:"
echo "  1. Navigate to: https://portal.azure.com"
echo "  2. Search for 'Load Testing' and select '$LOAD_TEST_RESOURCE'"
echo "  3. Click on '$TEST_ID' in the tests list"
echo "  4. Click 'Run' to start the test"
echo ""
