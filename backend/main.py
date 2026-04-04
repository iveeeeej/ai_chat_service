from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx
import asyncio

app = FastAPI()

# Enable CORS so your Flutter app can connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For development only
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ChatRequest(BaseModel):
    message: str

class ChatResponse(BaseModel):
    reply: str

# Ollama API endpoint (defaults to port 11434)
OLLAMA_URL = "http://localhost:11434/api/generate"

@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                OLLAMA_URL,
                json={
                    "model": "llama3.2:1b",
                    "prompt": request.message,
                    "stream": False,  # Get complete response at once
                    "options": {
                        "num_predict": 150,  # Limit response length
                        "temperature": 0.7   # Slight creativity
                    }
                }
            )
            response.raise_for_status()
            result = response.json()
            reply = result.get("response", "Sorry, I couldn't generate a response.")
            return ChatResponse(reply=reply)
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Ollama took too long to respond")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
def root():
    return {"message": "AI Chat Assistant is running with Ollama"}