from llama_cpp import Llama

llm = Llama(
    model_path="models/mistral-7b-instruct-v0.2.Q4_K_M.gguf",
    n_ctx=4096,
    n_threads=6
)

def ask_llm(prompt: str):
    response = llm(prompt, max_tokens=10)
    return response["choices"][0]["text"]