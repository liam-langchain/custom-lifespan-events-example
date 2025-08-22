#!/bin/bash

echo "Testing LangGraph FastAPI: Broken vs Fixed Implementation"
echo "======================================================="
echo ""

# Function to test an endpoint
test_endpoint() {
    local port=$1
    local version=$2
    local endpoint=$3
    local method=$4
    local data=$5
    
    echo "Testing $version version (port $port): $endpoint"
    
    if [ "$method" = "GET" ]; then
        curl -s "http://localhost:$port$endpoint" | jq '.' 2>/dev/null || curl -s "http://localhost:$port$endpoint"
    else
        curl -s -X POST "http://localhost:$port$endpoint" \
          -H "Content-Type: application/json" \
          -d "$data" | jq '.' 2>/dev/null || curl -s -X POST "http://localhost:$port$endpoint" \
          -H "Content-Type: application/json" \
          -d "$data"
    fi
    echo ""
}

# Check if servers are running
echo "Checking server status..."
BROKEN_RUNNING=false
FIXED_RUNNING=false

if curl -s http://localhost:8000/ > /dev/null; then
    BROKEN_RUNNING=true
    echo "Broken server running on port 8000"
else
    echo "Broken server not running on port 8000"
fi

if curl -s http://localhost:8001/ > /dev/null; then
    FIXED_RUNNING=true  
    echo "Fixed server running on port 8001"
else
    echo "Fixed server not running on port 8001"
fi

if [ "$BROKEN_RUNNING" = false ] && [ "$FIXED_RUNNING" = false ]; then
    echo ""
    echo "No servers running! Start them with:"
    echo "  Terminal 1: uv run python main.py"
    echo "  Terminal 2: uv run python main_fixed.py"
    exit 1
fi

echo ""
echo "=========================================="
echo "TEST 1: Root Endpoint"
echo "=========================================="

if [ "$BROKEN_RUNNING" = true ]; then
    test_endpoint 8000 "BROKEN" "/" "GET" ""
fi

if [ "$FIXED_RUNNING" = true ]; then
    test_endpoint 8001 "FIXED" "/" "GET" ""
fi

echo "=========================================="
echo "TEST 2: Invoke Endpoint - First Call"
echo "=========================================="

invoke_data1='{"user_id": "test", "thread_id": "123", "message": "hello"}'

if [ "$BROKEN_RUNNING" = true ]; then
    echo "BROKEN version - SHOULD FAIL:"
    test_endpoint 8000 "BROKEN" "/invoke" "POST" "$invoke_data1"
fi

if [ "$FIXED_RUNNING" = true ]; then
    echo "FIXED version - SHOULD WORK:"
    test_endpoint 8001 "FIXED" "/invoke" "POST" "$invoke_data1"
fi

echo "=========================================="
echo "TEST 3: Invoke Endpoint - Second Call"
echo "=========================================="

invoke_data2='{"user_id": "test2", "thread_id": "456", "message": "testing again"}'

if [ "$BROKEN_RUNNING" = true ]; then
    echo "BROKEN version - SHOULD FAIL:"
    test_endpoint 8000 "BROKEN" "/invoke" "POST" "$invoke_data2"
fi

if [ "$FIXED_RUNNING" = true ]; then
    echo "FIXED version - SHOULD WORK:"
    test_endpoint 8001 "FIXED" "/invoke" "POST" "$invoke_data2"
fi

echo "=========================================="
echo "TEST 4: Checkpointing Test (Same Thread)"
echo "=========================================="

invoke_data3='{"user_id": "test", "thread_id": "123", "message": "do you remember me?"}'

if [ "$BROKEN_RUNNING" = true ]; then
    echo "BROKEN version - SHOULD FAIL:"
    test_endpoint 8000 "BROKEN" "/invoke" "POST" "$invoke_data3"
fi

if [ "$FIXED_RUNNING" = true ]; then
    echo "FIXED version - SHOULD WORK:"
    test_endpoint 8001 "FIXED" "/invoke" "POST" "$invoke_data3"
fi

echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo ""
echo "Expected Results:"
echo "- BROKEN version: Root works, all invokes fail with connection errors"
echo "- FIXED version: All endpoints work correctly"
echo ""
echo "The difference demonstrates the context manager scope bug and its fix."