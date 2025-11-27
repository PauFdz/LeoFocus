import os
import requests

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
    if _client is None:
        # Option 1: Get from environment variable
        api_key = os.getenv("GROQ_API_KEY")
        
        # Option 2: Or set it directly here (easier for Windows!)
        if not api_key:
            api_key = "gsk_YOUR_KEY_HERE"  # Replace with your actual key
        
        if not api_key or api_key == "gsk_YOUR_KEY_HERE":
            raise ValueError(
                "Get free API key from https://console.groq.com/keys\n"
                "Then paste it in the code above"
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
# OPTION 3: Google Gemini (FREE, generous limits!)
# ============================================
def get_gemini_llm():
    """Initialize Gemini client (FREE API, 1500 requests/day)"""
    try:
        from google import genai
    except ImportError:
        raise ImportError("Install: pip install google-genai")
    
    global _client
    _client = genai.Client(api_key="AIzaSyAU01nhm9Vq8jzpKqQz-RcF5xwmaKUPxoE")
    if _client is None:
        # Option 1: Get from environment variable
        api_key = os.getenv("GEMINI_API_KEY")
        
        # Option 2: Or set it directly here (easier for Windows!)
        if not api_key:
            api_key = "YOUR_KEY_HERE"  # Replace with your actual key
        
        if not api_key or api_key == "YOUR_KEY_HERE":
            raise ValueError(
                "Get free API key from https://aistudio.google.com/app/apikey\n"
                "Then paste it in the code above"
            )
        
        _client = genai.Client(api_key=api_key)
    
    return _client

def ask_llm_gemini(prompt: str, max_tokens: int = 100, temperature: float = 0.2):
    """Gemini - FREE with generous limits (1500 requests/day)"""
    client = get_gemini_llm()
    
    # Available models:
    # - "gemini-2.0-flash-exp" - Latest experimental (free)
    # - "gemini-1.5-flash" - Fast and efficient
    # - "gemini-1.5-pro" - Best quality
    
    response = client.models.generate_content(
        model="gemini-2.5-flash",
        contents=prompt,
        config={
            'max_output_tokens': max_tokens,
            'temperature': temperature,
        }
    )
    
    return response.text.strip()


# ============================================
# OPTION 4: Ollama (100% FREE, runs locally)
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
        provider: "groq", "huggingface", "gemini", or "ollama"
    """
    if provider == "groq":
        return ask_llm_groq(prompt, max_tokens, temperature)
    elif provider == "huggingface":
        return ask_llm_huggingface(prompt, max_tokens, temperature)
    elif provider == "gemini":
        return ask_llm_gemini(prompt, max_tokens, temperature)
    elif provider == "ollama":
        return ask_llm_ollama(prompt, max_tokens, temperature)
    else:
        raise ValueError(f"Unknown provider: {provider}")


# ============================================
# Usage examples
# ============================================
if __name__ == "__main__":
    # Test Gemini (great free tier!)
    print(ask_llm("What is 2+2?", provider="gemini"))
    
    # Or test Groq (fastest!)
    # print(ask_llm("What is 2+2?", provider="groq"))
    
    # Or use Hugging Face
    # print(ask_llm("What is 2+2?", provider="huggingface"))
    
    # Or use Ollama (completely offline)
    # print(ask_llm("What is 2+2?", provider="ollama"))