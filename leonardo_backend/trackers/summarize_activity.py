import datetime
import time

def summarize_activity(state):
    now = time.time()
    
    # --- Sessione totale ---
    session_start = state.get("session_start", now)
    session_end = state.get("last_input_time", now)
    total_session_sec = session_end - session_start
    
    # --- Pause ---
    inactive_threshold = state.get("inactive_threshold", 300)
    pauses = []
    last_input = session_start
    for log_time, _, _ in state.get("window_log", []):
        t = time.mktime(datetime.datetime.strptime(log_time, "%a %b %d %H:%M:%S %Y").timetuple())
        if t - last_input > inactive_threshold:
            pauses.append((last_input, t))
        last_input = t
    # aggiunta pausa finale se presente
    if session_end - last_input > inactive_threshold:
        pauses.append((last_input, session_end))
    
    # --- Tempo per app / categorie ---
    app_times = {}
    productive_time = 0
    distracting_time = 0
    productive_apps = set(["VSCode", "PyCharm", "Terminal", "Word", "Excel", "Electron"])
    distracting_apps = set(["YouTube", "TikTok", "Netflix", "Facebook", "Instagram"])
    
    for app, fg_time in state.get("window_times", {}).items():
        bg_time = state.get("window_background_time", {}).get(app, 0)
        reading_time = state.get("reading_time", {}).get(app, 0)
        total_app_time = fg_time + bg_time + reading_time
        app_times[app] = total_app_time
        
        if app in productive_apps:
            productive_time += total_app_time
        elif app in distracting_apps:
            distracting_time += total_app_time
    
    # --- Ritmo multitasking ---
    switch_sequence = state.get("switch_sequence", [])
    switches_prod_dist = 0
    last_category = None
    for app in switch_sequence:
        category = ("productive" if app in productive_apps else
                    "distracting" if app in distracting_apps else "other")
        if last_category and category != last_category:
            if {"productive", "distracting"} == {last_category, category}:
                switches_prod_dist += 1
        last_category = category
    
    # --- Distribuzione oraria ---
    hourly_distribution = {}
    for app, t in app_times.items():
        # ipotizziamo che tutto il tempo sia nello stesso ora della sessione start
        hour = datetime.datetime.fromtimestamp(session_start).hour
        hourly_distribution[hour] = hourly_distribution.get(hour, 0) + t
    
    summary = {
        "total_session_sec": total_session_sec,
        "pause_periods": pauses,
        "app_times": app_times,
        "productive_time_sec": productive_time,
        "distracting_time_sec": distracting_time,
        "switches_prod_dist": switches_prod_dist,
        "hourly_distribution_sec": hourly_distribution,
        "recent_windows": switch_sequence[-10:],
    }
    
    return summary

# --- USO ---
#summary = summarize_activity(activity_state)
#print(summary)