import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../process_service.dart';
import '../theme.dart';
import '../widgets/glass_card_widget.dart';
import 'dart:math' as math;

class ReportView extends StatefulWidget {
  const ReportView({super.key});

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leonardo = Provider.of<LeonardoService>(context);
    final hasReport = leonardo.finalReport != null && leonardo.finalReport!.isNotEmpty;

    // Animazione di entrata con parallax
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          // Header con statistiche rapide (se report disponibile)
          if (hasReport) _buildQuickStats(leonardo),
          
          if (hasReport) const SizedBox(height: 16),

          // Report principale
          Expanded(
            child: GlassCard(
              padding: EdgeInsets.zero,
              child: Stack(
                children: [
                  // Background gradient animato
                  if (hasReport)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  LeonardoTheme.surface.withOpacity(0.98),
                                  LeonardoTheme.gold.withOpacity(0.03 + 0.02 * math.sin(_shimmerController.value * 2 * math.pi)),
                                  LeonardoTheme.accent.withOpacity(0.02),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // Contenuto del report
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: hasReport 
                        ? _buildMarkdownContent(leonardo.finalReport!) 
                        : _buildEmptyState(),
                  ),
                  
                  // Azioni floating
                  if (hasReport)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Row(
                        children: [
                          _ActionButton(
                            icon: Icons.share_rounded,
                            onTap: () => _shareReport(context, leonardo.finalReport!),
                            tooltip: 'Share',
                          ),
                          const SizedBox(width: 8),
                          _ActionButton(
                            icon: Icons.copy_rounded,
                            onTap: () => _copyReport(context, leonardo.finalReport!),
                            tooltip: 'Copy',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Action button con animazione
          _buildActionButton(leonardo),
        ],
      ),
    );
  }

  Widget _buildQuickStats(LeonardoService leonardo) {
    // ⭐ ESTRAI METRICHE REALI DAL PACCHETTO STATS
    final stats = leonardo.finalStats ?? {};
    
    // Valori reali dal Python (con type safety)
    final score = stats['final_score'] as int? ?? 0;
    final grade = stats['grade'] as String? ?? '?';
    final durationSeconds = stats['duration_seconds'] as int? ?? 0;
    final durationMinutes = (durationSeconds / 60).round();
    
    return Row(
      children: [
        Expanded(
          child: _QuickStatCard(
            label: 'Score',
            value: '$score',
            suffix: '/100',
            color: _getScoreColor(score),
            icon: Icons.analytics_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickStatCard(
            label: 'Grade',
            value: grade,
            suffix: '',
            color: _getGradeColor(grade),
            icon: Icons.star_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickStatCard(
            label: 'Time',
            value: '$durationMinutes',
            suffix: 'min',
            color: LeonardoTheme.accent,
            icon: Icons.timer_rounded,
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return const Color(0xFF2196F3);
    if (score >= 40) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  Color _getGradeColor(String grade) {
    if (grade.startsWith('A')) return const Color(0xFF4CAF50);
    if (grade.startsWith('B')) return const Color(0xFF2196F3);
    if (grade.startsWith('C')) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  Widget _buildMarkdownContent(String data) {
    return Markdown(
      data: data,
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 32),
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        blockSpacing: 20,
        
        // Headers con gerarchia visiva forte
        h1: GoogleFonts.cinzel(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: LeonardoTheme.ink,
          height: 1.3,
          letterSpacing: -0.5,
        ),
        h1Padding: const EdgeInsets.only(bottom: 8, top: 8),
        
        h2: GoogleFonts.cinzel(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: LeonardoTheme.accent,
          height: 1.4,
          letterSpacing: 0.5,
        ),
        h2Padding: const EdgeInsets.only(top: 24, bottom: 12),
        
        h3: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: LeonardoTheme.ink.withOpacity(0.9),
        ),
        
        // Body text ottimizzato per leggibilità
        p: GoogleFonts.inter(
          fontSize: 15,
          height: 1.7,
          color: LeonardoTheme.ink.withOpacity(0.85),
          letterSpacing: 0.2,
        ),
        
        strong: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          color: LeonardoTheme.ink,
        ),
        
        // Liste con migliore spacing
        listBullet: GoogleFonts.inter(
          color: LeonardoTheme.accent,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        listIndent: 24,
        
        // Tabelle stilizzate
        tableHead: GoogleFonts.inter(
          fontWeight: FontWeight.bold,
          color: LeonardoTheme.accent,
          fontSize: 13,
          letterSpacing: 1.2,
        ),
        tableBody: GoogleFonts.inter(
          fontSize: 15,
          color: LeonardoTheme.ink.withOpacity(0.9),
          height: 1.6,
        ),
        tableBorder: TableBorder.all(
          color: LeonardoTheme.ink.withOpacity(0.1),
          width: 1,
        ),
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        
        // Quote Leonardo-style
        blockquote: GoogleFonts.crimsonText(
          color: LeonardoTheme.ink.withOpacity(0.8),
          fontStyle: FontStyle.italic,
          fontSize: 16,
          height: 1.7,
          fontWeight: FontWeight.w500,
        ),
        blockquotePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: LeonardoTheme.gold, width: 4),
          ),
          gradient: LinearGradient(
            colors: [
              LeonardoTheme.gold.withOpacity(0.08),
              LeonardoTheme.gold.withOpacity(0.02),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
        ),
        
        // Code blocks
        code: GoogleFonts.firaCode(
          backgroundColor: Colors.transparent,
          fontSize: 13,
          color: LeonardoTheme.accent,
        ),
        codeblockDecoration: BoxDecoration(
          color: LeonardoTheme.ink.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: LeonardoTheme.ink.withOpacity(0.08), width: 1),
        ),
        codeblockPadding: const EdgeInsets.all(16),
        
        // Horizontal rule
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: LeonardoTheme.gold.withOpacity(0.3),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animazione pulsante
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: LeonardoTheme.gold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.description_outlined,
                size: 56,
                color: LeonardoTheme.gold.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Il Codex è vuoto",
            style: GoogleFonts.cinzel(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: LeonardoTheme.ink.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Completa una sessione per generare il report",
            style: GoogleFonts.inter(
              fontSize: 14,
              color: LeonardoTheme.ink.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(LeonardoService leonardo) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: LeonardoTheme.accent,
            foregroundColor: Colors.white,
            elevation: 12,
            shadowColor: LeonardoTheme.accent.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ).copyWith(
            overlayColor: WidgetStateProperty.all(Colors.white.withOpacity(0.2)),
          ),
          onPressed: () {
            HapticFeedback.mediumImpact();
            leonardo.reset();
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.refresh_rounded, size: 24),
              const SizedBox(width: 12),
              Text(
                "NEW SESSION",
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyReport(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text(
                "Report copied to clipboard",
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: LeonardoTheme.accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _shareReport(BuildContext context, String text) {
    // TODO: Implement share functionality with share_plus package
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Share functionality coming soon",
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: LeonardoTheme.ink,
      ),
    );
  }
}

// Quick Stat Card Widget
class _QuickStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final Color color;
  final IconData icon;

  const _QuickStatCard({
    required this.label,
    required this.value,
    required this.suffix,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: LeonardoTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1,
                ),
              ),
              if (suffix.isNotEmpty)
                Text(
                  suffix,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: LeonardoTheme.ink.withOpacity(0.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: LeonardoTheme.ink.withOpacity(0.6),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Action Button Widget
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _ActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: LeonardoTheme.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: LeonardoTheme.ink.withOpacity(0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 20,
              color: LeonardoTheme.ink.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
}