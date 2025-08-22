# LangGraph FastAPI Context Manager Bug Reproduction

This repository demonstrates a common bug when using LangGraph with PostgreSQL checkpointing in FastAPI applications.

## The Issue

When running this code, you'll get PostgreSQL connection errors during API requests, even though:
- PostgreSQL server is running correctly
- The application starts up successfully
- Database connection works during startup

## Error Messages You'll See

```
psycopg.OperationalError: the connection is closed
```

## How to Reproduce

1. **Start PostgreSQL:**
   ```bash
   docker run --name langgraph-postgres -d \
     -e POSTGRES_PASSWORD=password \
     -e POSTGRES_USER=user \
     -e POSTGRES_DB=langgraph \
     -p 5432:5432 \
     postgres:17
   ```

2. **Install dependencies:**
   ```bash
   uv sync
   ```

3. **Make sure `.env` file exists with the database URI:**
   ```bash
   # .env file should contain:
   DATABASE_URI=postgresql://user:password@localhost:5432/langgraph
   ```

4. **Run the application:**
   ```bash
   uv run python main.py
   ```

4. **Test the API:**
   ```bash
   curl -X POST "http://localhost:8000/invoke" \
     -H "Content-Type: application/json" \
     -d '{"user_id": "test", "thread_id": "123", "message": "hello"}'
   ```

5. **Observe the connection error**

## The Root Cause

The issue is in `test_agent/graph.py`:

```python
async def build_test_agent():
    with PostgresSaver.from_conn_string(database_uri) as checkpointer:
        checkpointer.setup()
        graph = builder.compile(checkpointer=checkpointer)
    return graph  # Connection closes here!
```

The PostgreSQL connection closes when the `with` block ends, but the graph is returned and used later in API requests when the connection is already dead.

## The Solution

The fix involves moving the context manager to the FastAPI application lifecycle. See the [official LangGraph Platform documentation](https://docs.langchain.com/langgraph-platform/custom-lifespan) for the recommended pattern.

## Project Structure

```
├── main.py                    # FastAPI application (broken)
├── main_fixed.py              # FastAPI application (fixed)
├── test_agent/
│   └── graph.py               # Graph builder with context manager issue
├── dto/
│   └── invoke_request.py      # Request/response models
├── src/test_agent/
│   └── state.py               # Graph state definition
├── .env                       # Database connection string
├── test_api.sh                # Test script for broken version
├── test_fixed_api.sh          # Test script for fixed version
└── test_both.sh               # Test script for both versions
```

## Dependencies

- FastAPI
- LangGraph + PostgreSQL checkpointing
- Python 3.9+

This reproduction case helps demonstrate why context manager scope is critical when integrating LangGraph with web frameworks.

## Testing the Bug vs Fix

### Quick Test (Recommended)

Test both versions simultaneously:

```bash
# Terminal 1: Start broken server
uv run python main.py

# Terminal 2: Start fixed server  
uv run python main_fixed.py

# Terminal 3: Test both
./test_both.sh
```

### Individual Testing

#### Test the Broken Implementation

1. **Run the broken server:**
   ```bash
   uv run python main.py
   ```

2. **Test it (should fail):**
   ```bash
   ./test_api.sh
   ```

Expected results:
- Root endpoint works
- Invoke endpoints fail with PostgreSQL connection errors

#### Test the Fixed Implementation  

1. **Run the fixed server:**
   ```bash
   uv run python main_fixed.py
   ```

2. **Test it (should work):**
   ```bash
   ./test_fixed_api.sh
   ```

Expected results:
- All endpoints work correctly
- PostgreSQL connection remains stable
- Checkpointing functions properly

## The Fix

The solution follows the [official LangGraph Platform pattern](https://docs.langchain.com/langgraph-platform/custom-lifespan) by:

1. **Moving context manager to FastAPI lifespan** instead of separate function
2. **Using `app.state`** to store resources  
3. **Keeping connection alive** for entire application lifetime
4. **Proper cleanup** on application shutdown

Key change in `main_fixed.py`:
```python
@asynccontextmanager
async def lifespan(app: FastAPI):
    checkpointer_context = PostgresSaver.from_conn_string(database_uri)
    checkpointer = checkpointer_context.__enter__()
    graph = builder.compile(checkpointer=checkpointer)
    app.state.graph = graph
    yield
    checkpointer_context.__exit__(None, None, None)
```
