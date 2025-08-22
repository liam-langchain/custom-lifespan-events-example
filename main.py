from fastapi import FastAPI
from datetime import datetime
import uvicorn
import logging
from dto.invoke_request import InvokeRequest
from test_agent.graph import build_test_agent
from langchain_core.messages import HumanMessage
from fastapi import HTTPException

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize graph as None, will be set during startup
graph = None

app = FastAPI(
    title="Digital Doctor Graph API",
    description="A simple FastAPI application with health monitoring",
    version="1.0.0"
)

@app.on_event("startup")
async def startup_event():
    """Initialize the graph during startup"""
    global graph
    logger.info("Initializing test agent graph...")
    graph = await build_test_agent()
    logger.info("Test agent graph initialized successfully")

@app.post("/invoke")
async def invoke(request: InvokeRequest):
    """
    Invoke the graph with the provided payload
    """
    if graph is None:
        logger.error("Graph not initialized yet")
        raise Exception("Graph not initialized")
        
    logger.info(f"Invoke endpoint called with payload: {request}")
    logger.info(f"Request fields - user_id: {request.user_id}, thread_id: {request.thread_id}, message: {request.message}")
    
    try:
        result = graph.invoke(
            {"messages": [{"role": "user", "content": request.message}]},
            {"configurable": {"thread_id": request.thread_id, "user_id": request.user_id, "invoke_count": 0}},
        )
        logger.info(f"Graph invocation successful: {result}")
        
        return {
            "status": "success",
            "result": result,
            "timestamp": datetime.now().isoformat()
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
        "message": "OK",
    }

if __name__ == "__main__":
    logger.info("Starting Digital Doctor Graph API server...")
    uvicorn.run(app, host="0.0.0.0", port=8000)
