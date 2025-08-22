#!/bin/bash

echo "Testing LangGraph FastAPI Bug Reproduction"
echo "=============================================="

# Check if server is running
echo "Checking if server is running on port 8000..."
if ! curl -s http://localhost:8000/ > /dev/null; then
    echo "Server not running! Please start it first with: uv run python main.py"
    exit 1
fi

echo "Server is running!"
echo ""

# Test 1: Root endpoint (should work)
echo "Test 1: Root endpoint"
echo "curl -X GET http://localhost:8000/"
curl -X GET "http://localhost:8000/" | jq '.' 2>/dev/null || curl -X GET "http://localhost:8000/"
echo ""
echo ""

# Test 2: Invoke endpoint (should fail with connection error)
echo "Test 2: Invoke endpoint - THIS SHOULD FAIL"
echo "curl -X POST http://localhost:8000/invoke ..."
curl -X POST "http://localhost:8000/invoke" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "thread_id": "123", "message": "hello"}' \
  | jq '.' 2>/dev/null || curl -X POST "http://localhost:8000/invoke" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "thread_id": "123", "message": "hello"}'
echo ""
echo ""

# Test 3: Another invoke to confirm it's consistently broken
echo "Test 3: Another invoke - SHOULD ALSO FAIL"
echo "curl -X POST http://localhost:8000/invoke ..."
curl -X POST "http://localhost:8000/invoke" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test2", "thread_id": "456", "message": "testing again"}' \
  | jq '.' 2>/dev/null || curl -X POST "http://localhost:8000/invoke" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test2", "thread_id": "456", "message": "testing again"}'
echo ""
echo ""

echo "Expected Results:"
echo "- Root endpoint should return: {\"message\": \"OK\"}"
echo "- Invoke endpoints should fail with PostgreSQL connection errors"
echo "- This demonstrates the context manager scope bug!"
echo ""
echo "The fix involves moving the context manager to FastAPI lifespan management."