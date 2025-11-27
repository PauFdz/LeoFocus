# test_llm.py
from llm_client import ask_llm

response = ask_llm("What is 2+2?", max_tokens=50)
print(f"Response: {response}")