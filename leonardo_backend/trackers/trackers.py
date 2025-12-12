import json
import time
import threading
import sys
from pynput import keyboard, mouse
import subprocess
import os
from local_summarizer import summarize_activity_with_llm, get_start_session_advice
from llm_client_2 import create_json_memory, generate_final_report_from_memory

# -----------------------------
# CONFIGURAZIONE APPLICAZIONI
# -----------------------------
DISTRACTING_APPS = ["YouTube", "TikTok", "Netflix", "Facebook", "Instagram", "WhatsApp", "TV"]
PRODUCTIVE_APPS = ["VSCode", "PyCharm", "Terminal", "Word", "Excel", "Electron", "GitHub", "GitHub Desktop", "Notes", "Note", "Obsidian", "Notion", "Sublime Text", "IntelliJ IDEA", "Xcode", "Android Studio"]
BROWSER_DISTRACTIONS = ["Facebook", "Instagram", "Netflix", "YouTube", "TikTok", "Reddit", "Twitter", "Prime Video", "Twitch", "Spotify"]

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
    "total_distracted_time" : 0
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

def log_debug(data):
    #for debugging
    # Scrive nella stessa cartella dello script
    with open("debug_leonardo.jsonl", "a", encoding="utf-8") as f:
        f.write(json.dumps(data, ensure_ascii=False) + "\n")

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
    if window_name is None or not isinstance(window_name, str):     # returns false when it cant read the page title instead of creating an error
        return False                                                # may happen when switching windows or if the window has no title
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
            output = subprocess.check_output(['osascript', '-e', script], stderr=subprocess.DEVNULL).decode('utf-8').strip()
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
    # Stato Iniziale della Memoria
    memory_context = {
        "focus_score": 100,
        "status": "Starting",
        "user_role": activity_state.get("user_context", "General Creator"),
        "summary_so_far": "Session started.",
        "leonardo_comment": "I am observing.",
        "history": []
    }
    
    activity_state["memory_context"] = memory_context
    
    last_chunk_time = time.time()
    
    # Accumulatori per il chunk di 30 secondi
    chunk_windows_list = []      # Nomi completi (App + Titolo)
    chunk_distraction_hits = 0   # Contatore secondi di distrazione
    chunk_samples = 0            # Contatore totale secondi

    while True:
        time.sleep(1)
        now = time.time()
        
        # 1. Recupera App e Titolo (es. "Google Chrome", "YouTube - Funny Cats")
        app_name = activity_state["active_window"]
        doc_name = ""
        
        # Se c'è una finestra attiva, cerchiamo il dettaglio (Titolo Tab/Documento)
        if app_name:
            doc_name = get_document_name(app_name)
            
            # Aggiorniamo i tempi globali (logica esistente)
            elapsed = now - activity_state["last_switch_time"]
            activity_state["window_times"][app_name] = activity_state["window_times"].get(app_name, 0) + elapsed
            activity_state["last_switch_time"] = now

        # 2. Determina se è una distrazione ORA (ogni secondo)
        is_distracted_now = False
        full_window_name = app_name if app_name else "Idle"
        
        if app_name:
            # Aggiungiamo il titolo al nome per chiarezza
            if doc_name:
                full_window_name = f"{app_name} ({doc_name})"
            
            # Check 1: L'App è nella lista nera? (es. Spotify app)
            if app_name in DISTRACTING_APPS:
                is_distracted_now = True
            
            # Check 2: È un browser e il sito è nella lista nera?
            elif app_name in ["Google Chrome", "Safari", "Firefox", "Microsoft Edge", "Arc"]:
                # Controlla keywords nel titolo (es. "YouTube" in "YouTube - Video")
                for distractor in BROWSER_DISTRACTIONS:
                    if distractor.lower() in doc_name.lower():
                        is_distracted_now = True
                        break
        
        # 3. Accumula dati per il Chunk (Matematica)
        chunk_samples += 1
        if is_distracted_now:
            chunk_distraction_hits += 1
            activity_state["total_distracted_time"] += 1
        
        if app_name:
            chunk_windows_list.append(full_window_name)

        # 4. Invia dati UI a Flutter (Timer veloce)
        data_packet = {
            "type": "update",
            "active_window": full_window_name, # Ora mostriamo anche il titolo a Flutter!
            "total_time": int(now - activity_state["session_start"]),
            "switches": activity_state['window_switches'],
            "keys": activity_state['key_presses'],
            "mouse": activity_state['mouse_moves'],
            "is_inactive": (now - activity_state["last_input_time"]) > activity_state["inactive_threshold"],
            "top_apps": sorted(activity_state["window_times"].items(), key=lambda x: x[1], reverse=True)[:5]
        }

        print(json.dumps(data_packet), flush=True)

        # === Check every 30 seconds ===
        if now - last_chunk_time >= 30:
            
            # Don't use this anymore
            """distraction_percent = 0
            if chunk_samples > 0:
                distraction_percent = int((chunk_distraction_hits / chunk_samples) * 100)"""

                # A. Distrazione RECENTE (ultimi 30s) -> Per l'emozione immediata
            recent_distraction = 0
            if chunk_samples > 0:
                recent_distraction = int((chunk_distraction_hits / chunk_samples) * 100)

            # B. Distrazione GLOBALE (tutta la sessione) -> Per il Focus Score stabile
            session_duration = now - activity_state["session_start"]
            global_distraction = 0
            if session_duration > 0:
                global_distraction = int((activity_state["total_distracted_time"] / session_duration) * 100)
            
            # Prepariamo i dati per l'LLM
            # Usiamo set() per mandare solo la lista unica delle app usate
            unique_windows = list(set(chunk_windows_list))
            
            chunk_data = {
                "windows": unique_windows, # L'LLM vedrà "Chrome (YouTube)"
                "duration": 30,
                #"distraction_level": distraction_percent, 
                "recent_distraction": recent_distraction, # <--- Modifica qui
                "global_distraction": global_distraction  # <--- Modifica qui
            }
            
            try:
                # Chiediamo a Groq
                new_memory = create_json_memory(chunk_data, memory_context, activity_state["user_context"])
                  # ⭐ IMPORTANTE: Aggiungi alla history
                if 'history' not in new_memory:
                    new_memory['history'] = memory_context.get('history', [])
                
                # Aggiungi questa iterazione alla history
                history_entry = {
                    "iteration": len(new_memory['history']) + 1,
                    "timestamp": now,
                    "score": new_memory.get('focus_score', 50),
                    "windows": unique_windows,
                    "recent_distraction": recent_distraction,
                    "global_distraction": global_distraction,
                    "duration": 30
                }
                new_memory['history'].append(history_entry)
                
                # ⭐ Mantieni history limitata (ultimi 50 entries)
                if len(new_memory['history']) > 50:
                    new_memory['history'] = new_memory['history'][-50:]
                
                memory_context = new_memory
                activity_state["memory_context"] = memory_context 
                
                # Pacchetto per Flutter
                leo_packet = {
                    "type": "leo_comment",
                    "content": memory_context.get('leonardo_comment', 'Observing...'),
                    "focus_score": memory_context.get('focus_score', 100),
                    "emotion": memory_context.get('leonardo_emotion', 'neutral') 
                }
                print(json.dumps(leo_packet), flush=True)
                
                # Debug Log (Per vedere se la matematica funziona)
                log_debug({
                    "type": "LLM_MEMORY_DUMP", 
                    "iteration": len(memory_context['history']),
                    "current_score": memory_context.get('focus_score', 100),
                    "math_distraction_percent": global_distraction,
                    "apps_seen": unique_windows,
                    "history_size": len(memory_context['history'])
                })

            except Exception as e:
                print(f"⚠️ LLM Error: {e}", file=sys.stderr)

            # Reset
            chunk_windows_list = []
            chunk_distraction_hits = 0
            chunk_samples = 0
            last_chunk_time = now
            
