# file: local_summarizer.py
from llama_cpp import Llama
import json
import re

def sanitize_title(t):
    if not t: return ""
    t = re.sub(r'/[^\s]+', '/…', t)
    t = re.sub(r'\S+@\S+', 'email@…', t)
    t = re.sub(r'\d{4,}', '####', t)
    return t

def build_prompt(activity_state):
    app_times = activity_state.get("window_times", {})
    top = sorted(app_times.items(), key=lambda x: x[1], reverse=True)[:6]

    top_lines = []
    for name, seconds in top:
        doc = sanitize_title(activity_state
                             .get("document_names", {})
                             .get(name, name))
        top_lines.append(f"- {name} | time_sec:{int(seconds)} | doc:{doc}")

    total_sec = activity_state.get("session_end", 0) - activity_state.get("session_start", 0)
    switches = activity_state.get("productive_switches", 0)
    pauses = len(activity_state.get("pause_periods", []))

    prompt = f"""
You are an assistant that analyses anonymized study session logs and gives a concise performance summary.
Do not identify the user. Do not hallucinate.

Session summary:
Total_session_sec: {int(total_sec)}
Productive_switches: {int(switches)}
Pauses_count: {pauses}

Top apps by foreground time:
{chr(10).join(top_lines)}

Your task:
VERDICT: 2 lines summarizing focus.
DISTRACTIONS: 3 main distracting factors with evidence.
RECOMMENDATIONS: 3 actionable tips.
MOTIVATION: 2 short motivational sentences.

Answer in plain text. Use section headers.
"""
    return prompt

def summarize_activity_with_llm(activity_state, model_path="/Users/davidravelli/VisualStudio/Leonardo/Leonardo/leonardo_backend/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf"):
    prompt = build_prompt(activity_state)
    llm = Llama(model_path=model_path)

    res = llm(prompt, max_tokens=300, temperature=0.2)
    return res["choices"][0]["text"]