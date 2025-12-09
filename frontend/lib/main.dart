import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';
import 'process_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LeonardoService()),
      ],
      child: const LeonardoApp(),
    ),
  );
}

class LeonardoApp extends StatelessWidget {
  const LeonardoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leonardo',
      theme: LeonardoTheme.themeData,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _orbController;
  late AnimationController _fadeController;

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
    return Row(
      children: [
        // Leonardo Avatar con stato
        _buildLeonardoAvatar(leonardo),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "LEONARDO",
                style: GoogleFonts.cinzel(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: LeonardoTheme.ink,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getLeonardoSubtitle(leonardo),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: LeonardoTheme.inkLight,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        if (leonardo.isRunning && !leonardo.isGeneratingReport)
          _buildQuickStats(leonardo),
      ],
    );
  }

  Widget _buildLeonardoAvatar(LeonardoService leonardo) {
    Color statusColor;
    IconData statusIcon;
    
    if (leonardo.finalReport != null) {
      statusColor = LeonardoTheme.success;
      statusIcon = Icons.check_circle;
    } else if (leonardo.isRunning || leonardo.isGeneratingReport) {
      statusColor = LeonardoTheme.accent;
      statusIcon = Icons.visibility;
    } else {
      statusColor = LeonardoTheme.inkLight;
      statusIcon = Icons.edit_note;
    }

    return Container(
      width: 56,
      height: 56,
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
        border: Border.all(color: statusColor, width: 2.5),
      ),
      child: Stack(
        children: [
          Center(
            child: ClipOval( 
              child: Image.asset(
                'assets/leo.png', // <-- Il percorso del tuo file PNG
                fit: BoxFit.cover, 
                width: 200,      // Assicurati che le dimensioni siano coerenti 
                height: 200,     // con il Container genitore se necessario.
              ),
            ),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(statusIcon, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(LeonardoService leonardo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: LeonardoTheme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LeonardoTheme.accent.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 16, color: LeonardoTheme.accent),
          const SizedBox(width: 8),
          Text(
            _formatTime(leonardo.totalTime),
            style: GoogleFonts.chivoMono(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: LeonardoTheme.accent,
            ),
          ),
        ],
      ),
    );
  }

  String _getLeonardoSubtitle(LeonardoService leonardo) {
    if (leonardo.finalReport != null) {
      return "Your Renaissance mentor has spoken";
    } else if (leonardo.isGeneratingReport) {
      return "Composing your codex entry...";
    } else if (leonardo.isRunning) {
      return "Observing your craft with keen eyes";
    } else {
      return "Your Renaissance mentor awaits";
    }
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h}h ${m}m';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildCurrentState(BuildContext context, LeonardoService leonardo) {
    if (leonardo.finalReport != null) {
      return _buildReportView(context, leonardo);
    } else if (leonardo.isRunning || leonardo.isGeneratingReport) {
      return _buildRunningView(context, leonardo);
    } else {
      return _buildSetupView(context, leonardo);
    }
  }

  // SETUP VIEW
  Widget _buildSetupView(BuildContext context, LeonardoService leonardo) {
    final TextEditingController roleController = TextEditingController();
    
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLeonardoMessage(
              "Salve, curious mind!",
              "Tell me of your endeavor today. What craft shall you pursue? "
              "I shall observe your focus and offer wisdom from the Renaissance.",
            ),
            const SizedBox(height: 48),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: GlassCard(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    TextField(
                      controller: roleController,
                      style: GoogleFonts.inter(fontSize: 16, color: LeonardoTheme.ink),
                      decoration: InputDecoration(
                        hintText: "e.g., Studying Calculus, Coding a Flutter app...",
                        prefixIcon: const Icon(Icons.psychology_outlined),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.5),
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) leonardo.startSession(value);
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
                          if (roleController.text.isNotEmpty) {
                            leonardo.startSession(roleController.text);
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("BEGIN SESSION", style: TextStyle(fontSize: 15, letterSpacing: 1)),
                            const SizedBox(width: 12),
                            Icon(Icons.arrow_forward_rounded, size: 20),
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

  // RUNNING VIEW
  Widget _buildRunningView(BuildContext context, LeonardoService leonardo) {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Column: Timer + Active Window
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Expanded(
                      child: GlassCard(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.hourglass_empty_rounded, 
                              size: 48, 
                              color: LeonardoTheme.accent.withOpacity(0.6)),
                            const SizedBox(height: 24),
                            Text(
                              _formatTime(leonardo.totalTime),
                              style: GoogleFonts.chivoMono(
                                fontSize: 64,
                                fontWeight: FontWeight.w300,
                                color: LeonardoTheme.ink,
                                letterSpacing: -2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "SESSION DURATION",
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.5,
                                color: LeonardoTheme.inkLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: LeonardoTheme.accent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.window_rounded, 
                              color: LeonardoTheme.accent, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "CURRENT FOCUS",
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: LeonardoTheme.inkLight,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  leonardo.activeWindow,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: LeonardoTheme.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                          Icon(Icons.apps_rounded, 
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
        
        if (leonardo.isGeneratingReport)
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stop_circle_outlined, size: 20),
                  const SizedBox(width: 12),
                  const Text("END SESSION", style: TextStyle(fontSize: 15, letterSpacing: 1)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // REPORT VIEW
  Widget _buildReportView(BuildContext context, LeonardoService leonardo) {
    return Column(
      children: [
        Expanded(
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.95),
                        LeonardoTheme.gold.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Markdown(
                    data: leonardo.finalReport!,
                    padding: const EdgeInsets.all(48),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    styleSheet: MarkdownStyleSheet(
                      h1: GoogleFonts.cinzel(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: LeonardoTheme.ink,
                      ),
                      h2: GoogleFonts.cinzel(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: LeonardoTheme.accent,
                        height: 1.5,
                      ),
                      p: GoogleFonts.inter(
                        fontSize: 16,
                        height: 1.7,
                        color: LeonardoTheme.ink.withOpacity(0.85),
                      ),
                      listBullet: TextStyle(color: LeonardoTheme.accent),
                      blockquote: GoogleFonts.inter(
                        color: LeonardoTheme.inkLight,
                        fontStyle: FontStyle.italic,
                        fontSize: 15,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: LeonardoTheme.gold, width: 4),
                        ),
                        color: LeonardoTheme.gold.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: LeonardoTheme.accent,
              padding: const EdgeInsets.symmetric(vertical: 20),
            ),
            onPressed: () => leonardo.reset(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh_rounded, size: 20),
                const SizedBox(width: 12),
                const Text("NEW SESSION", style: TextStyle(fontSize: 15, letterSpacing: 1)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeonardoMessage(String title, String message) {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [LeonardoTheme.accent, LeonardoTheme.accent],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.auto_stories_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.cinzel(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: LeonardoTheme.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.6,
              color: LeonardoTheme.inkLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Glass Card Widget
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(32),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}