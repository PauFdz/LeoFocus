from llm_client import ask_llm

def summarize_activity(activity_state):
    prompt = f"""
    Sei un assistente che analizza l'attività dell'utente.

    Ecco i dati raccolti:
    {activity_state}

    Genera un report chiaro e sintetico su:
    - livello di produttività
    - finestre più utilizzate
    - distrazioni
    - pause e inattività
    - raccomandazioni pratiche
    """

    return ask_llm(prompt)