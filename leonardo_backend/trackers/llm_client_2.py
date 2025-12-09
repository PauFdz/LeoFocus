import os
import requests
import json
import sys

_client = None
# ============================================
# OPTION 1: Groq (FREE, very fast!)
# ============================================
def get_groq_llm():
    """Initialize Groq client (FREE API, very fast)"""
    try:
        from groq import Groq
    except ImportError:
        raise ImportError("Install: pip install groq")
    
    global _client
    _client = Groq(api_key="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")
    if _client is None:
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            raise ValueError(
                "Get free API key from https://console.groq.com/keys\n"
                "Then: export GROQ_API_KEY='your-key'"
            )
        _client = Groq(api_key=api_key)
    return _client

def ask_llm_groq(prompt: str, max_tokens: int = 100, temperature: float = 0.2):
    """Groq - FREE and lightning fast!"""
    client = get_groq_llm()
    response = client.chat.completions.create(
        model="llama-3.1-8b-instant",  # or "mixtral-8x7b-32768"
        messages=[{"role": "user", "content": prompt}],
        max_tokens=max_tokens,
        temperature=temperature
    )
    return response.choices[0].message.content.strip()


# ============================================
# OPTION 2: Hugging Face Inference API (FREE)
# ============================================
def ask_llm_huggingface(prompt: str, max_tokens: int = 100, temperature: float = 0.2):
    """Hugging Face - FREE but slower"""
    api_key = os.getenv("HF_API_KEY")
    if not api_key:
        raise ValueError(
            "Get free API key from https://huggingface.co/settings/tokens\n"
            "Then: export HF_API_KEY='your-key'"
        )
    
    API_URL = "https://api-inference.huggingface.co/models/meta-llama/Llama-3.2-3B-Instruct"
    headers = {"Authorization": f"Bearer {api_key}"}
    
    response = requests.post(
        API_URL,
        headers=headers,
        json={
            "inputs": prompt,
            "parameters": {
                "max_new_tokens": max_tokens,
                "temperature": temperature
            }
        }
    )
    
    if response.status_code == 200:
        return response.json()[0]["generated_text"][len(prompt):].strip()
    else:
        return f"Error: {response.status_code} - {response.text}"


# ============================================
# OPTION 3: Ollama (100% FREE, runs locally)
# ============================================
def ask_llm_ollama(prompt: str, max_tokens: int = 100, temperature: float = 0.2):
    """Ollama - Completely free, runs on your machine"""
    try:
        response = requests.post(
            "http://localhost:11434/api/generate",
            json={
                "model": "llama3.2",  # or "mistral", "phi3"
                "prompt": prompt,
                "stream": False,
                "options": {
                    "num_predict": max_tokens,
                    "temperature": temperature
                }
            }
        )
        return response.json()["response"]
    except Exception as e:
        return f"Error: Install Ollama from https://ollama.com\nThen run: ollama pull llama3.2"


# ============================================
# Easy wrapper function
# ============================================
def ask_llm(prompt: str, max_tokens: int = 100, temperature: float = 0.2, provider: str = "groq"):
    """
    Universal LLM function
    
    Args:
        provider: "groq" (fastest), "huggingface" (free), or "ollama" (local)
    """
    if provider == "groq":
        return ask_llm_groq(prompt, max_tokens, temperature)
    elif provider == "huggingface":
        return ask_llm_huggingface(prompt, max_tokens, temperature)
    elif provider == "ollama":
        return ask_llm_ollama(prompt, max_tokens, temperature)
    else:
        raise ValueError(f"Unknown provider: {provider}")

# ============================================
# Creates json every n seconds
# ============================================

