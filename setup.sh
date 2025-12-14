# ===== AUTOMATED SETUP & DEPLOY =====
# To Run setup.sh
# chmod +x setup.sh
# ./setup.sh

# 1. Login to GCP first (do this manually once)
gcloud auth application-default login

# 2. Create project structure
mkdir backend

# 3. Setup Python backend
python3 -m venv backend/venv
source backend/venv/bin/activate
pip install -q fastapi uvicorn google-genai python-dotenv

# 4. Setup React frontend (automated, select no, no)
npm create vite@latest frontend -- --template react
cd frontend && npm install && cd ..

# 5. Create all files
cat > backend/requirements.txt << 'EOF'
fastapi
uvicorn[standard]
google-genai
python-dotenv
EOF

cat > backend/ai.py << 'EOF'
from google import genai

client = genai.Client(
    vertexai=True, 
    project="hanlin-0415", 
    location="us-central1"
)

def get_response(user_message):
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

try: 
    if os.path.isdir("dist"):
        app.mount("/", StaticFiles(directory="dist", html=True), name="static")
except Exception as e:
    print(f"Error mounting static files: {e}")
EOF

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

cat > frontend/src/App.jsx << 'EOF'
import { useState } from 'react'
import './App.css'

function App() {
  const [input, setInput] = useState('')
  const [messages, setMessages] = useState([
    { role: 'ai', text: 'Hello! I am your local AI. How can I help?' }
  ])
  const [isLoading, setIsLoading] = useState(false)

  const sendMessage = async () => {
    if (!input.trim()) return
    
    const newMessages = [...messages, { role: 'user', text: input }]
    setMessages(newMessages)
    setInput('')
    setIsLoading(true)

    try {
      const response = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: input })
      })
      
      const data = await response.json()
      setMessages([...newMessages, { role: 'ai', text: data.reply }])
    } catch (error) {
      setMessages([...newMessages, { role: 'ai', text: "Error connecting to backend." }])
    }
    setIsLoading(false)
  }

  return (
    <div style={{ maxWidth: '600px', margin: '0 auto', padding: '2rem', textAlign: 'left' }}>
      <h1>🤖 My MVP Chatbot</h1>
      
      <div style={{ 
        height: '400px', 
        overflowY: 'auto', 
        border: '1px solid #444', 
        borderRadius: '8px',
        padding: '1rem',
        marginBottom: '1rem',
        background: '#1a1a1a'
      }}>
        {messages.map((msg, index) => (
          <div key={index} style={{ 
            margin: '10px 0', 
            textAlign: msg.role === 'user' ? 'right' : 'left' 
          }}>
            <span style={{ 
              background: msg.role === 'user' ? '#007bff' : '#333',
              color: 'white',
              padding: '8px 12px',
              borderRadius: '15px',
              display: 'inline-block',
              maxWidth: '80%'
            }}>
              {msg.text}
            </span>
          </div>
        ))}
        {isLoading && <div style={{fontStyle: 'italic', color: '#666'}}>AI is thinking...</div>}
      </div>

      <div style={{ display: 'flex', gap: '10px' }}>
        <input 
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyPress={(e) => e.key === 'Enter' && sendMessage()}
          placeholder="Type a message..."
          style={{ flex: 1, padding: '10px', borderRadius: '5px', border: '1px solid #ccc' }}
        />
        <button onClick={sendMessage} disabled={isLoading} style={{ padding: '10px 20px' }}>
          Send
        </button>
      </div>
    </div>
  )
}

export default App
EOF

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
gcloud builds submit --tag gcr.io/hanlin-0415/chatbot . --quiet
gcloud run deploy chatbot-mvp \
  --image gcr.io/hanlin-0415/chatbot \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --quiet

echo "✅ Deployment complete!"


# 7. Delete service
# gcloud run services delete chatbot-mvp --region us-central1 --project hanlin-0415

# 8. Delete image
# gcloud container images delete gcr.io/hanlin-0415/chatbot --force-delete-tags
