import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'package:path/path.dart' as p; // Aggiungi 'path' al pubspec.yaml se non c'è

class LeonardoService extends ChangeNotifier {
  Process? _process;
  
  // Stato UI
  bool isRunning = false;
  bool isGeneratingReport = false;
  String currentContext = "";
  
  // Dati in tempo reale
  String activeWindow = "Waiting...";
  int totalTime = 0;
  int switches = 0;
  List<dynamic> topApps = [];
  String? finalReport;

  String emotion = "neutral"; // Default Leo's emotion
  String leoComment = "I am observing your work.";

  // ---------------------------------------------------------------------------
  // CONFIGURAZIONE PERCORSI
  // ---------------------------------------------------------------------------
  
  // 1. Il tuo Python
  //final String pythonExec = '/Library/Frameworks/Python.framework/Versions/3.13/bin/python3';
  //final String pythonExec = '/Library/Frameworks/Python.framework/Versions/3.12/bin/python3'; 
  
  // 2. La cartella dei file Python
  //final String backendPath = '/Users/davidravelli/Documents/GitHub/Leonardo/leonardo_backend/trackers'; 
  //final String backendPath = '/Users/filippo/Documents/PoliMI/Creativity Science and Innovation/Leonardo/leonardo_backend/trackers'; 



// 1. Rileva automaticamente l'eseguibile Python in base al sistema operativo
// Su Windows cerca "python", su Mac/Linux cerca "python3"
String get pythonExec {
    if (kIsWeb) return ""; // Su web non c'è python
    return Platform.isWindows ? 'python' : 'python3';
  }

// 2. Calcola il percorso backend in modo relativo
String get backendPath {
    if (kIsWeb) return ""; 
    return p.join(
      Directory.current.parent.path,
      'leonardo_backend',
      'trackers'
    );
  }

  
  // 3. Il nome del file principale
  final String scriptName = 'trackers.py';
  // ---------------------------------------------------------------------------
  
  Future<void> startSession(String context) async {
    currentContext = context;
    isRunning = true;
    finalReport = null;
    notifyListeners();

    print("🚀 FLUTTER: Avvio Sessione...");
    print("📂 Directory di lavoro: $backendPath");
    print("🐍 Eseguibile: $pythonExec");

    try {
      _process = await Process.start(
        pythonExec, 
        ['-u', scriptName, context], 
        workingDirectory: backendPath, 
        runInShell: true, 
      );

      print("✅ Processo avviato (PID: ${_process!.pid})");

      _process!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        _parsePythonOutput(line);
      });

      _process!.stderr.transform(utf8.decoder).listen((data) {
        if (data.trim().isNotEmpty) {
          print("❌ PYTHON ERROR: $data"); 
        }
      });

    } catch (e) {
      print("❌ ERRORE LANCIO FLUTTER: $e");
      isRunning = false;
      notifyListeners();
    }
  }

  void _parsePythonOutput(String line) {
    //print("📥 RAW PYTHON: $line"); // DEBUGGING
    try {
      if (!line.trim().startsWith('{')) return; 
      
      final data = jsonDecode(line);

      if (data['type'] == 'update') {
        activeWindow = data['active_window'];
        totalTime = data['total_time'];
        switches = data['switches'];
        topApps = data['top_apps'];
        notifyListeners();
      } 
      
      else if (data['type'] == 'leo_comment') {
        print("💡 Trovato commento di Leo!");   // DEBUGGING

        if (data.containsKey('content')) {
          leoComment = data['content'];
        }

        if (data.containsKey('emotion')) {
          emotion = data['emotion'].toString().toLowerCase();
          print("🎨 FLUTTER: Emozione cambiata in -> $emotion"); // DEBUGGING
        }
        
        notifyListeners();
      }
      else if (data['type'] == 'status') {
        isGeneratingReport = true;
        notifyListeners();
      }
      else if (data['type'] == 'report') {
        finalReport = data['content'];
        isGeneratingReport = false;
        isRunning = false;
        notifyListeners();
        _process?.kill(); 
      }
    } catch (e) {
      print("⚠️ Errore parsing JSON: $e");
    }
  }

  Future<void> stopSession() async {
    print("🛑 Invio segnale di stop a Python...");
    _process?.kill(ProcessSignal.sigint);
  }

  // --- ECCO LA FUNZIONE RESET (DENTRO LA CLASSE) ---
  void reset() {
    print("🔄 Resetting application state...");
    finalReport = null;
    isRunning = false;
    isGeneratingReport = false;
    activeWindow = "Waiting...";
    totalTime = 0;
    switches = 0;
    topApps = [];
    currentContext = "";
    emotion = "neutral"; 
    leoComment = "Observing your craft...";
    
    notifyListeners();
  }

}