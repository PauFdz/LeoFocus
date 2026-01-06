import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'process_service.dart';
import 'report_view.dart';
import 'running_view.dart';
import 'theme.dart';
import 'widgets/glass_card_widget.dart';
import 'dart:ui';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _orbController;
  late AnimationController _fadeController;
  final TextEditingController _roleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _fadeController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leonardo = Provider.of<LeonardoService>(context);

    return Scaffold(
      body: Stack(
        children: [
          // Animated Background
          AnimatedBuilder(
            animation: _orbController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: -150 + (50 * _orbController.value),
                    right: -100,
                    child: _buildOrb(450, LeonardoTheme.accent.withOpacity(0.08)),
                  ),
                  Positioned(
                    bottom: -100 + (30 * (1 - _orbController.value)),
                    left: -80,
                    child: _buildOrb(380, LeonardoTheme.gold.withOpacity(0.06)),
                  ),
                ],
              );
            },
          ),
          
          // Main Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeController,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24),
                    child: Column(
                      children: [
                        _buildHeader(context, leonardo),
                        const SizedBox(height: 32),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.02),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            // QUI GESTIAMO TUTTI GLI STATI
                            child: _buildCurrentState(context, leonardo),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }

Widget _buildHeader(BuildContext context, LeonardoService leonardo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center, 
      children: [
        Text(
          "LeoFocus", 
          style: GoogleFonts.italianno(
            fontSize: 96, 
            fontWeight: FontWeight.w500,
            color: LeonardoTheme.ink,
            // 1. MODIFICA FONDAMENTALE: height < 1.0 "mangia" lo spazio vuoto
            height: 0.8, 
          ),
          textAlign: TextAlign.center,
        ),
        
        // 2. Rimuovi o commenta il SizedBox se vuoi che siano appiccicati
        // const SizedBox(height: 4), 
        
        // Se vuoi sovrapporli leggermente o avvicinarli ancora di più, 
        // puoi usare Transform.translate per tirare su il sottotitolo:
        Transform.translate(
          offset: const Offset(0, -10), // Valore negativo per salire (es. -10, -15)
          child: Text(
            _getLeonardoSubtitle(leonardo),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: LeonardoTheme.inkLight,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
  // 2. AGGIUNGI QUESTA VISTA "PONTE"
  Widget _buildLoadingAdviceView(BuildContext context, LeonardoService leonardo) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Avatar che pulsa o fisso
        _buildLeonardoAvatar(leonardo, size: 120),
        const SizedBox(height: 48),
        
        GlassCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: LeonardoTheme.accent,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Leonardo is contemplating your task...",
                style: GoogleFonts.cinzel(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: LeonardoTheme.ink,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Preparing wisdom for a ${leonardo.currentContext}...",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: LeonardoTheme.inkLight,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // LOGICA DI NAVIGAZIONE PRINCIPALE
  Widget _buildCurrentState(BuildContext context, LeonardoService leonardo) {
    if (leonardo.finalReport != null) {
      return const ReportView(); 
    } 
    // NUOVO STATO: Consigli Iniziali
    else if (leonardo.initialAdvice != null && !leonardo.isAdviceAcknowledged) {
      return _buildAdviceView(context, leonardo);
    }
    else if (leonardo.isWaitingForAdvice) {
      return _buildLoadingAdviceView(context, leonardo);
    } 
    else if (leonardo.isRunning || leonardo.isGeneratingReport) {
      return const RunningView(); 
    } else {
      return _buildSetupView(context, leonardo);
    }
  }

  // --- 1. SETUP VIEW (Inserimento Ruolo) ---
  Widget _buildSetupView(BuildContext context, LeonardoService leonardo) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLeonardoAvatar(leonardo, size: 140),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.zero,
                          topRight: Radius.circular(24),
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 15,
                            offset: const Offset(4, 4),
                          ),
                        ],
                        border: Border.all(color: LeonardoTheme.inkLight.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Salve, curious mind!",
                            style: GoogleFonts.cinzel(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: LeonardoTheme.accent,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Tell me of your endeavor today. What craft shall you pursue?\n\nI shall observe your focus and offer you my wisdom.",
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              height: 1.5,
                              color: LeonardoTheme.ink,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 48),

            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: GlassCard(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    TextField(
                      controller: _roleController,
                      style: GoogleFonts.inter(fontSize: 16, color: LeonardoTheme.ink),
                      decoration: InputDecoration(
                        hintText: "e.g., Studying Calculus, Coding a Flutter app...",
                        prefixIcon: const Icon(Icons.psychology_outlined),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.5),
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          leonardo.startSession(value);
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LeonardoTheme.accent,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                        onPressed: () {
                          if (_roleController.text.isNotEmpty) {
                            leonardo.startSession(_roleController.text);
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("CONSULT LEONARDO", style: TextStyle(fontSize: 15, letterSpacing: 1)),
                            const SizedBox(width: 12),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. ADVICE VIEW (Nuova vista consigli) ---
  Widget _buildAdviceView(BuildContext context, LeonardoService leonardo) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLeonardoAvatar(leonardo, size: 120),
        const SizedBox(height: 32),
        
        Expanded(
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: LeonardoTheme.accent.withOpacity(0.1),
                    border: Border(bottom: BorderSide(color: LeonardoTheme.accent.withOpacity(0.1))),
                  ),
                  child: Text(
                    "LEONARDO'S PRECEPTS",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cinzel(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: LeonardoTheme.accent,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: MarkdownBody(
                        data: leonardo.initialAdvice ?? "Consulting the codex...",
                        styleSheet: MarkdownStyleSheet(
                          p: GoogleFonts.inter(
                            fontSize: 18,
                            height: 1.6,
                            color: LeonardoTheme.ink,
                          ),
                          listBullet: TextStyle(
                            color: LeonardoTheme.accent,
                            fontSize: 18,
                          ),
                          strong: TextStyle(
                            color: LeonardoTheme.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: LeonardoTheme.accent,
              padding: const EdgeInsets.symmetric(vertical: 20),
              elevation: 4,
              shadowColor: LeonardoTheme.accent.withOpacity(0.4),
            ),
            onPressed: () => leonardo.acknowledgeAdvice(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("I SHALL FOLLOW THY COUNSEL", 
                  style: TextStyle(fontSize: 15, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                const Icon(Icons.check_circle_outline, size: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // UTILITY
  Widget _buildLeonardoAvatar(LeonardoService leonardo, {double size = 100.0}) {
    Color statusColor;
    String assetImage = 'assets/leo.png';
    
    if (leonardo.finalReport != null) {
      statusColor = LeonardoTheme.success;
    } else if (leonardo.initialAdvice != null && !leonardo.isAdviceAcknowledged) {
      statusColor = LeonardoTheme.gold; // Colore oro quando dà consigli
    } else if (leonardo.isRunning) {
      statusColor = LeonardoTheme.accent;
    } else {
      statusColor = LeonardoTheme.inkLight;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: statusColor, width: 3.0),
      ),
      child: Center(
        child: ClipOval( 
          child: Image.asset(
            assetImage,
            fit: BoxFit.cover, 
            width: size,
            height: size,
          ),
        ),
      ),
    );
  }

  String _getLeonardoSubtitle(LeonardoService leonardo) {
    if (leonardo.finalReport != null) {
      return "Your Renaissance mentor has spoken";
    } else if (leonardo.initialAdvice != null && !leonardo.isAdviceAcknowledged) {
      return "Wisdom for the task ahead";
    } else if (leonardo.isGeneratingReport) {
      return "Composing your codex entry...";
    } else if (leonardo.isRunning) {
      return "Observing your craft with keen eyes";
    } else {
      return "Your Renaissance mentor awaits";
    }
  }
}