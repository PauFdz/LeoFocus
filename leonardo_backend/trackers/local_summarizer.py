import json
import re
from llm_client import ask_llm

def sanitize_title(t):
    """Remove sensitive info from titles"""
    if not t: 
        return ""
    t = re.sub(r'/[^\s]+', '/…', t)
    t = re.sub(r'\S+@\S+', 'email@…', t)
    t = re.sub(r'\d{4,}', '####', t)
    return t

def build_prompt(activity_state):
    """Build a structured prompt for the LLM"""
    app_times = activity_state.get("window_times", {})
    top = sorted(app_times.items(), key=lambda x: x[1], reverse=True)[:6]

    top_lines = []
    for name, seconds in top:
        # Get document name from activity_state
        doc_names = activity_state.get("document_names", {})
        doc = sanitize_title(doc_names.get(name, name))
        top_lines.append(f"- {name} | time_sec:{int(seconds)} | doc:{doc}")

    total_sec = activity_state.get("session_end", 0) - activity_state.get("session_start", 0)
    switches = activity_state.get("productive_switches", 0)
    pauses = len(activity_state.get("pause_periods", []))

    prompt = f"""You are an assistant that analyzes anonymized study session logs and provides a concise performance summary.
Do not identify the user. Do not hallucinate. Be specific and evidence-based.

SESSION DATA:
- Total session duration: {int(total_sec)} seconds ({int(total_sec/60)} minutes)
- Productive switches: {int(switches)}
- Number of pauses: {pauses}

TOP APPLICATIONS BY TIME:
{chr(10).join(top_lines)}

YOUR TASK:
Provide a brief analysis with these sections:

1. VERDICT: 2-3 sentences summarizing overall focus and productivity.

2. DISTRACTIONS: List 3 main distracting factors with specific evidence from the data.

3. RECOMMENDATIONS: Provide 3 actionable tips to improve focus.

4. MOTIVATION: 2 encouraging sentences.

Keep the response concise and under 250 words total."""

    return prompt

def summarize_activity_with_llm(activity_state):
    """
    Generate an LLM-based summary of activity
    
    Args:
        activity_state: Dictionary containing session activity data
    
    Returns:
        Generated summary text
    """
    try:
        prompt = build_prompt(activity_state)
        
        print("\n🤖 Generating summary with LLM...")
        print("⏳ This may take 30-60 seconds...")
        
        summary = ask_llm(
            prompt=prompt,
            max_tokens=500,  # Enough for full summary
            temperature=0.3   # Slightly creative but focused
        )
        
        return summary
    
    except Exception as e:
        print(f"❌ Error generating summary: {e}")
        return f"Error: Could not generate summary - {str(e)}"