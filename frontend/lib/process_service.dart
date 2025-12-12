import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'package:path/path.dart' as p;

class LeonardoService extends ChangeNotifier {
  Process? _process;
  
  // Stato UI
  bool isRunning = false;
  bool isGeneratingReport = false;
  String currentContext = "";
  bool isWaitingForAdvice = false;
  
  // Gestione Consigli Iniziali
  String? initialAdvice; 
  bool isAdviceAcknowledged = false;

  // Dati in tempo reale
  String activeWindow = "Waiting...";
  int totalTime = 0;
  int switches = 0;
  int keyPresses = 0;
  int mouseClicks = 0;
  List<dynamic> topApps = [];
  
  // Report finale
  String? finalReport;
  Map<String, dynamic>? finalStats; // ⭐ AGGIUNTO per metriche reali
  Map<String, dynamic>? reportStats; // Manteniamo per compatibilità

  // Feedback Leonardo
  String emotion = "neutral"; 
  String leoComment = "I am observing your work.";
  int focusScore = 100; // ⭐ AGGIUNTO per tracking real-time

  // Status dinamico per UI
  String currentStatus = "good"; // ⭐ AGGIUNTO: awesome/good/warning/bad

  // 1. Rileva automaticamente l'eseguibile Python
  String get pythonExec {
    if (kIsWeb) return ""; 
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
  
  final String scriptName = 'trackers.py';
  
  Future<void> startSession(String context) async {
    currentContext = context;
    isRunning = true;
    finalReport = null;
    finalStats = null; // ⭐ Reset stats
    reportStats = null;
    
    // Reset advice per la nuova sessione
    initialAdvice = null;
    isAdviceAcknowledged = false;
    isWaitingForAdvice = true;
    
    // Reset metriche
    focusScore = 100;
    currentStatus = "good";
    
    notifyListeners();

    print("🚀 FLUTTER: Avvio Sessione...");
    print("📂 Directory di lavoro: $backendPath");
    print("🐍 Eseguibile: $pythonExec");
    print("🎯 Contesto: $context");

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
    try {
      if (!line.trim().startsWith('{')) return; 
      
      final data = jsonDecode(line);
      final type = data['type'] as String?;

      if (type == null) return;

      switch (type) {
        // ============================================
        // CONSIGLI INIZIALI
        // ============================================
        case 'initial_advice':
          print("📜 Advice received from Python");
          initialAdvice = data['content'];
          isWaitingForAdvice = false;
          isAdviceAcknowledged = false;
          notifyListeners();
          break;

        // ============================================
        // UPDATE REAL-TIME (ogni secondo)
        // ============================================
        case 'update':
          activeWindow = data['active_window'] ?? "Idle";
          totalTime = data['total_time'] ?? 0;
          switches = data['switches'] ?? 0;
          keyPresses = data['keys'] ?? 0;
          mouseClicks = data['mouse'] ?? 0;
          topApps = data['top_apps'] ?? [];
          notifyListeners();
          break;

        // ============================================
        // HEARTBEAT (ogni 2s con status)
        // ============================================
        case 'heartbeat':
          activeWindow = data['active'] ?? activeWindow;
          totalTime = data['total_time'] ?? totalTime;
          
          // ⭐ Aggiorna status se presente
          if (data.containsKey('current_status')) {
            currentStatus = data['current_status'] ?? "good";
          }
          notifyListeners();
          break;

        // ============================================
        // COMMENTO LEONARDO (ogni 30s)
        // ============================================
        case 'leo_comment':
          if (data.containsKey('content')) {
            leoComment = data['content'];
          }

          if (data.containsKey('emotion')) {
            emotion = data['emotion'].toString().toLowerCase();
          }

          // ⭐ Aggiorna focus score
          if (data.containsKey('focus_score')) {
            focusScore = data['focus_score'] ?? 100;
          }
          
          notifyListeners();
          break;

        // ============================================
        // LLM UPDATE (nuovo sistema con status UI)
        // ============================================
        case 'llm_update':
          leoComment = data['insights'] ?? leoComment;
          focusScore = data['focus_score'] ?? focusScore;
          currentStatus = data['status'] ?? currentStatus;
          
          // Gestisci alerts se presenti
          if (data['alerts'] != null && (data['alerts'] as List).isNotEmpty) {
            print("⚠️ Alerts: ${data['alerts']}");
          }
          
          notifyListeners();
          break;

        // ============================================
        // CRITICAL ALERT (status bad)
        // ============================================
        case 'critical_alert':
          emotion = "concerned";
          leoComment = data['message'] ?? "Focus alert!";
          currentStatus = "bad";
          print("🚨 CRITICAL ALERT: ${data['message']}");
          notifyListeners();
          break;

        // ============================================
        // ACHIEVEMENT (status awesome)
        // ============================================
        case 'achievement':
          emotion = "happy";
          leoComment = data['message'] ?? "Excellent work!";
          currentStatus = "awesome";
          print("🎉 ACHIEVEMENT: ${data['message']}");
          notifyListeners();
          break;

        // ============================================
        // STATUS GENERICO (es. "generating report...")
        // ============================================
        case 'status':
          isGeneratingReport = true;
          leoComment = data['message'] ?? "Generating report...";
          notifyListeners();
          break;

        // ============================================
        // REPORT FINALE ⭐ CON STATS COMPLETO
        // ============================================
        case 'report':
          print("📊 Report ricevuto da Python");
          
          finalReport = data['content'];
          
          // ⭐ Estrai stats completo
          if (data.containsKey('stats')) {
            reportStats = data['stats'] as Map<String, dynamic>?;
          }
          
          // ⭐ Estrai metriche finali per Quick Stats
          finalStats = {
            'final_score': data['final_score'] ?? focusScore,
            'grade': data['grade'] ?? _calculateGrade(focusScore),
            'total_iterations': data['total_iterations'] ?? 0,
            'duration_seconds': reportStats?['duration_seconds'] ?? totalTime,
            'total_switches': reportStats?['total_switches'] ?? switches,
            'top_apps': reportStats?['top_apps'] ?? [],
            'total_distraction_time': reportStats?['total_distraction_time'] ?? 0,
            'pause_count': reportStats?['pause_count'] ?? 0,
          };
          
          print("✅ Stats estratte: $finalStats");
          
          isGeneratingReport = false;
          isRunning = false;
          currentStatus = "completed";
          
          notifyListeners();
          _process?.kill(); 
          break;

        // ============================================
        // ERRORE
        // ============================================
        case 'error':
          print("❌ Python Error: ${data['message']}");
          leoComment = "An error occurred: ${data['message']}";
          emotion = "confused";
          notifyListeners();
          break;

        default:
          print("⚠️ Unknown message type: $type");
      }
    } catch (e) {
      print("⚠️ Errore parsing JSON: $e");
      print("   Line: $line");
    }
  }

  // ============================================
  // HELPER: Calcola grade da score
  // ============================================
  String _calculateGrade(int score) {
    if (score >= 90) return "A+";
    if (score >= 85) return "A";
    if (score >= 80) return "A-";
    if (score >= 75) return "B+";
    if (score >= 70) return "B";
    if (score >= 65) return "B-";
    if (score >= 60) return "C+";
    if (score >= 50) return "C";
    return "D";
  }

  // ============================================
  // ACKNOWLEDGE ADVICE (sblocca Python)
  // ============================================
  void acknowledgeAdvice() {
    print("✅ User acknowledged advice");
    _process?.stdin.writeln('START'); 
    isAdviceAcknowledged = true;
    notifyListeners();
  }

  // ============================================
  // STOP SESSION
  // ============================================
  Future<void> stopSession() async {
    print("🛑 Invio segnale di stop a Python...");
    _process?.kill(ProcessSignal.sigint);
    
    // Aspetta un po' per permettere a Python di generare il report
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // ============================================
  // RESET (nuova sessione)
  // ============================================
  void reset() {
    print("🔄 Resetting application state...");
    
    // Report e stats
    finalReport = null;
    finalStats = null;
    reportStats = null;
    
    // Stato sessione
    isRunning = false;
    isGeneratingReport = false;
    
    // Dati real-time
    activeWindow = "Waiting...";
    totalTime = 0;
    switches = 0;
    keyPresses = 0;
    mouseClicks = 0;
    topApps = [];
    
    // Context e consigli
    currentContext = "";
    initialAdvice = null;
    isAdviceAcknowledged = false;
    isWaitingForAdvice = false;
    
    // Leonardo feedback
    emotion = "neutral"; 
    leoComment = "Observing your craft...";
    focusScore = 100;
    currentStatus = "good";
    
    notifyListeners();
  }

  // ============================================
  // GETTERS di comodo
  // ============================================
  
  // Per compatibilità con codice esistente
  int get currentFocusScore => focusScore;
  
  String get currentEmotion => emotion;
  
  bool get hasReport => finalReport != null && finalReport!.isNotEmpty;
  
  bool get hasStats => finalStats != null;
  
  // Formatta tempo in MM:SS
  String get formattedTime {
    final minutes = totalTime ~/ 60;
    final seconds = totalTime % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================
  // DISPOSE
  // ============================================
  @override
  void dispose() {
    _process?.kill();
    super.dispose();
  }
}