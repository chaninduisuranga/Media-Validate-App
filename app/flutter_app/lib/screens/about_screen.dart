import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroCard(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Mission Objective'),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    icon: Icons.shield_rounded,
                    color: AppColors.primary,
                    title: 'Media Authenticity Protocol',
                    body:
                        'Media Validator is a high-fidelity intelligence tool designed to detect digital manipulation, synthetically altered content, and sophisticated deepfakes across the global web.',
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('The Architecture'),
                  const SizedBox(height: 16),
                  _buildStep(
                    number: '01',
                    color: AppColors.primary,
                    title: 'Go Structural Validation',
                    body:
                        'A lightning-fast inspection layer that analyzes metadata integrity, compression clusters, and pixel consistency in real-time.',
                  ),
                  const SizedBox(height: 16),
                  _buildStep(
                    number: '02',
                    color: AppColors.secondary,
                    title: 'AI Neural Inference',
                    body:
                        'Powered by EfficientNetB0, our models are trained to identify the invisible temporal and spatial artefacts unique to AI generation.',
                  ),
                  const SizedBox(height: 16),
                  _buildStep(
                    number: '03',
                    color: AppColors.success,
                    title: 'Unified Verdict',
                    body:
                        'Both pipelines converge to provide a definitive confidence score and authenticity classification for your media.',
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Technology Integration'),
                  const SizedBox(height: 20),
                  _buildTechGrid(),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: AppColors.bgDeep,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.textSecondary,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Engine specs',
        style: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return AppCard(
      padding: const EdgeInsets.all(32),
      gradient: AppColors.gradientHero,
      radius: 24,
      borderColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_rounded,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 24),
          Text(
            'Media Validator',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Advanced Content Authenticity Intelligence\nVersion 1.2.0 Stable Build',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: AppColors.textMuted,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      borderColor: color.withValues(alpha: 0.2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required String number,
    required Color color,
    required String title,
    required String body,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                number,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: color,
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
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechGrid() {
    final techs = [
      {
        'label': 'Flutter',
        'icon': Icons.phone_android_rounded,
        'color': AppColors.info,
      },
      {
        'label': 'Go Fast',
        'icon': Icons.bolt_rounded,
        'color': AppColors.secondary,
      },
      {
        'label': 'FastAPI',
        'icon': Icons.api_rounded,
        'color': AppColors.success,
      },
      {
        'label': 'EfficientNet',
        'icon': Icons.psychology_rounded,
        'color': AppColors.primary,
      },
      {
        'label': 'Supabase',
        'icon': Icons.storage_rounded,
        'color': AppColors.success,
      },
      {
        'label': 'Postgres',
        'icon': Icons.data_usage_rounded,
        'color': AppColors.info,
      },
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.9,
      children: techs.map((t) {
        final color = t['color'] as Color;
        return AppCard(
          padding: EdgeInsets.zero,
          borderColor: color.withValues(alpha: 0.2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(t['icon'] as IconData, color: color, size: 28),
              const SizedBox(height: 12),
              Text(
                t['label'] as String,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
