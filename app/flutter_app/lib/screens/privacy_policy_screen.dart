import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
                  _buildLastUpdated(),
                  const SizedBox(height: 40),
                  _buildSection(
                    icon: Icons.shield_rounded,
                    color: AppColors.primary,
                    title: 'Media Protection Strategy',
                    body:
                        'All uploads are processed via transient memory pipelines. Content is analyzed for authenticity markers and immediately purged. We do not maintain a permanent media cloud storage of your private files.',
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    icon: Icons.fingerprint_rounded,
                    color: AppColors.secondary,
                    title: 'Identity Cryptography',
                    body:
                        'Your profile credentials and "Secret Key" are secured using industry-standard hashing protocols. We utilize Supabase encrypted tunnels for all data transit.',
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    icon: Icons.visibility_off_rounded,
                    color: AppColors.success,
                    title: 'Zero Third-Party Exposure',
                    body:
                        'We do not sell, leak, or share your usage patterns, identity parameters, or validation results with external advertisement networks or data brokers.',
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    icon: Icons.delete_forever_rounded,
                    color: AppColors.danger,
                    title: 'Identity Termination',
                    body:
                        'At any point, you may initiate a full "Identity Termination" from your profile. This results in the absolute removal of all database records associated with your account.',
                  ),
                  const SizedBox(height: 48),
                  _buildContactHub(),
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
        'Policy Protocol',
        style: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildLastUpdated() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.update_rounded, color: AppColors.primary, size: 16),
          const SizedBox(width: 10),
          Text(
            'Revision: 01 JUNE 2026',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactHub() {
    return AppCard(
      padding: const EdgeInsets.all(32),
      gradient: LinearGradient(
        colors: [AppColors.bgSurface, AppColors.bgElevated],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.contact_support_rounded,
            color: AppColors.secondary,
            size: 36,
          ),
          const SizedBox(height: 20),
          Text(
            'Operational Queries?',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'For technical enquiries regarding the Privacy Protocol, reach out through the official encrypted channels.',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
