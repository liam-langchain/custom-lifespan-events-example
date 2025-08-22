from typing import TypedDict, List
from langchain_core.messages import BaseMessage

class TestAgentState(TypedDict):
    messages: List[BaseMessage]