# -----------------------------
# MAIN
# -----------------------------

def _calculate_grade(score):
    """Calculate letter grade from score"""
    if score >= 90:
        return "A+"
    elif score >= 85:
        return "A"
    elif score >= 80:
        return "A-"
    elif score >= 75:
        return "B+"
    elif score >= 70:
        return "B"
    elif score >= 65:
        return "B-"
    elif score >= 60:
        return "C+"
    elif score >= 50:
        return "C"
    else:
        return "D"
    
if __name__ == "__main__":
    # 1. ACQUISIZIONE CONTESTO DA ARGOMENTI (passati da Flutter)
    if len(sys.argv) > 1:
        user_context = sys.argv[1]
    else:
        user_context = "General Work Session"

    try:
        # --- ADVICE PRE-SESSION ---
        # asking llm for advice
        startup_advice = get_start_session_advice(user_context)

        # sending to flutter
        print(json.dumps({
            "type": "leo_comment",
            "content": startup_advice,
            #"emotion": "interested"
        }), flush=True)

    except Exception as e:
        sys.stderr.write(f"Error getting startup advice: {e}\n")
            
    activity_state["user_context"] = user_context

    # --- MODIFICA CHIAVE: Generazione Consigli Iniziali ---
    # Prima di partire, chiediamo a Leonardo il consiglio e lo mandiamo a Flutter
    try:
        # Nota: Flutter deve gestire un pacchetto con type: "initial_advice"
        advice = get_start_session_advice(user_context)
        print(json.dumps({
            "type": "initial_advice",
            "content": advice
        }), flush=True)
    except Exception as e:
        log_debug({"error_advice": str(e)})
    # -------------------------------------------------------
    try:
        sys.stdin.readline()
    except: 
        pass

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
        
        # Genering report LLM
        # summary = summarize_activity_with_llm(activity_state)
        # now generates using the final json instead of the logs like before
        final_memory = activity_state.get("memory_context", {})

        session_duration = activity_state["session_end"] - activity_state["session_start"]
        sorted_apps = sorted(activity_state["window_times"].items(), key=lambda x: x[1], reverse=True)[:5]

        stats_package = {
            "duration_seconds": int(session_duration),
            "total_switches": activity_state["window_switches"],
            "focus_score": final_memory.get("focus_score", 50),
            "top_apps": [{"name": k, "seconds": int(v)} for k, v in sorted_apps], # Formattiamo bene per JSON
            "total_distraction_time": activity_state.get("total_distracted_time", 0),
            "pause_count": len(activity_state.get("pause_periods", [])),
            "key_presses": activity_state.get("key_presses", 0),
            "mouse_clicks": activity_state.get("mouse_clicks", 0)
        }

        try:
            # generating the final json
            #report_markdown = generate_final_report_from_memory(final_memory)
            report_markdown = generate_final_report_from_memory(
                final_memory, 
                activity_state["user_context"],
                stats_package
            )
            # Invia il report finale
            final_packet = {
                "type": "report",
                "content": report_markdown,
                "stats": stats_package,
                "final_score": final_memory.get("focus_score", 50),
                "grade": _calculate_grade(final_memory.get("focus_score", 50)),
                "total_iterations": len(final_memory.get('history', []))
            }
            print(json.dumps(final_packet), flush=True)

        except Exception as e:
            print(f"⚠️ Error generating report: {e}", file=sys.stderr)