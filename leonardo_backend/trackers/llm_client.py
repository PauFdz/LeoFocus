import os
from pathlib import Path
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch

_model = None
_tokenizer = None

def get_model_cache_dir():
    """Get the local models directory for caching"""
    current_file = Path(__file__).resolve()
    project_root = current_file.parent.parent
    models_dir = project_root / "models" / "tinyllama-cache"
    models_dir.mkdir(parents=True, exist_ok=True)
    return str(models_dir)

def get_llm():
    """Load smaller Llama model (pure Python, faster)"""
    global _model, _tokenizer
    
    if _model is None:
        # Using smaller Llama 3.2 - much faster!
        # Options:
        # - "meta-llama/Llama-3.2-1B-Instruct" (~2.5GB, very fast)
        # - "meta-llama/Llama-3.2-3B-Instruct" (~6GB, good quality)
        # - "TinyLlama/TinyLlama-1.1B-Chat-v1.0" (~2GB, fastest)
        
        model_name = "TinyLlama/TinyLlama-1.1B-Chat-v1.0"
        cache_dir = get_model_cache_dir()
        
        print(f"Loading {model_name}...")
        print(f"Model cache directory: {cache_dir}")
        print("First download ~2GB (cached locally in models/ folder)...")
        
        _tokenizer = AutoTokenizer.from_pretrained(
            model_name,
            cache_dir=cache_dir
        )
        _model = AutoModelForCausalLM.from_pretrained(
            model_name,
            cache_dir=cache_dir,
            torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
            device_map="auto" if torch.cuda.is_available() else "cpu",
            low_cpu_mem_usage=True
        )
        
        print("✓ Model loaded!")
    
    return _model, _tokenizer

def ask_llm(prompt: str, max_tokens: int = 100, temperature: float = 0.2):
    """Ask the LLM (pure Python)"""
    try:
        model, tokenizer = get_llm()
        
        # TinyLlama format
        formatted_prompt = f"<|user|>\n{prompt}</s>\n<|assistant|>\n"
        
        inputs = tokenizer(formatted_prompt, return_tensors="pt")
        device = next(model.parameters()).device
        inputs = {k: v.to(device) for k, v in inputs.items()}
        
        with torch.no_grad():
            outputs = model.generate(
                **inputs,
                max_new_tokens=max_tokens,
                temperature=temperature,
                do_sample=temperature > 0,
                pad_token_id=tokenizer.eos_token_id
            )
        
        response = tokenizer.decode(
            outputs[0][inputs['input_ids'].shape[1]:], 
            skip_special_tokens=True
        )
        
        return response.strip()
    
    except Exception as e:
        return f"Error: {str(e)}"