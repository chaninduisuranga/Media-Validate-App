import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/history_screen.dart';
import 'screens/detection_guide_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'app_theme.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MediaValidatorApp());
}

class MediaValidatorApp extends StatelessWidget {
  const MediaValidatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Media Validater',
      theme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}

// ─── Main shell with bottom navigation ───────────────────────────────────────

class MainShell extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const MainShell({super.key, this.userData});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(userData: widget.userData),
      AnalyticsScreen(userData: widget.userData!),
      HistoryScreen(userData: widget.userData),
      ProfileScreen(userData: widget.userData!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    final items = [
      _NavItem(icon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.bar_chart_rounded, label: 'Analytics'),
      _NavItem(icon: Icons.history_rounded, label: 'History'),
      _NavItem(icon: Icons.person_rounded, label: 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final isActive = i == _currentIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _currentIndex = i),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          items[i].icon,
                          size: 26,
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].label,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isActive
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
}

// ─── Home Screen ──────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const HomeScreen({super.key, this.userData});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _selectedFile;
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickMedia(ImageSource source, {bool isVideo = false}) async {
    XFile? pickedFile;
    if (isVideo) {
      pickedFile = await _picker.pickVideo(source: source);
    } else {
      pickedFile = await _picker.pickImage(source: source);
    }

    if (pickedFile != null) {
      setState(() {
        _selectedFile = File(pickedFile!.path);
        _result = null;
      });
    }
  }

  Future<void> _validateMedia() async {
    if (_selectedFile == null) return;

    setState(() {
      _isLoading = true;
      _result = null;
    });

    try {
      final response = await ApiService.validateMedia(
        _selectedFile!,
        widget.userData?['id'],
      );
      setState(() {
        _result = response;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(color: AppColors.bgBase)),
          // Abstract background decoration
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  _buildTopBar(),
                  const SizedBox(height: 30),
                  Text(
                    'Media Authenticity',
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Instant media authenticity verification',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  Expanded(child: _buildUploadZone()),
                  const SizedBox(height: 30),
                  if (_result != null) _buildResultCard(),
                  const SizedBox(height: 20),
                  if (_selectedFile != null && _result == null)
                    GradientButton(
                      label: 'Verify Content',
                      isLoading: _isLoading,
                      onPressed: _validateMedia,
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                color: AppColors.secondary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'PRO ENGINE',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUploadZone() {
    return GestureDetector(
      onTap: () => _showPickerOptions(),
      child: AppCard(
        padding: EdgeInsets.zero,
        borderColor: _selectedFile == null
            ? AppColors.border
            : AppColors.primary,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _selectedFile == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_upload_outlined,
                        size: 48,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Ready to inspect',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to upload Image or Video',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    _selectedFile!.path.endsWith('.mp4') ||
                            _selectedFile!.path.endsWith('.mov')
                        ? Container(
                            color: AppColors.bgElevated,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.movie_creation_outlined,
                                  size: 64,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Text(
                                    _selectedFile!.path.split('/').last,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Image.file(_selectedFile!, fit: BoxFit.cover),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedFile = null;
                          _result = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.bgBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          _buildDrawerHeader(),
          const SizedBox(height: 15),
          _buildDrawerItem(Icons.help_outline_rounded, 'Detection Guide', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DetectionGuideScreen()),
            );
          }),
          _buildDrawerItem(Icons.privacy_tip_outlined, 'Privacy Policy', () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            );
          }),
          _buildDrawerItem(
            Icons.star_outline_rounded,
            'Support with Rating',
            () {
              Navigator.pop(context);
              _showRatingDialog(context);
            },
          ),
          _buildDrawerItem(Icons.share_outlined, 'Share Us', () {
            Navigator.pop(context);
            _showShareDialog(context);
          }),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: AppCard(
              padding: const EdgeInsets.symmetric(vertical: 0),
              radius: 14,
              borderColor: AppColors.danger.withValues(alpha: 0.3),
              child: ListTile(
                onTap: () {
                  Navigator.pop(context);
                  _showLogoutDialog();
                },
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.danger,
                ),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Logout',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Ready to leave? Your scan history is saved.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    final firstName = widget.userData?['first_name'] ?? 'Guest';
    final lastName = widget.userData?['last_name'] ?? '';
    final userEmail = widget.userData?['email'] ?? '';
    final profilePhoto = widget.userData?['profile_photo'] as String?;

    ImageProvider? avatarImage;
    if (profilePhoto != null && profilePhoto.isNotEmpty) {
      try {
        avatarImage = MemoryImage(base64Decode(profilePhoto));
      } catch (_) {}
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: AppColors.primary,
            backgroundImage: avatarImage,
            child: avatarImage == null
                ? const Icon(Icons.person, color: Colors.white, size: 35)
                : null,
          ),
          const SizedBox(height: 20),
          Text(
            '$firstName $lastName',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            userEmail,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 22),
      title: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 15,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }

  void _showShareDialog(BuildContext context) {
    const appLink = 'https://mediavalidator.app';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Promote Authenticity',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.verified_user_rounded,
              color: AppColors.secondary,
              size: 50,
            ),
            const SizedBox(height: 16),
            Text(
              'Help others verify digital content. Share the pro validator link.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      appLink,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: appLink));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied link to clipboard'),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context) {
    int selectedStars = 0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Improve the Engine',
            style: GoogleFonts.outfit(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How accurate was our analysis?',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedStars ? Icons.star : Icons.star_border,
                      color: AppColors.warning,
                      size: 36,
                    ),
                    onPressed: () => setState(() => selectedStars = index + 1),
                  );
                }),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  hintText: 'Share your feedback...',
                  fillColor: AppColors.bgElevated,
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedStars == 0
                  ? null
                  : () async {
                      final userId = widget.userData?['id'];
                      if (userId != null) {
                        await ApiService.submitRating({
                          'user_id': userId,
                          'rating': selectedStars,
                          'comment': commentController.text,
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Feedback received. Thank you!'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final pred = _result!['prediction']?.toString().toLowerCase() ?? 'edited';
    final isReal = pred == 'real';
    final isSuspicious = pred == 'suspicious';

    Color color = AppColors.danger;
    String label = 'DETECTION ALERT';
    IconData icon = Icons.warning_amber_rounded;

    if (isReal) {
      color = AppColors.success;
      label = 'VERIFIED REAL';
      icon = Icons.verified;
    } else if (isSuspicious) {
      color = AppColors.warning;
      label = 'SUSPICIOUS SIGNAL';
      icon = Icons.plagiarism;
    }

    return AppCard(
      padding: const EdgeInsets.all(24),
      borderColor: color.withValues(alpha: 0.4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Inference Confidence',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${_result!['confidence']}%',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: (_result!['confidence'] as num) / 100,
              backgroundColor: color.withValues(alpha: 0.1),
              color: color,
              minHeight: 10,
            ),
          ),
          if (_result!['go_results'] != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'STRUCTURAL PIPELINE',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textMuted,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...((_result!['go_results'] as List).take(3).map((res) {
              final status = res['status'];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      status == 'REAL' ? Icons.check_circle : Icons.error,
                      size: 14,
                      color: status == 'REAL' ? AppColors.success : color,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${res['method']}: ${res['details']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList()),
          ],
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => setState(() {
              _selectedFile = null;
              _result = null;
            }),
            child: const Text(
              'Reset Scanner',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select Media Type',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildPickerOption(
                    Icons.image_rounded,
                    'Image',
                    AppColors.primary,
                    () {
                      Navigator.pop(context);
                      _pickMedia(ImageSource.gallery);
                    },
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildPickerOption(
                    Icons.videocam_rounded,
                    'Video',
                    AppColors.secondary,
                    () {
                      Navigator.pop(context);
                      _pickMedia(ImageSource.gallery, isVideo: true);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        borderColor: color.withValues(alpha: 0.2),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
