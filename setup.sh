# ===== CREATE AN ONLINE APP =====
# Run this command in the terminal to create the app:
# chmod +x setup.sh && ./setup.sh

# 1. Login to GCP
gcloud auth application-default login

# 2. Create project structure
mkdir -p backend

# 3. Setup Python backend
echo "Setting up Backend..."
rm -rf backend/venv
python3 -m venv backend/venv
source backend/venv/bin/activate
pip install -q fastapi uvicorn google-genai python-dotenv

# 4. Setup React frontend
echo "Setting up Frontend..."
rm -rf frontend
yes n | npm create -y vite@latest frontend -- --template react
cd frontend
npm install
npm install react-markdown
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

PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT", "hanlin-0415")
LOCATION = "us-central1"

client = genai.Client(
    vertexai=True,
    project=PROJECT_ID,
    location=LOCATION
)

def get_response(user_message: str) -> str:
    instruction = f"""


    """.strip()
    
    prompt = f"""
    Instruction:
    {instruction}

    Query:
    {user_message}
    """
    
    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt
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
  color-scheme: light;
}

body {
  margin: 0;
  padding: 0;
  background-color: #ffffff;
  color: #1f1f1f;
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
  border-bottom: 1px solid #e0e0e0;
  background: #ffffff;
}

.header h1 {
  font-size: 1.1rem;
  margin: 0;
  color: #1f1f1f;
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
  border: 1px solid #e0e0e0;
  border-radius: 12px;
  background: #f8f9fa;
  animation: fadeIn 0.2s ease;
  box-shadow: 0 1px 2px rgba(0,0,0,0.05);
}

.message.user {
  background: #ffffff;
  border-color: #d1d1d1;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(6px); }
  to { opacity: 1; transform: translateY(0); }
}

.role-name {
  font-size: 0.85rem;
  color: #5f6368;
  font-weight: 600;
}

/* Markdown Styles */
.text {
  font-size: 1rem;
  line-height: 1.6;
  color: #1f1f1f;
  overflow-wrap: break-word;
}

.text p {
  margin: 0.5rem 0;
}
.text p:first-child { margin-top: 0; }
.text p:last-child { margin-bottom: 0; }

.text ul, .text ol {
  margin: 0.5rem 0;
  padding-left: 1.5rem;
}

.text code {
  background-color: #e8eaed;
  padding: 2px 4px;
  border-radius: 4px;
  font-family: monospace;
  font-size: 0.9em;
}

.text pre {
  background-color: #2d2d2d;
  color: #f8f8f8;
  padding: 1rem;
  border-radius: 8px;
  overflow-x: auto;
  margin: 0.5rem 0;
}

.text pre code {
  background-color: transparent;
  padding: 0;
  color: inherit;
}

.input-area {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: linear-gradient(to top, #ffffff 80%, transparent);
  padding: 1.25rem 1rem;
  display: flex;
  justify-content: center;
}

.input-container {
  width: 100%;
  max-width: 900px;
  background: #f0f2f5;
  border-radius: 14px;
  padding: 0.5rem 0.75rem;
  display: flex;
  align-items: center;
  gap: 10px;
  border: 1px solid transparent;
}

.input-container:focus-within {
  background: #ffffff;
  border-color: #1f1f1f;
  box-shadow: 0 1px 4px rgba(0,0,0,0.1);
}

input {
  flex: 1;
  background: transparent;
  border: none;
  color: #1f1f1f;
  font-size: 1rem;
  padding: 10px;
  outline: none;
}

button {
  background: #1f1f1f;
  color: #ffffff;
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
import ReactMarkdown from 'react-markdown'
import './App.css'

function App() {
  const [input, setInput] = useState('')
  const [messages, setMessages] = useState([
    { role: 'AI', text: 'Hi! Ask me anything.' }
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
      setMessages([...nextMessages, { role: 'AI', text: data.reply }])
    } catch (error) {
      setMessages([...nextMessages, { role: 'AI', text: 'Error: Could not connect to backend.' }])
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
            <div className="role-name">{msg.role === 'user' ? 'User' : 'AI'}</div>
            <div className="text">
              <ReactMarkdown>{msg.text}</ReactMarkdown>
            </div>
          </div>
        ))}

        {isLoading && (
          <div className="message">
            <div className="role-name">AI</div>
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

# --- Config & Deploy ---

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
gcloud builds submit --tag gcr.io/hanlin-0415/my_app . --quiet

echo "Deploying to Cloud Run..."
gcloud run deploy my-app-image --image gcr.io/hanlin-0415/my_app --platform managed --region us-central1 --allow-unauthenticated --quiet

echo "Deployment complete! Click the Service URL above."

# 7. update the code to the github
# git add setup.sh && git commit -m "my comment" && git push

# 8. Delete service 
# gcloud run services delete my-app-image --region us-central1 --project hanlin-0415 

# 9. Delete image 
# gcloud container images delete gcr.io/hanlin-0415/my_app --force-delete-tags 

# 10. Delete local files 
# rm -rf backend frontend Dockerfile .gcloudignore