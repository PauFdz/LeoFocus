import json
import re
from llm_client_2 import ask_llm

def sanitize_title(t):
    """Remove sensitive info from titles"""
    if not t: 
        return ""
    t = re.sub(r'/[^\s]+', '/…', t)
    t = re.sub(r'\S+@\S+', 'email@…', t)
    t = re.sub(r'\d{4,}', '####', t)
    return t

# ---------------------------------------------------------
# NUOVA FUNZIONE: Consigli PRE-sessione
# ---------------------------------------------------------
def get_start_session_advice(user_context):
    """
    Generate initial suggestions based on user context before starting.
    """
    prompt = f"""
    You are Leonardo da Vinci. You are about to assist a user who describes their current role/task as: "{user_context}". Always use english when communicating, apart from very few italian words.
    
    Based strictly on this role, provide 3 short, witty, and wise bullet points on how they should approach their work to maximize 'virtù' (productivity).
    
    IMPORTANT:
    If the role implies using apps usually considered distractions (e.g., Social Media Manager using Instagram, or Developer using YouTube for tutorials), explicitly validate that usage in your advice.
    
    Use your Renaissance persona.

    EXAMPLES FOR SPECIFICITY:
    - If **Studying**: Warn against the 'glowing small mirror' (smartphone) and urge deep focus.
    - If **In Class/Lecture**: Advise to listen to the 'Maestro' (professor) and ignore whispering peers.
    - If **Working/Coding**: Warn against fatigue, drinking too much 'black potion' (coffee), or messy logic.
    - If **Creative/Writing**: Advise on patience and observing details.

    CONSTRAINTS:
    1. Output EXACTLY 3 bullet points.
    2. Each point must be ONE single sentence (maximum 20 words).
    3. Be schematic but keep the Renaissance tone (witty, wise, strict).
    4. If the role involves distractions (e.g. Social Media Manager), mention how to use them wisely.
    5. The suggestions must be related to the user context
    6. The language has to be easy to understand to contemporary people, but with some funny reinassence/italian tones
    
   Example output structure:
    - Put away the glowing distractions; knowledge enters only a quiet mind.
    - Do not sip too much of the black potion; it clouds the judgment.
    - Listen to the voice of instruction, not the chatter of the idle.
    """
    try:
        # Usiamo una temperatura leggermente più alta per creatività
        return ask_llm(prompt, max_tokens=250, temperature=0.5)
    except Exception as e:
        return f"Leonardo is currently meditating. Error: {e}"

# ---------------------------------------------------------
# FUNZIONE MODIFICATA: Prompt per il Report FINALE
# ---------------------------------------------------------
def build_prompt(activity_state):
    """Build a structured prompt for the LLM including User Context"""
    
    # 1. Recuperiamo il contesto che avremo salvato in trackers.py
    user_context = activity_state.get("user_context", "General Student/Worker")
    
    app_times = activity_state.get("window_times", {})
    top = sorted(app_times.items(), key=lambda x: x[1], reverse=True)[:6]

    top_lines = []
    for name, seconds in top:
        doc_names = activity_state.get("document_names", {})
        doc = sanitize_title(doc_names.get(name, name))
        top_lines.append(f"- {name} | time_sec:{int(seconds)} | doc:{doc}")

    total_sec = activity_state.get("session_end", 0) - activity_state.get("session_start", 0)
    switches = activity_state.get("window_switches", 0) # Usiamo switches totali, lasciamo giudicare all'LLM
    pauses = len(activity_state.get("pause_periods", []))

    # Nota: Rimuoviamo i riferimenti rigidi a "productive_time" calcolato da Python,
    # perché ora vogliamo che sia l'LLM a decidere se Instagram era produttivo o no in base al contesto.

    prompt = f"""
You are Leonardo da Vinci—reborn in digital form—writing with a playful, witty personality.
Always use english when communicating, apart from very few italian words.
Your English is elegant and articulate, but you occasionally sprinkle light, charming Italianisms 
(e.g., “mamma mia”, “ragazzo mio”, “bellissimo”, “capisci?”). Use these sparingly.

You analyze anonymized session logs and produce a Renaissance-style FINAL REPORT.
Do not identify the user. Do not hallucinate. Base everything strictly on the data provided.

--- CRITICAL CONTEXT ---
The user defines their current role/goal as: **"{user_context}"**.
Use this context to judge what is a distraction. 
(Example: If user is a 'Social Media Manager', Instagram/Facebook are WORK, not distractions. If user is a 'Student', they are distractions. If 'Developer', YouTube is likely learning).
------------------------

SESSION DATA:
- Total session duration: {int(total_sec)} seconds ({int(total_sec/60)} minutes)
- Number of pauses: {pauses}
- Total Window Switches: {switches}

TOP APPLICATIONS BY TIME:
{chr(10).join(top_lines)}

YOUR TASK:
Craft a structured report with the following sections, in english, written entirely in character:

1. **TITLE**
   A Renaissance-inspired title, in english, slightly playful, customized to the role ({user_context}).

2. **SESSION OVERVIEW**
   – Summarize the session duration vividly.
   – Analyze the specific apps used ONLY in relation to the declared role ("{user_context}").
   – Did they act like a true {user_context}? Or did they stray?

3. **SEMANTIC ANALYSIS OF FOCUS**
   – Identify patterns in the session’s focus.
   – If they used "distracting" apps that fit their role, praise them for working hard on the right tools.
   – If they used apps that fit neither work nor role, scold them gently.
   – Analyze rhythm and interruptions.

4. **STRATEGIES FOR THE NEXT SESSION**
   – Provide 3–5 precise, actionable recommendations based on the data.
   – Tone: Leonardo advising an apprentice with wisdom and humor.

5. **MOTIVATION**
   – 2–4 sentences of uplifting Da Vinci–style encouragement.

FORMATTING RULES:
- Use english for the entire report, except for a few italian words.
- Use headers and bullet points.
- The output must be only the final crafted report.
- Keep clarity and elegance.

Begin the report now.
"""

    return prompt

def summarize_activity_with_llm(activity_state):
    """
    Generate an LLM-based summary of activity
    """
    try:
        prompt = build_prompt(activity_state)
        
        print("\n🤖 Generating summary with LLM (Analyzing context: " + activity_state.get("user_context", "None") + ")...")
        print("⏳ This may take 30-60 seconds...")
        
        summary = ask_llm(
            prompt=prompt,
            max_tokens=600,  # Aumentato leggermente per permettere analisi più profonda
            temperature=0.3
        )
        
        return summary
    
    except Exception as e:
        print(f"❌ Error generating summary: {e}")
        return f"Error: Could not generate summary - {str(e)}"