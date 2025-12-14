#!/bin/bash

# ===== AUTOMATED SETUP & DEPLOY (FIXED VERSION) =====
# Usage:
# chmod +x setup.sh && ./setup.sh


# 1. Login to GCP first
gcloud auth application-default login


# Enable necessary APIs (Prevents permission errors)
# echo "Enabling Google Cloud APIs..."
# gcloud services enable aiplatform.googleapis.com run.googleapis.com cloudbuild.googleapis.com

# 2. Create project structure
mkdir -p backend

# 3. Setup Python backend
echo "Setting up Backend..."
# Remove old venv if it exists to be safe
rm -rf backend/venv
python3 -m venv backend/venv
source backend/venv/bin/activate
pip install -q fastapi uvicorn google-genai python-dotenv

# 4. Setup React frontend
echo "Setting up Frontend..."
rm -rf frontend # Clean start
npm create vite@latest frontend -- --template react
cd frontend
npm install
cd ..

# 5. Create all files

# --- Backend Files ---
cat > backend/requirements.txt << 'EOF'
fastapi
uvicorn[standard]
google-genai
python-dotenv
EOF

cat > backend/ai.py << 'EOF'
from google import genai
import os

# Use environment variable for project ID to make it portable
PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT", "hanlin-0415")
LOCATION = "us-central1"

client = genai.Client(
    vertexai=True,
    project=PROJECT_ID,
    location=LOCATION
)

def get_response(user_message: str) -> str:
    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=user_message
        )
        return response.text
    except Exception as e:
        return f"AI Error: {str(e)}"
EOF

cat > backend/main.py << 'EOF'
from fastapi import FastAPI
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from ai import get_response
import os

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ChatRequest(BaseModel):
    message: str

@app.post("/api/chat")
async def chat_endpoint(request: ChatRequest):
    ai_reply = get_response(request.message)
    return {"reply": ai_reply}

# Serve static files (React App)
try:
    if os.path.isdir("dist"):
        app.mount("/", StaticFiles(directory="dist", html=True), name="static")
except Exception as e:
    print(f"Error mounting static files: {e}")
EOF

# --- Frontend Files ---

cat > frontend/vite.config.js << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true,
        secure: false,
      }
    }
  }
})
EOF

cat > frontend/src/index.css << 'EOF'
:root {
  font-family: Inter, system-ui, Avenir, Helvetica, Arial, sans-serif;
  line-height: 1.5;
  font-weight: 400;
  color-scheme: dark;
}

body {
  margin: 0;
  padding: 0;
  background-color: #131314;
  color: #e3e3e3;
  width: 100vw;
  height: 100vh;
  overflow: hidden;
}

#root {
  width: 100%;
  height: 100%;
}
EOF

cat > frontend/src/App.css << 'EOF'
.app-container {
  display: flex;
  flex-direction: column;
  height: 100vh;
  max-width: 900px;
  margin: 0 auto;
}

.header {
  padding: 1rem;
  text-align: center;
  border-bottom: 1px solid #2d2d2d;
  background: #131314;
}

.header h1 {
  font-size: 1.1rem;
  margin: 0;
  color: #c4c7c5;
  font-weight: 500;
}

