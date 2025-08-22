#!/bin/bash

echo "Testing LangGraph FastAPI FIXED Implementation"
echo "============================================="

# Check if server is running
echo "Checking if FIXED server is running on port 8001..."
if ! curl -s http://localhost:8001/ > /dev/null; then
    echo "Server not running! Please start it first with: uv run python main_fixed.py"
    exit 1
fi

echo "Server is running!"
echo ""

# Test 1: Root endpoint (should work)
echo "Test 1: Root endpoint"
echo "curl -X GET http://localhost:8001/"
curl -X GET "http://localhost:8001/" | jq '.' 2>/dev/null || curl -X GET "http://localhost:8001/"
echo ""
echo ""

# Test 2: Invoke endpoint (should work now)
echo "Test 2: Invoke endpoint - THIS SHOULD WORK"
echo "curl -X POST http://localhost:8001/invoke ..."
curl -X POST "http://localhost:8001/invoke" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "thread_id": "123", "message": "hello from fixed version"}' \
  | jq '.' 2>/dev/null || curl -X POST "http://localhost:8001/invoke" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "thread_id": "123", "message": "hello from fixed version"}'
echo ""
echo ""

# Test 3: Another invoke to confirm it works consistently
echo "Test 3: Another invoke - SHOULD ALSO WORK"
echo "curl -X POST http://localhost:8001/invoke ..."
curl -X POST "http://localhost:8001/invoke" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test2", "thread_id": "456", "message": "testing fixed version again"}' \
  | jq '.' 2>/dev/null || curl -X POST "http://localhost:8001/invoke" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test2", "thread_id": "456", "message": "testing fixed version again"}'
echo ""
echo ""

# Test 4: Checkpointing test - same thread_id should maintain context
echo "Test 4: Checkpointing test - reusing thread_id"
echo "curl -X POST http://localhost:8001/invoke (same thread_id) ..."
curl -X POST "http://localhost:8001/invoke" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "thread_id": "123", "message": "do you remember me?"}' \
  | jq '.' 2>/dev/null || curl -X POST "http://localhost:8001/invoke" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "thread_id": "123", "message": "do you remember me?"}'
echo ""
echo ""

echo "Expected Results:"
echo "- All endpoints should return successful responses"
echo "- PostgreSQL connection should remain stable"
echo "- Checkpointing should work correctly"
echo "- The context manager scope bug is FIXED!"