def create_json_memory(current_log, previous_context, user_goal):
    
    #distraction_level = current_log.get('distraction_level', 0) split into two to get leo's emotions
    recent_distraction = current_log.get('recent_distraction', 0)
    global_distraction = current_log.get('global_distraction', 0)
    
    # Focus Score uses global average for the session
    focus_score = int(100 - global_distraction)
    
    prompt = f"""
    You are Leonardo da Vinci. You will be guiding the user through their goal. User goal: "{user_goal}".
    
    CURRENT SITUATION (Last 30s):
    - Recent Distraction: {recent_distraction}% (Use this for your Emotion)
    - Session Global Distraction: {global_distraction}% (Use this for Focus Score)
    - Apps Used: {json.dumps(current_log.get('windows', []))}
    
    PREVIOUS HISTORY SUMMARY:
    "{previous_context.get('summary_so_far', 'Session started.')}"

    TASK:
    1. REWRITE the 'summary_so_far' concisely (max 3 sentences). Merge old and new. The summary should include how the user has been behaving during the whole session.
    2. Determine emotion based strictly on Distraction Level: - 0% to 10%: "happy" (Proud, praises the user's virtù).
       - 11% to 30%: "interested" (Supportive, curious observer, mild encouragement).
       - 31% to 50%: "normal" (Observing, calm).
       - 51% to 70%: "worried" (Concerned, warns that time is fleeing).
       - 71% to 100%: "angry" (Stern, scolding, disappointed by the waste of genius).
    3. Generate a NEW short comment.

    OUTPUT FORMAT (JSON ONLY):
    {{
      "focus_score": {focus_score},
      "leonardo_emotion": "happy" | "interested" | "normal" | "worried" | "angry",
      "summary_so_far": "<REWRITTEN SUMMARY>",
      "leonardo_comment": "<COMMENT>"
    }}
    """
    
    # --- DEBUG: STAMPA IL PROMPT REALE ---
    print("\n" + "="*50, file=sys.stderr)
    print(f"🛑 [DEBUG LLM] DISTRAZIONE CALCOLATA: {global_distraction}%", file=sys.stderr)
    print(f"🛑 [DEBUG LLM] APPS PASSATE: {current_log.get('windows', [])}", file=sys.stderr)
    print("="*50 + "\n", file=sys.stderr)
    # -------------------------------------

    response = ask_llm(prompt, max_tokens=350, provider="groq") 
    
    try:
        start = response.find('{')
        end = response.rfind('}') + 1
        if start != -1 and end != -1:
            return json.loads(response[start:end])
        else:
            return json.loads(response)
    except Exception as e:
        print(f"JSON Parsing failed: {e}", file=sys.stderr)
        return previous_context

# ============================================
# Generating the final report using json memory
# ============================================

def generate_final_report_from_memory(final_context: dict):
    
    if not final_context:
        return "Leonardo could not observe enough to write a report."   # fallback

    prompt = f"""
    You are Leonardo da Vinci. The session has ended.
    
    FINAL ACCUMULATED MEMORY OF THE SESSION:
    {json.dumps(final_context)}
    
    Your task: Write the final "Codex Entry" (Report) in Markdown based STRICTLY on this memory.
    
    Guidelines:
    1. **Title**: A witty Renaissance title based on the User Goal.
    2. **Observation**: Comment on their Focus Score and evolution throughout the session.
    3. **Advice**: Give 3 specific advices based on what distracted them (see 'summary_so_far').
    4. **Tone**: Wise, strict but encouraging. Use 1-2 Italian words like "Virtù", "Mamma mia", "Genio", "Geniale".
    
    Output ONLY the Markdown.
    """
    
    # Usiamo più token per il report finale
    return ask_llm(prompt, max_tokens=600, provider="groq")

# ============================================
# Usage examples
# ============================================
if __name__ == "__main__":
    # Test Groq (recommended!)
    print(ask_llm("What is 2+2?", provider="groq"))
    
    # Or use Hugging Face
    # print(ask_llm("What is 2+2?", provider="huggingface"))
    
    # Or use Ollama (completely offline)
    # print(ask_llm("What is 2+2?", provider="ollama"))