.chat-window {
  flex: 1;
  overflow-y: auto;
  padding: 1.5rem 1rem 7rem 1rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.message {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  padding: 0.9rem 1rem;
  border: 1px solid #2d2d2d;
  border-radius: 12px;
  background: #1e1f20;
  animation: fadeIn 0.2s ease;
}

.message.user {
  border-color: #3a3a3a;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(6px); }
  to { opacity: 1; transform: translateY(0); }
}

.role-name {
  font-size: 0.85rem;
  color: #c4c7c5;
  font-weight: 600;
}

.text {
  font-size: 1rem;
  line-height: 1.6;
  white-space: pre-wrap;
  color: #e3e3e3;
}

.input-area {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: linear-gradient(to top, #131314 80%, transparent);
  padding: 1.25rem 1rem;
  display: flex;
  justify-content: center;
}

.input-container {
  width: 100%;
  max-width: 900px;
  background: #1e1f20;
  border-radius: 14px;
  padding: 0.5rem 0.75rem;
  display: flex;
  align-items: center;
  gap: 10px;
  border: 1px solid #444746;
}

.input-container:focus-within {
  border-color: #6a6a6a;
}

input {
  flex: 1;
  background: transparent;
  border: none;
  color: white;
  font-size: 1rem;
  padding: 10px;
  outline: none;
}

button {
  background: #e3e3e3;
  color: #131314;
  border: none;
  border-radius: 10px;
  height: 38px;
  padding: 0 14px;
  font-size: 0.95rem;
  cursor: pointer;
  transition: opacity 0.2s;
}

button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
EOF

cat > frontend/src/App.jsx << 'EOF'
import { useState, useRef, useEffect } from 'react'
import './App.css'

function App() {
  const [input, setInput] = useState('')
  const [messages, setMessages] = useState([
    { role: 'assistant', text: 'Hi! Ask me anything.' }
  ])
  const [isLoading, setIsLoading] = useState(false)
  const messagesEndRef = useRef(null)

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }

  useEffect(() => {
    scrollToBottom()
  }, [messages, isLoading])

  const sendMessage = async () => {
    const trimmed = input.trim()
    if (!trimmed || isLoading) return

    const nextMessages = [...messages, { role: 'user', text: trimmed }]
    setMessages(nextMessages)
    setInput('')
    setIsLoading(true)

    try {
      const response = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: trimmed })
      })

      const data = await response.json()
      setMessages([...nextMessages, { role: 'assistant', text: data.reply }])
    } catch (error) {
      setMessages([...nextMessages, { role: 'assistant', text: 'Error: Could not connect to backend.' }])
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <div className="app-container">
      <header className="header">
        <h1>my app</h1>
      </header>

      <div className="chat-window">
        {messages.map((msg, idx) => (
          <div key={idx} className={`message ${msg.role === 'user' ? 'user' : ''}`}>
            <div className="role-name">{msg.role === 'user' ? 'User' : 'Assistant'}</div>
            <div className="text">{msg.text}</div>
          </div>
        ))}

        {isLoading && (
          <div className="message">
            <div className="role-name">Assistant</div>
            <div className="text" style={{ fontStyle: 'italic' }}>Thinking...</div>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      <div className="input-area">
        <div className="input-container">
          <input
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && sendMessage()}
            placeholder="Type a message..."
            autoFocus
          />
          <button onClick={sendMessage} disabled={isLoading || !input.trim()}>
            Send
          </button>
        </div>
      </div>
    </div>
  )
}

export default App
EOF

# --- Configuration Files ---

cat > Dockerfile << 'EOF'
FROM node:22 as build-stage
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ .
RUN npm run build

FROM python:3.9-slim
WORKDIR /app
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY backend/ .
COPY --from=build-stage /app/frontend/dist ./dist
CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
EOF

cat > .gcloudignore << 'EOF'
.git
.dockerignore
frontend/node_modules
frontend/dist
backend/venv
backend/__pycache__
.env
.DS_Store
EOF

# 6. Build and deploy
echo "Building container..."
gcloud builds submit --tag gcr.io/hanlin-0415/chatbot . --quiet

echo "Deploying to Cloud Run..."
# Using a single line for the command to avoid copy-paste line break issues
gcloud run deploy chatbot-mvp --image gcr.io/hanlin-0415/chatbot --platform managed --region us-central1 --allow-unauthenticated --quiet

echo "Deployment complete! Click the Service URL above."


# 7. Delete service 
# gcloud run services delete chatbot-mvp --region us-central1 --project hanlin-0415 


# 8. Delete image 
# gcloud container images delete gcr.io/hanlin-0415/chatbot --force-delete-tags 


# 9. Delete local files 
# rm -rf backend frontend Dockerfile .gcloudignore
