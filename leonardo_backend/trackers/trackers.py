import time
import threading
import sys
from pynput import keyboard, mouse
import subprocess

# -----------------------------
# CONFIGURAZIONE APPLICAZIONI
# -----------------------------
DISTRACTING_APPS = ["YouTube", "TikTok", "Netflix", "Facebook", "Instagram"]
PRODUCTIVE_APPS = ["VSCode", "PyCharm", "Terminal", "Word", "Excel"]

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
    "window_times": {},        # tempo cumulativo per finestra {nome_finestra: secondi}
    "window_open_count": {},   # numero volte che un'app viene aperta
    "session_start": time.time(),
    "last_input_time": time.time(),
    "inactive_threshold": 40  # da reimpostare a 5 minuti
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

def monitor_active_window():
    while True:
        current = get_active_window()
        now = time.time()

        # Aggiorna tempo della finestra precedente
        last = activity_state["last_window"]
        if last and last != current:
            elapsed = now - activity_state["last_switch_time"]
            activity_state["window_times"][last] = activity_state["window_times"].get(last, 0) + elapsed
            # Conta apertura/chiusura
            activity_state["window_open_count"][current] = activity_state["window_open_count"].get(current, 0) + 1
            activity_state["window_switches"] += 1

        # Aggiorna stato attuale
        if current:
            activity_state["active_window"] = current
            activity_state["last_window"] = current
            activity_state["last_switch_time"] = now

        time.sleep(0.5)

# -----------------------------
# KEYBOARD & MOUSE LISTENERS
# -----------------------------
def on_key_press(key):
    activity_state["key_presses"] += 1
    activity_state["last_input_time"] = time.time()

def on_move(x, y):
    activity_state["mouse_moves"] += 1
    activity_state["last_input_time"] = time.time()

def on_click(x, y, button, pressed):
    if pressed:
        activity_state["mouse_clicks"] += 1
        activity_state["last_input_time"] = time.time()

# -----------------------------
# ALL OPEN WINDOWS / APPS
# -----------------------------
def get_all_windows():
    try:
        if sys.platform == "darwin":
            script = 'tell application "System Events" to get name of every process whose background only is false'
            output = subprocess.check_output(['osascript', '-e', script]).decode('utf-8').strip()
            apps = [a.strip() for a in output.split(",") if a.strip()]
            return apps
        else:
            import pygetwindow as gw
            return [w.title for w in gw.getWindows() if w.title]
    except:
        return []

# -----------------------------
# REPORT LOOP
# -----------------------------
def report_loop():
    while True:
        time.sleep(5)
        now = time.time()

        # Aggiorna tempo finestra attiva
        current_window = activity_state["active_window"]
        if current_window:
            elapsed = now - activity_state["last_switch_time"]
            activity_state["window_times"][current_window] = activity_state["window_times"].get(current_window, 0) + elapsed
            activity_state["last_switch_time"] = now

        # Controlla inattività
        inactive_time = now - activity_state["last_input_time"]
        is_inactive = inactive_time > activity_state["inactive_threshold"]

        all_windows = get_all_windows()

        print("\n--- ACTIVITY REPORT ---")
        print(f"Active window       : {activity_state['active_window']}")
        print(f"Window switches     : {activity_state['window_switches']}")
        print(f"Key presses         : {activity_state['key_presses']}")
        print(f"Mouse moves         : {activity_state['mouse_moves']}")
        print(f"Mouse clicks        : {activity_state['mouse_clicks']}")
        print(f"All open windows    : {all_windows}")
        print(f"Time per window     :")
        for w, t in activity_state["window_times"].items():
            print(f"  {w}: {int(t)} sec, opened {activity_state['window_open_count'].get(w,0)} times")
        print(f"Inactive?           : {is_inactive} ({int(inactive_time)} sec)")
        print(f"Session start       : {time.ctime(activity_state['session_start'])}")
        print("------------------------\n")

        # reset counters
        activity_state["key_presses"] = 0
        activity_state["mouse_moves"] = 0
        activity_state["mouse_clicks"] = 0
        activity_state["window_switches"] = 0

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

    report_loop()