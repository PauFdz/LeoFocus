from llm_client import ask_llm

def summarize_activity(activity_state):
    prompt = f"""
    You are an assistant that analyzes user activity. Communicate in english.

    Here is the collected data:
    {activity_state}

    Generate a clear and concise report on:
    - productivity level
    - most used windows
    - distractions
    - pauses and inactivity
    - practical recommendations
    """

    return ask_llm(prompt)