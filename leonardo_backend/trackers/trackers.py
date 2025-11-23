import time
import threading
import sys
from pynput import keyboard, mouse
import subprocess
import os

# -----------------------------
# CONFIGURAZIONE APPLICAZIONI
# -----------------------------
DISTRACTING_APPS = ["YouTube", "TikTok", "Netflix", "Facebook", "Instagram", "WhatsApp"]
PRODUCTIVE_APPS = ["VSCode", "PyCharm", "Terminal", "Word", "Excel", "Electron"]

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
    "inactive_threshold": 300,
    # nuove metriche
    "click_per_app": {},          # click per finestra
    "switch_sequence": [],        # sequenza finestre attive
    "key_combinations": {},       # combinazioni di tasti
    "scroll_events": 0,           # scroll generico
    "reading_time": {},            # tempo con finestra aperta senza input
    "session_end": None,
    "pause_periods": [],          # lista tuple (start, end) di inattività
    "last_pause_start": None,
    "hourly_activity": {},        # ore del giorno → tempo attivo
    "productive_switches": 0,     # switch tra app produttive e distrattive
}

# -----------------------------
# ACTIVE WINDOW DETECTION
# -----------------------------
def get_active_window():
    try:
        if sys.platform == "darwin":
            script = 'tell application "System Events" to get name of first application process whose frontmost is true'
            active_app = subprocess.check_output(['osascript', '-e', script]).decode('utf-8').strip()
            return active_app
        else:
            import pygetwindow as gw
            win = gw.getActiveWindow()
            return str(win.title) if win else None
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
                # Firefox non supporta AppleScript nativo per schede, usa heuristica dal titolo
                if " – " in window_name:
                    return window_name.split(" – ")[0]
                return window_name
            if "Edge" in window_name:
                script = 'tell application "Microsoft Edge" to get title of active tab of front window'
                return subprocess.check_output(['osascript', '-e', script]).decode('utf-8').strip()
        except:
            return window_name

        # fallback generico: split dal titolo finestra
        if " – " in window_name:
            return window_name.split(" – ")[0]
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
        if " – " in window_name:
            return window_name.split(" – ")[0]

        return window_name
# -----------------------------
# MONITOR WINDOW
# -----------------------------
def monitor_active_window():
    while True:
        current = get_active_window()
        now = time.time()
        last = activity_state["last_window"]

        # gestione pause
        inactive_elapsed = now - activity_state["last_input_time"]
        if inactive_elapsed > activity_state["inactive_threshold"]:
            if activity_state["last_pause_start"] is None:
                activity_state["last_pause_start"] = now
        else:
            if activity_state["last_pause_start"]:
                activity_state["pause_periods"].append(
                    (activity_state["last_pause_start"], now)
                )
                activity_state["last_pause_start"] = None

        # aggiornamento sequenze e switch
        if current != last:
            if last:
                elapsed = now - activity_state["last_switch_time"]
                activity_state["window_times"][last] = activity_state["window_times"].get(last, 0) + elapsed
                activity_state["window_background_time"][last] = activity_state["window_background_time"].get(last, 0)
                activity_state["window_log"].append((time.ctime(), last, "background" if current else "closed"))

            if current:
                activity_state["window_open_count"][current] = activity_state["window_open_count"].get(current, 0) + 1
                activity_state["window_log"].append((time.ctime(), current, "foreground"))

            # sequenza finestre per pattern switch
            activity_state["switch_sequence"].append(current)
            if len(activity_state["switch_sequence"]) > 50:
                activity_state["switch_sequence"] = activity_state["switch_sequence"][-50:]

            # conteggio multitasking: switch tra produttive e distrattive
            if last:
                last_cat = "productive" if last in PRODUCTIVE_APPS else "distracting" if last in DISTRACTING_APPS else "other"
                curr_cat = "productive" if current in PRODUCTIVE_APPS else "distracting" if current in DISTRACTING_APPS else "other"
                if last_cat != curr_cat and last_cat != "other" and curr_cat != "other":
                    activity_state["productive_switches"] += 1

            activity_state["window_switches"] += 1
            activity_state["active_window"] = current
            activity_state["last_window"] = current
            activity_state["last_switch_time"] = now

        # aggiornamento background / reading time e distribuzione oraria
        hour = time.localtime(now).tm_hour
        activity_state["hourly_activity"][hour] = activity_state["hourly_activity"].get(hour, 0) + 0.5

        for w in activity_state["window_times"]:
            if w != current:
                activity_state["window_background_time"][w] = activity_state["window_background_time"].get(w, 0) + 0.5
            else:
                # tempo di lettura
                if inactive_elapsed < 5:
                    activity_state["reading_time"][w] = activity_state["reading_time"].get(w, 0) + 0.5

        time.sleep(0.5)
