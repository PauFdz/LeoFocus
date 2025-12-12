import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../process_service.dart';
import '../theme.dart';
import '../widgets/glass_card_widget.dart';

class RunningView extends StatelessWidget {
  const RunningView({super.key});

  @override
  Widget build(BuildContext context) {
    final leonardo = Provider.of<LeonardoService>(context);

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- LEFT COLUMN: UNICA CARD (Avatar + Timer) ---
              Expanded(
                flex: 2,
                child: GlassCard( // <--- ORA È UN'UNICA GLASS CARD
                  child: Column(
                    children: [
                      // 1. SEZIONE AVATAR (Si prende tutto lo spazio disponibile)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildRunningAvatar(context, leonardo, size: 130), // Un po' più grande
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                leonardo.leoComment,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500, // Leggermente più marcato
                                  fontStyle: FontStyle.italic,
                                  color: LeonardoTheme.ink,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Divisore sottile per separare visivamente l'area timer
                      Divider(
                        color: LeonardoTheme.inkLight.withOpacity(0.1),
                        height: 32,
                        thickness: 1,
                      ),

                      // 2. SEZIONE TIMER (Ancorata in basso)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: LeonardoTheme.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.timer_outlined, 
                              color: LeonardoTheme.accent, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "SESSION TIME",
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: LeonardoTheme.inkLight,
                                ),
                              ),
                              Text(
                                _formatTime(leonardo.totalTime),
                                style: GoogleFonts.chivoMono(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: LeonardoTheme.ink,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Right Column: App Usage 
              Expanded(
                flex: 3,
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.apps_rounded, 
                            color: LeonardoTheme.accent, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            "TOOLS IN USE",
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: LeonardoTheme.inkLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: leonardo.topApps.isEmpty
                            ? Center(
                                child: Text(
                                  "Gathering data...",
                                  style: GoogleFonts.inter(
                                    color: LeonardoTheme.inkLight,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: leonardo.topApps.length,
                                separatorBuilder: (c, i) => Divider(
                                  color: LeonardoTheme.inkLight.withOpacity(0.1),
                                  height: 24,
                                ),
                                itemBuilder: (ctx, index) {
                                  final app = leonardo.topApps[index];
                                  final percentage = leonardo.totalTime > 0
                                      ? ((app[1] as num) / leonardo.totalTime * 100)
                                      : 0.0;
                                  
                                  return Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              LeonardoTheme.accent.withOpacity(0.8),
                                              LeonardoTheme.accent.withOpacity(0.6),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Text(
                                            "${index + 1}",
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              app[0].toString(),
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: percentage / 100,
                                                minHeight: 4,
                                                backgroundColor: Colors.grey.shade200,
                                                valueColor: AlwaysStoppedAnimation(
                                                  LeonardoTheme.accent.withOpacity(0.7),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            "${(app[1] as num).toInt()}s",
                                            style: GoogleFonts.chivoMono(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            "${percentage.toStringAsFixed(0)}%",
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: LeonardoTheme.inkLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Bottom Bar: Stop Button
        if (leonardo.isGeneratingReport)
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: LeonardoTheme.accent,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  "Leonardo is inscribing his observations...",
                  style: GoogleFonts.inter(
                    fontStyle: FontStyle.italic,
                    color: LeonardoTheme.inkLight,
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: LeonardoTheme.ink,
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              onPressed: () => leonardo.stopSession(),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stop_circle_outlined, size: 20),
                  SizedBox(width: 12),
                  Text("END SESSION", style: TextStyle(fontSize: 15, letterSpacing: 1)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // --- AVATAR ---
  Widget _buildRunningAvatar(BuildContext context, LeonardoService leonardo, {double size = 100.0}) {
    
    String asset;
    Color borderColor;

    // Gestione estesa delle emozioni
    switch (leonardo.emotion) {
      case 'happy':
      case 'joy':
        asset = 'assets/happy.png';
        borderColor = LeonardoTheme.success; // Verde
        break;
      case 'angry':
      case 'frustrated':
        asset = 'assets/angry.png'; 
        borderColor = LeonardoTheme.failure; // Rosso
        break;
      case 'worried':
      case 'sad':
        asset = 'assets/worried.png'; // Assicurati di avere questo file
        borderColor = Colors.orange;
        break;
      case 'puzzled':
      case 'neutral':
      default:
        asset = 'assets/leo.png';
        borderColor = LeonardoTheme.accent; // Blu
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.4), // Ombra più forte per vedere il cambio colore
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
        border: Border.all(color: borderColor, width: 4.0), // Bordo colorato
      ),
      child: ClipOval(
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          width: size,
          height: size,
          errorBuilder: (context, error, stackTrace) {
             // Se l'immagine specifica non esiste, torna a Leo ma mantieni il bordo colorato!
             print("⚠️ Immagine mancante per: ${leonardo.emotion} (cercavo $asset)");
             return Image.asset('assets/leo.png', fit: BoxFit.cover);
          },
        ),
      ),
    );
  }

  // Funzione helper per il tempo
  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h}h ${m}m';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}