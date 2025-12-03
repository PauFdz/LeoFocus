import json
import time
import threading
import sys
from pynput import keyboard, mouse
import subprocess
import os
from local_summarizer import summarize_activity_with_llm, get_start_session_advice

# -----------------------------
# CONFIGURAZIONE APPLICAZIONI
# -----------------------------
DISTRACTING_APPS = ["YouTube", "TikTok", "Netflix", "Facebook", "Instagram", "WhatsApp", "TV"]
PRODUCTIVE_APPS = ["VSCode", "PyCharm", "Terminal", "Word", "Excel", "Electron"]
BROWSER_DISTRACTIONS = ["Facebook", "Instagram", "Netflix", "YouTube", "TikTok"]

# SYSTEM PROCESSES TO IGNORE (Windows)
SYSTEM_PROCESSES = [
    "Program Manager",
    "Realtek Audio Console",
    "OmApSvcBroker",
    "Experiencia de entrada de Windows",
    "NVIDIA GeForce Overlay",
    "NVIDIA Share",
    "Windows Shell Experience Host",
    "Microsoft Text Input Application",
    "SearchUI",
    "ShellExperienceHost",
    "ApplicationFrameHost",
    "TextInputHost",
    "Settings",
    "Configuración",
    "SystemSettings",
    "Windows Security",
    "Seguridad de Windows"
]

# SYSTEM PROCESSES TO IGNORE (macOS)
MAC_SYSTEM_PROCESSES = [
    "Dock",
    "Finder",
    "SystemUIServer",
    "Control Center",
    "NotificationCenter",
    "loginwindow",
    "WindowServer"
]

APP_CATEGORIES = {
    "browser": ["Safari", "Chrome", "Firefox", "Edge"],
    "ide": ["VSCode", "PyCharm", "Sublime Text"],
    "chat": ["Slack", "Discord", "Telegram", "WhatsApp"],
    "mail": ["Mail", "Outlook"],
    "office": ["Word", "Excel", "PowerPoint"],
    "media": ["YouTube", "Spotify", "Netflix"]
}

# -----------------------------
# GLOBAL STATE
# -----------------------------
activity_state = {
    "key_presses": 0,
    "mouse_moves": 0,
    "mouse_clicks": 0,
    "active_window": None,
    "last_window": None,
    "window_switches": 0,
    "last_switch_time": time.time(),
    "window_times": {},
    "window_open_count": {},
    "window_background_time": {},
    "window_log": [],
    "session_start": time.time(),
    "last_input_time": time.time(),
    "inactive_threshold": 10,
    "click_per_app": {},
    "switch_sequence": [],
    "key_combinations": {},
    "scroll_events": 0,
    "reading_time": {},
    "session_end": None,
    "pause_periods": [],
    "last_pause_start": None,
    "hourly_activity": {},
    "productive_switches": 0,
    "document_names": {},
    "all_open_windows": [],
}

# -----------------------------
# HELPER FUNCTIONS
# -----------------------------
def is_system_process(window_name):
    """Check if a window is a system process that should be ignored"""
    if not window_name:
        return True
    
    # Check Windows system processes
    for system_proc in SYSTEM_PROCESSES:
        if system_proc.lower() in window_name.lower():
            return True
    
    # Check macOS system processes
    for system_proc in MAC_SYSTEM_PROCESSES:
        if system_proc.lower() in window_name.lower():
            return True
    
    # Ignore very short names (likely system processes)
    if len(window_name.strip()) < 2:
        return True
    
    # Ignore windows with sharing notifications
    if "compartiendo tu pantalla" in window_name.lower():
        return True
    if "is sharing your screen" in window_name.lower():
        return True
    
    return False

# -----------------------------
# ACTIVE WINDOW DETECTION
# -----------------------------
def get_active_window():
    try:
        if sys.platform == "darwin":
            script = 'tell application "System Events" to get name of first application process whose frontmost is true'
            active_app = subprocess.check_output(['osascript', '-e', script]).decode('utf-8').strip()
            return active_app if not is_system_process(active_app) else None
        else:
            import pygetwindow as gw
            win = gw.getActiveWindow()
            if win and win.title:
                return str(win.title) if not is_system_process(win.title) else None
            return None
    except:
        return None

