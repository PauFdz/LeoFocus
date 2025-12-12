import '../process_service.dart';
import '../theme.dart';
import '../widgets/glass_card_widget.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ReportView extends StatelessWidget {
  const ReportView({super.key});

  @override
  Widget build(BuildContext context) {
    final leonardo = Provider.of<LeonardoService>(context);

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
                        LeonardoTheme.surface.withOpacity(0.95),
                        LeonardoTheme.gold.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Markdown(
                    data: leonardo.finalReport ?? "No report generated.",
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
                      listBullet: const TextStyle(color: LeonardoTheme.accent),
                      blockquote: GoogleFonts.inter(
                        color: LeonardoTheme.inkLight,
                        fontStyle: FontStyle.italic,
                        fontSize: 15,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        border: const Border(
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
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh_rounded, size: 20),
                SizedBox(width: 12),
                Text("NEW SESSION", style: TextStyle(fontSize: 15, letterSpacing: 1)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}