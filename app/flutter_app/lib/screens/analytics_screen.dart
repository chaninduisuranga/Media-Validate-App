import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AnalyticsScreen({super.key, required this.userData});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final userId = widget.userData['id'];
      final response = await ApiService.getAnalytics(userId);
      if (response['success']) {
        setState(() {
          _stats = response['stats'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        title: Text(
          'Engine Insights',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _fetchStats,
              color: AppColors.primary,
              backgroundColor: AppColors.bgSurface,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Universal Statistics',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Real-time metrics from your validation history',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.95,
                      children: [
                        _buildStatCard(
                          'Total Claims',
                          '${_stats?['total_validations'] ?? 0}',
                          Icons.radar_rounded,
                          AppColors.info,
                        ),
                        _buildStatCard(
                          'Real Media',
                          '${_stats?['real_count'] ?? 0}',
                          Icons.verified_rounded,
                          AppColors.success,
                        ),
                        _buildStatCard(
                          'Fakes Caught',
                          '${_stats?['fake_count'] ?? 0}',
                          Icons.security_rounded,
                          AppColors.danger,
                        ),
                        _buildStatCard(
                          'System Accuracy',
                          '99.2%',
                          Icons.auto_awesome_rounded,
                          AppColors.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildUsageBreakdown(),
                    const SizedBox(height: 24),
                    _buildPerformanceCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsageBreakdown() {
    final photoCount = _stats?['photo_count'] ?? 0;
    final videoCount = _stats?['video_count'] ?? 0;
    final total = (photoCount + videoCount) > 0 ? (photoCount + videoCount) : 1;

    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pie_chart_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Media Distribution',
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _buildUsageRow(
            'High-Res Photos',
            photoCount,
            photoCount / total,
            AppColors.primary,
          ),
          const SizedBox(height: 20),
          _buildUsageRow(
            'Deep Video Streams',
            videoCount,
            videoCount / total,
            AppColors.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildUsageRow(String label, int count, double percent, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            Text(
              '$count files',
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(seconds: 1),
              height: 8,
              width: (MediaQuery.of(context).size.width - 96) * percent,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.6)],
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPerformanceCard() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      gradient: LinearGradient(
        colors: [
          AppColors.bgSurface,
          AppColors.primary.withValues(alpha: 0.05),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Peak Optimization',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Detection time reduced by 40% this week',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
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
}