# -----------------------------
# DOCUMENT / TAB NAMES
# -----------------------------
def get_document_name(window_name):
    if not window_name:
        return ""

    if sys.platform == "darwin":
        try:
            if "Word" in window_name:
                script = 'tell application "Microsoft Word" to get name of active document'
                return subprocess.check_output(['osascript', '-e', script]).decode('utf-8').strip()
            if "Excel" in window_name:
                script = 'tell application "Microsoft Excel" to get name of active workbook'
                return subprocess.check_output(['osascript', '-e', script]).decode('utf-8').strip()
            if "Safari" in window_name:
                script = 'tell application "Safari" to get name of front document'
                return subprocess.check_output(['osascript', '-e', script]).decode('utf-8').strip()
            if "Chrome" in window_name:
                script = 'tell application "Google Chrome" to get title of active tab of front window'
                return subprocess.check_output(['osascript', '-e', script]).decode('utf-8').strip()
            if "Firefox" in window_name:
                if " — " in window_name:
                    return window_name.split(" — ")[0]
                return window_name
            if "Edge" in window_name:
                script = 'tell application "Microsoft Edge" to get title of active tab of front window'
                return subprocess.check_output(['osascript', '-e', script]).decode('utf-8').strip()
        except:
            return window_name

        if " — " in window_name:
            return window_name.split(" — ")[0]
        if " | " in window_name:
            return window_name.split(" | ")[0]

        return window_name

    else:  # Windows
        try:
            import win32com.client
            if "Word" in window_name:
                word = win32com.client.Dispatch("Word.Application")
                if word.Documents.Count > 0:
                    return word.ActiveDocument.Name
            elif "Excel" in window_name:
                excel = win32com.client.Dispatch("Excel.Application")
                if excel.Workbooks.Count > 0:
                    return excel.ActiveWorkbook.Name
            elif "PowerPoint" in window_name:
                ppt = win32com.client.Dispatch("PowerPoint.Application")
                if ppt.Presentations.Count > 0:
                    return ppt.ActivePresentation.Name
        except:
            pass

        # browser heuristics
        if any(browser in window_name for browser in ["Chrome", "Firefox", "Edge"]):
            if " - " in window_name:
                return window_name.split(" - ")[0]
            if " | " in window_name:
                return window_name.split(" | ")[0]

        # IDE/other apps
        if " — " in window_name:
            return window_name.split(" — ")[0]

        return window_name


def is_browser_distraction(window_name):
    doc_name = get_document_name(window_name)
    if any(browser in window_name for browser in ["Chrome", "Safari", "Firefox", "Edge"]):
        for keyword in BROWSER_DISTRACTIONS:
            if keyword.lower() in doc_name.lower():
                return True
    return False

# -----------------------------
# ALL OPEN WINDOWS / APPS - FIXED WITH FILTERING
# -----------------------------
def get_all_windows():
    """Get all open windows - FILTERED to exclude system processes"""
    try:
        if sys.platform == "darwin":
            script = 'tell application "System Events" to get name of every process whose background only is false'
            output = subprocess.check_output(['osascript', '-e', script]).decode('utf-8').strip()
            windows = [a.strip() for a in output.split(",") if a.strip()]
            # Filter out system processes
            windows = [w for w in windows if not is_system_process(w)]
            return windows
        else:
            import pygetwindow as gw
            # Filter out empty titles, system windows, and very short names
            windows = [w.title for w in gw.getAllWindows() 
                      if w.title and len(w.title) > 0 and not is_system_process(w.title)]
            return windows
    except Exception as e:
        print(f"⚠️ Error getting windows: {e}")
        return []

# -----------------------------
# MONITOR WINDOW
# -----------------------------
def monitor_active_window():
    while True:
        current = get_active_window()
        now = time.time()
        last = activity_state["last_window"]

        # Update all open windows list (filtered)
        activity_state["all_open_windows"] = get_all_windows()

        # Pause detection
        inactive_elapsed = now - activity_state["last_input_time"]
        
        # Start pause if inactive for too long
        if inactive_elapsed > activity_state["inactive_threshold"]:
            if activity_state["last_pause_start"] is None:
                activity_state["last_pause_start"] = activity_state["last_input_time"]
                print(f"⏸️ Pause started at {time.ctime(activity_state['last_pause_start'])}")
        else:
            # End pause when activity resumes
            if activity_state["last_pause_start"] is not None:
                pause_end = now
                pause_duration = pause_end - activity_state["last_pause_start"]
                activity_state["pause_periods"].append({
                    "start": time.ctime(activity_state["last_pause_start"]),
                    "end": time.ctime(pause_end),
                    "duration": int(pause_duration)
                })
                print(f"▶️ Pause ended. Duration: {int(pause_duration)} seconds")
                activity_state["last_pause_start"] = None

        # Window switching logic
        if current != last:
            if last:
                elapsed = now - activity_state["last_switch_time"]
                activity_state["window_times"][last] = activity_state["window_times"].get(last, 0) + elapsed
                activity_state["window_background_time"][last] = activity_state["window_background_time"].get(last, 0)
                activity_state["window_log"].append((time.ctime(), last, "background" if current else "closed"))

            if current:
                activity_state["window_open_count"][current] = activity_state["window_open_count"].get(current, 0) + 1
                activity_state["window_log"].append((time.ctime(), current, "foreground"))
                activity_state["document_names"][current] = get_document_name(current)

            activity_state["switch_sequence"].append(current)
            if len(activity_state["switch_sequence"]) > 50:
                activity_state["switch_sequence"] = activity_state["switch_sequence"][-50:]

            # Productive/distracting switches
            if last:
                def get_app_category(win):
                    if win in PRODUCTIVE_APPS:
                        return "productive"
                    if win in DISTRACTING_APPS or is_browser_distraction(win):
                        return "distracting"
                    return "other"

                last_cat = get_app_category(last)
                curr_cat = get_app_category(current)

                if last_cat != curr_cat and last_cat != "other" and curr_cat != "other":
                    activity_state["productive_switches"] += 1

            activity_state["window_switches"] += 1
            activity_state["active_window"] = current
            activity_state["last_window"] = current
            activity_state["last_switch_time"] = now

        # Background time and reading time
        hour = time.localtime(now).tm_hour
        activity_state["hourly_activity"][hour] = activity_state["hourly_activity"].get(hour, 0) + 0.5

        for w in activity_state["window_times"]:
            if w != current:
                activity_state["window_background_time"][w] = activity_state["window_background_time"].get(w, 0) + 0.5
            else:
                if inactive_elapsed < 5:
                    activity_state["reading_time"][w] = activity_state["reading_time"].get(w, 0) + 0.5

        time.sleep(0.5)

