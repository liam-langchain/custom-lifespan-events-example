from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from datetime import datetime
import uvicorn
import logging
import os
from dotenv import load_dotenv

from dto.invoke_request import InvokeRequest
from langgraph.graph import StateGraph, START, END
from langgraph.checkpoint.postgres import PostgresSaver
from langchain_core.runnables import RunnableConfig
from langchain_core.messages import HumanMessage, AIMessage
from src.test_agent.state import TestAgentState

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def test_node(state: TestAgentState) -> TestAgentState:
    """Simple test node that echoes back the message"""
    messages = state.get("messages", [])
    
    if messages:
        last_message = messages[-1]
        # Handle both dict format and LangChain message objects
        if isinstance(last_message, dict):
            content = last_message.get("content", "")
        else:
            content = last_message.content
        
        response = AIMessage(content=f"Echo: {content}")
        messages.append(response)
    else:
        messages = [AIMessage(content="Hello from test node!")]
    
    return {"messages": messages}

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Fixed lifespan management following LangGraph Platform pattern"""
    logger.info("Starting up with proper lifespan management...")
    
    # Get database URI
    database_uri = os.getenv("DATABASE_URI")
    
    # Create and keep context manager alive
    checkpointer_context = PostgresSaver.from_conn_string(database_uri)
    checkpointer = checkpointer_context.__enter__()
    checkpointer.setup()
    
    # Build graph with persistent connection
    builder = StateGraph(TestAgentState, config_schema=RunnableConfig)
    builder.add_node("test_node", test_node)
    builder.add_edge(START, "test_node")
    builder.add_edge("test_node", END)
    graph = builder.compile(checkpointer=checkpointer)
    
    # Store in app.state (official pattern)
    app.state.checkpointer_context = checkpointer_context
    app.state.graph = graph
    
    logger.info("Graph initialized with persistent PostgreSQL connection")
    
    yield
    
    # Cleanup on shutdown
    logger.info("Shutting down - cleaning up database connection...")
    if hasattr(app.state, 'checkpointer_context'):
        app.state.checkpointer_context.__exit__(None, None, None)
    logger.info("Database connection closed")

app = FastAPI(
    title="Digital Doctor Graph API - FIXED",
    description="Fixed version with proper lifespan management",
    version="1.0.0",
    lifespan=lifespan
)

@app.post("/invoke")
async def invoke(request: InvokeRequest):
    """
    Invoke the graph using resources from app.state
    """
    if not hasattr(app.state, 'graph') or app.state.graph is None:
        logger.error("Graph not initialized")
        raise HTTPException(status_code=500, detail="Graph not initialized")
        
    logger.info(f"Invoke endpoint called with payload: {request}")
    logger.info(f"Request fields - user_id: {request.user_id}, thread_id: {request.thread_id}, message: {request.message}")
    
    try:
        result = app.state.graph.invoke(
            {"messages": [{"role": "user", "content": request.message}]},
            {"configurable": {"thread_id": request.thread_id, "user_id": request.user_id, "invoke_count": 0}},
        )
        logger.info(f"Graph invocation successful: {result}")
        
        return {
            "status": "success",
            "result": result,
            "timestamp": datetime.now().isoformat(),
            "version": "FIXED"
        }
        
    except Exception as e:
        logger.error(f"Error in invoke endpoint: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

@app.get("/")
async def root():
    """
    Root endpoint with basic information
    """
    logger.info("Root endpoint called")
    return {
        "message": "OK - FIXED VERSION",
        "version": "fixed",
        "description": "Uses proper FastAPI lifespan management"
    }

if __name__ == "__main__":
    logger.info("Starting FIXED Digital Doctor Graph API server...")
    uvicorn.run(app, host="0.0.0.0", port=8001)