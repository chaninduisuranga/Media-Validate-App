import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

class DetectionGuideScreen extends StatelessWidget {
  const DetectionGuideScreen({super.key});

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
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Supported Content'),
                  const SizedBox(height: 16),
                  _buildFileTypesRow(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Understanding Verdicts'),
                  const SizedBox(height: 16),
                  _buildResultCard(
                    label: 'VERIFIED REAL',
                    icon: Icons.verified_rounded,
                    color: AppColors.success,
                    description:
                        'Negative detection for manipulation. Metadata integrity is confirmed and neural analysis confirms authentic pixel density.',
                  ),
                  const SizedBox(height: 16),
                  _buildResultCard(
                    label: 'SUSPICIOUS',
                    icon: Icons.plagiarism_outlined,
                    color: AppColors.warning,
                    description:
                        'Inconsistencies detected. File may have been re-encoded, screenshotted, or contains moderate editing artefacts.',
                  ),
                  const SizedBox(height: 16),
                  _buildResultCard(
                    label: 'DEEPFAKE DETECTED',
                    icon: Icons.gpp_bad_rounded,
                    color: AppColors.danger,
                    description:
                        'Synthetic content identified. AI models have detected generative facial patterns or structural pixel anomalies.',
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Optimization Tips'),
                  const SizedBox(height: 16),
                  _buildTipsGrid(),
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
        'Operational Guide',
        style: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AppCard(
      padding: const EdgeInsets.all(24),
      borderColor: AppColors.secondary.withValues(alpha: 0.3),
      child: Row(
        children: [
          const Icon(
            Icons.psychology_rounded,
            color: AppColors.secondary,
            size: 40,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expert Analysis',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Learn how to interpret raw engine data for peak accuracy.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
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

  Widget _buildFileTypesRow() {
    final types = [
      {'ext': 'JPG', 'color': AppColors.primary},
      {'ext': 'PNG', 'color': AppColors.info},
      {'ext': 'WEBP', 'color': AppColors.success},
      {'ext': 'MP4', 'color': AppColors.warning},
      {'ext': 'MOV', 'color': AppColors.danger},
    ];
    return Row(
      children: types.map((t) {
        final color = t['color'] as Color;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                t['ext'] as String,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResultCard({
    required String label,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      borderColor: color.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipsGrid() {
    final tips = [
      {
        'icon': Icons.high_quality_rounded,
        'tip': 'Use unformatted originals only',
      },
      {'icon': Icons.camera_rounded, 'tip': 'Avoid social media screenshots'},
      {
        'icon': Icons.timelapse_rounded,
        'tip': 'Videos must exceed 1.5 seconds',
      },
      {
        'icon': Icons.wifi_tethering_rounded,
        'tip': 'Connect to high-speed uplink',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3,
      ),
      itemCount: tips.length,
      itemBuilder: (context, index) {
        return AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                tips[index]['icon'] as IconData,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(height: 12),
              Text(
                tips[index]['tip'] as String,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