# -----------------------------
# KEYBOARD & MOUSE
# -----------------------------
def on_key_press(key):
    activity_state["key_presses"] += 1
    activity_state["last_input_time"] = time.time()

    try:
        k = str(key)
        if "Key.ctrl" in k or "Key.cmd" in k:
            activity_state["key_combinations"]["ctrl"] = activity_state["key_combinations"].get("ctrl", 0) + 1
        elif "Key.tab" in k:
            activity_state["key_combinations"]["tab"] = activity_state["key_combinations"].get("tab", 0) + 1
        elif "Key.shift" in k:
            activity_state["key_combinations"]["shift"] = activity_state["key_combinations"].get("shift", 0) + 1
    except:
        pass

def on_move(x, y):
    activity_state["mouse_moves"] += 1
    activity_state["last_input_time"] = time.time()

def on_click(x, y, button, pressed):
    if pressed:
        activity_state["mouse_clicks"] += 1
        activity_state["last_input_time"] = time.time()
        current = activity_state["active_window"]
        if current:
            activity_state["click_per_app"][current] = activity_state["click_per_app"].get(current, 0) + 1

def on_scroll(x, y, dx, dy):
    activity_state["scroll_events"] += 1
    activity_state["last_input_time"] = time.time()

# -----------------------------
# CATEGORIZZA APP
# -----------------------------
def categorize_app(app_name, doc_name=None):
    for category, apps in APP_CATEGORIES.items():
        if app_name in apps:
            return category

    if app_name in ["Safari", "Chrome", "Firefox", "Edge"] and doc_name:
        for keyword in BROWSER_DISTRACTIONS:
            if keyword.lower() in doc_name.lower():
                return "distracting"

    return "other"

# -----------------------------
# REPORT LOOP
# -----------------------------
def report_loop_json():
    """Versione JSON del loop per Flutter"""
    while True:
        time.sleep(1) # Aggiornamento più frequente per la UI (1s invece di 5s)
        now = time.time()
        
        # Logica di calcolo (identica a prima)
        current_window = activity_state["active_window"]
        if current_window:
            elapsed = now - activity_state["last_switch_time"]
            activity_state["window_times"][current_window] = activity_state["window_times"].get(current_window, 0) + elapsed
            activity_state["last_switch_time"] = now

        # Creiamo un oggetto dati pulito per Flutter
        data_packet = {
            "type": "update",
            "active_window": current_window if current_window else "Idle",
            "total_time": int(now - activity_state["session_start"]),
            "switches": activity_state['window_switches'],
            "keys": activity_state['key_presses'],
            "mouse": activity_state['mouse_moves'],
            "is_inactive": (now - activity_state["last_input_time"]) > activity_state["inactive_threshold"],
            # Inviamo i top 5 per il grafico
            "top_apps": sorted(activity_state["window_times"].items(), key=lambda x: x[1], reverse=True)[:5]
        }
        
        # STAMPA JSON SU UNA RIGA (importante flush=True)
        print(json.dumps(data_packet), flush=True)

# -----------------------------
# MAIN
# -----------------------------
if __name__ == "__main__":
    # 1. ACQUISIZIONE CONTESTO DA ARGOMENTI (passati da Flutter)
    if len(sys.argv) > 1:
        user_context = sys.argv[1]
    else:
        user_context = "General Creator"
    
    activity_state["user_context"] = user_context

    # Avvia monitoraggio
    activity_state["session_start"] = time.time()
    
    # Thread separati per input
    threading.Thread(target=monitor_active_window, daemon=True).start()
    keyboard_listener = keyboard.Listener(on_press=on_key_press)
    keyboard_listener.start()
    mouse_listener = mouse.Listener(on_move=on_move, on_click=on_click, on_scroll=on_scroll)
    mouse_listener.start()

    try:
        # Usiamo il loop JSON
        report_loop_json()

    except KeyboardInterrupt:
        # Quando Flutter chiude il processo o invia segnale
        activity_state["session_end"] = time.time()
        
        # Comunica a Flutter che stiamo pensando
        print(json.dumps({"type": "status", "message": "Leonardo is composing the Codex..."}), flush=True)
        
        # Genera report LLM
        summary = summarize_activity_with_llm(activity_state)
        
        # Invia il report finale
        final_packet = {
            "type": "report",
            "content": summary
        }
        print(json.dumps(final_packet), flush=True)