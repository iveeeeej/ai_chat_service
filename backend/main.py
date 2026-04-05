from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx
from datetime import datetime
from motor.motor_asyncio import AsyncIOMotorClient

app = FastAPI()

# CORS (same as before)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# MongoDB connection
MONGO_URL = "mongodb://localhost:27017"
client = AsyncIOMotorClient(MONGO_URL)
db = client["chat_db"] # database name
collection = db["messages"]

class ChatRequest(BaseModel):
    message: str

class ChatResponse(BaseModel):
    reply: str

OLLAMA_URL = "http://localhost:11434/api/generate"

@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    # 1. Save user message
    user_doc = {
        "role": "user",
        "content": request.message,
        "timestamp": datetime.utcnow()
    }
    await collection.insert_one(user_doc)

    # 2. Get AI reply from Ollama
    try:
        async with httpx.AsyncClient(timeout=30.0) as http_client:
            response = await http_client.post(
                OLLAMA_URL,
                json={
                    "model": "llama3.2:1b",
                    "prompt": request.message,
                    "stream": False,
                    "options": {
                        "num_predict": 350,
                        "temperature": 0.7
                    }
                }
            )
            response.raise_for_status()
            result = response.json()
            reply = result.get("response", "Sorry, I couldn't generate a response.")
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Ollama took too long to respond")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    # 3. Save assistant reply
    assistant_doc = {
        "role": "assistant",
        "content": reply,
        "timestamp": datetime.utcnow()
    }
    await collection.insert_one(assistant_doc)

    return ChatResponse(reply=reply)

# Optional: endpoint to get recent conversation history
@app.get("/history")
async def get_history(limit: int = 20):
    """Returns the last `limit` messages (oldest to newest)."""
    cursor = collection.find().sort("timestamp", -1).limit(limit)
    messages = await cursor.to_list(length=limit)
    # reverse to show oldest first
    messages.reverse()
    # Convert ObjectId to string for JSON serialization
    for msg in messages:
        msg["_id"] = str(msg["_id"])
    return {"messages": messages}

@app.delete("/history")
async def clear_history():
    """Delete all messages from MongoDB"""
    result = await collection.delete_many({})
    return {"deleted_count": result.deleted_count}

@app.get("/")
def root():
    return {"message": "AI Chat Assistant is running with Ollama + MongoDB"}