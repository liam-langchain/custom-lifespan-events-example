from pydantic import BaseModel

class InvokeRequest(BaseModel):
    user_id: str
    thread_id: str
    message: str