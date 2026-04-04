to Start backend:
run "uvicorn main:app --reload --host 0.0.0.0 --port 8000" in the termninal.

to Test the Root Endpoint:
run "curl http://localhost:8000/" in a different terminal
Expected response:
{"message":"AI Chat Assistant is running with Ollama"}

Testing API (with curl)
in CMD:
curl -X POST http://localhost:8000/chat -H "Content-Type: application/json" -d "{\"message\": \"What is Flutter?\"}"
in Powershell:
Invoke-RestMethod -Uri http://localhost:8000/chat -Method Post -ContentType "application/json" -Body '{"message":"What is Flutter?"}'