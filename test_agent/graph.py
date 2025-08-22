import os
import logging
from dotenv import load_dotenv

from langgraph.graph import StateGraph, START, END
from langchain_core.runnables import RunnableConfig
from langgraph.checkpoint.postgres import PostgresSaver
from langchain_core.messages import AIMessage
from src.test_agent.state import TestAgentState

# Load environment variables
load_dotenv()

logger = logging.getLogger(__name__)

def test_node(state: TestAgentState) -> TestAgentState:
    """Simple test node that echoes back the message"""
    messages = state.get("messages", [])
    
    if messages:
        last_message = messages[-1]
        response = AIMessage(content=f"Echo: {last_message.content}")
        messages.append(response)
    else:
        messages = [AIMessage(content="Hello from test node!")]
    
    return {"messages": messages}

async def build_test_agent(thread_id: str = None):
    """
    Simple Test Agent to verify connectivity to everything with PostgreSQL persistence
    
    Args:
        thread_id: Optional user/session ID to associate with this checkpointer.
                   If None, a default thread_id will be used.
    """

    # Get database URI from environment
    database_uri = os.getenv("DATABASE_URI")

    # Use provided thread_id or generate a default one
    if thread_id is None:
        thread_id = "default_test_agent"

    logger.info(f"Initializing test agent with PostgresSaver checkpointing for thread_id: {thread_id}")
    graph = None

    # Create PostgreSQL saver with thread_id
    with PostgresSaver.from_conn_string(database_uri) as checkpointer:
        # Setup the database tables
        checkpointer.setup()

        # Build the graph
        builder = StateGraph(TestAgentState, config_schema=RunnableConfig)

        # Add the test node
        builder.add_node("test_node", test_node)

        # Define the workflow: START -> test_node -> END
        builder.add_edge(START, "test_node")
        builder.add_edge("test_node", END)

        # Compile the graph with checkpointing
        graph = builder.compile(checkpointer=checkpointer)

        logger.info(f"Test agent graph compiled successfully with PostgreSQL checkpointing for thread_id: {thread_id}")

    return graph