# -----------------------------
# KEYBOARD & MOUSE
# -----------------------------
def on_key_press(key):
    activity_state["key_presses"] += 1
    activity_state["last_input_time"] = time.time()

    # track combinazioni ctrl/cmd + altri tasti (browser tab switch, shortcuts)
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
# ALL OPEN WINDOWS / APPS
# -----------------------------
def get_all_windows():
    try:
        if sys.platform == "darwin":
            script = 'tell application "System Events" to get name of every process whose background only is false'
            output = subprocess.check_output(['osascript', '-e', script]).decode('utf-8').strip()
            return [a.strip() for a in output.split(",") if a.strip()]
        else:
            import pygetwindow as gw
            return [w.title for w in gw.getWindows() if w.title]
    except:
        return []

# -----------------------------
# CATEGORIZZA APP
# -----------------------------
def categorize_app(app_name):
    for category, apps in APP_CATEGORIES.items():
        if app_name in apps:
            return category
    return "other"

# -----------------------------
# REPORT LOOP
# -----------------------------
def report_loop():
    while True:
        time.sleep(5)
        now = time.time()
        activity_state["session_end"] = now

        current_window = activity_state["active_window"]
        if current_window:
            elapsed = now - activity_state["last_switch_time"]
            activity_state["window_times"][current_window] = activity_state["window_times"].get(current_window, 0) + elapsed
            activity_state["last_switch_time"] = now

        inactive_time = now - activity_state["last_input_time"]
        is_inactive = inactive_time > activity_state["inactive_threshold"]

        all_windows = get_all_windows()

        print("\n--- ACTIVITY REPORT ---")
        print(f"Active window       : {current_window}")
        print(f"Window switches     : {activity_state['window_switches']}")
        print(f"Key presses         : {activity_state['key_presses']}")
        print(f"Mouse moves         : {activity_state['mouse_moves']}")
        print(f"Mouse clicks        : {activity_state['mouse_clicks']}")
        print(f"Scroll events       : {activity_state['scroll_events']}")
        print(f"All open windows    : {all_windows}")
        print(f"Time per window     :")

        for w, t in activity_state["window_times"].items():
            bg_time = activity_state["window_background_time"].get(w, 0)
            reading_time = activity_state["reading_time"].get(w, 0)
            category = categorize_app(w)
            opens = activity_state["window_open_count"].get(w, 0)
            doc_name = get_document_name(w)
            clicks = activity_state["click_per_app"].get(w, 0)
            print(f"  {w}: {int(t)} sec (fg), {int(bg_time)} sec (bg), reading {int(reading_time)} sec, clicks {clicks}, opened {opens} times, category: {category}, document/tab: {doc_name}")

        print(f"Inactive?           : {is_inactive} ({int(inactive_time)} sec)")
        print(f"Session start       : {time.ctime(activity_state['session_start'])}")
        print(f"Session end         : {time.ctime(activity_state['session_end'])}")
        print(f"Pause periods       : {activity_state['pause_periods']}")
        print(f"Switches productive/distracting : {activity_state['productive_switches']}")
        print("Hourly activity distribution:")
        for h in sorted(activity_state["hourly_activity"]):
            print(f"  {h}:00 - {int(activity_state['hourly_activity'][h])} sec")

        print("Recent window sequence (last 10):")
        print(f"  {activity_state['switch_sequence'][-10:]}")
        print("Key combinations:")
        print(f"  {activity_state['key_combinations']}")
        print("Window log (last 10):")
        for log in activity_state["window_log"][-10:]:
            print(f"  {log}")
        print("------------------------\n")

        # reset contatori temporanei
        activity_state["key_presses"] = 0
        activity_state["mouse_moves"] = 0
        activity_state["mouse_clicks"] = 0
        activity_state["window_switches"] = 0
        activity_state["scroll_events"] = 0
        activity_state["key_combinations"] = {}
        activity_state["productive_switches"] = 0

# -----------------------------
# MAIN
# -----------------------------
if __name__ == "__main__":
    print("🔍 Starting enhanced activity monitor (Windows + macOS)...")

    threading.Thread(target=monitor_active_window, daemon=True).start()

    keyboard_listener = keyboard.Listener(on_press=on_key_press)
    keyboard_listener.start()

    mouse_listener = mouse.Listener(on_move=on_move, on_click=on_click)
    mouse_listener.start()

    try:
        report_loop()
    except KeyboardInterrupt:
        print("\n🛑 User stopped monitoring. Generating summary...")
        from summarize_activity import summarize_activity
        summary = summarize_activity(activity_state)
        import pprint
        pprint.pprint(summary)