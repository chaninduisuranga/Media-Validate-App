import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import '../app_theme.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProfileScreen({super.key, required this.userData});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Map<String, dynamic> _currentUser;
  bool _isEditing = false;
  bool _isLoading = false;
  String? _profilePhotoBase64;

  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _passwordController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.userData;
    _profilePhotoBase64 = _currentUser['profile_photo'];
    _phoneController = TextEditingController(
      text: _currentUser['phone_no'] ?? '',
    );
    _addressController = TextEditingController(
      text: _currentUser['address'] ?? '',
    );
    _passwordController = TextEditingController();
    _firstNameController = TextEditingController(
      text: _currentUser['first_name'] ?? '',
    );
    _lastNameController = TextEditingController(
      text: _currentUser['last_name'] ?? '',
    );
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      final bytes = await File(pickedFile.path).readAsBytes();
      setState(() {
        _profilePhotoBase64 = base64Encode(bytes);
      });
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isLoading = true);
    try {
      final updateData = {
        'phone_no': _phoneController.text,
        'address': _addressController.text,
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        'profile_photo': _profilePhotoBase64 ?? '',
      };
      if (_passwordController.text.isNotEmpty) {
        updateData['password'] = _passwordController.text;
      }

      final response = await ApiService.updateUser(
        _currentUser['id'],
        updateData,
      );
      if (response['success']) {
        setState(() {
          _currentUser['phone_no'] = _phoneController.text;
          _currentUser['address'] = _addressController.text;
          _currentUser['first_name'] = _firstNameController.text;
          _currentUser['last_name'] = _lastNameController.text;
          _currentUser['profile_photo'] = _profilePhotoBase64;
          _isEditing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identity parameters updated'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Terminate Identity',
          style: GoogleFonts.outfit(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Are you sure you want to delete your identity profile? This action is irreversible across the network.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abort'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(context);
              _deleteAccount();
            },
            child: const Text('Confirm Deletion'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.deleteUser(_currentUser['id']);
      if (response['success']) {
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deletion failed: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildProfileAvatar() {
    ImageProvider? backgroundImage;
    if (_profilePhotoBase64 != null && _profilePhotoBase64!.isNotEmpty) {
      try {
        backgroundImage = MemoryImage(base64Decode(_profilePhotoBase64!));
      } catch (_) {}
    }

    return Center(
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 64,
              backgroundColor: AppColors.bgSurface,
              backgroundImage: backgroundImage,
              child: backgroundImage == null
                  ? const Icon(
                      Icons.person_rounded,
                      size: 70,
                      color: AppColors.textMuted,
                    )
                  : null,
            ),
          ),
          if (_isEditing)
            Positioned(
              bottom: 4,
              right: 4,
              child: GestureDetector(
                onTap: _pickProfilePhoto,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bgBase, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_a_photo_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        title: Text(
          'Identity Profile',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isEditing ? Icons.close : Icons.edit_note_rounded,
              color: AppColors.primary,
              size: 28,
            ),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_sweep_rounded,
              color: AppColors.danger,
              size: 28,
            ),
            onPressed: _confirmDelete,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProfileAvatar(),
              const SizedBox(height: 12),
              Text(
                '${_currentUser['first_name']} ${_currentUser['last_name']}',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                _currentUser['email'] ?? '',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              _buildSectionTitle('Network Details'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildEditableTile(
                      'First Name',
                      _firstNameController,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildEditableTile('Last Name', _lastNameController),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildEditableTile(
                'Phone Channel',
                _phoneController,
                icon: Icons.phone_iphone_rounded,
              ),
              const SizedBox(height: 20),
              _buildEditableTile(
                'Physical Address',
                _addressController,
                maxLines: 2,
                icon: Icons.map_rounded,
              ),
              const SizedBox(height: 20),
              if (_isEditing)
                _buildEditableTile(
                  'New Secret Key (Optional)',
                  _passwordController,
                  isPassword: true,
                  icon: Icons.key_rounded,
                ),
              if (!_isEditing) _buildMetaInfo(),
              const SizedBox(height: 48),
              if (_isEditing)
                GradientButton(
                  label: 'Commit Changes',
                  isLoading: _isLoading,
                  onPressed: _updateProfile,
                ),
            ],
          ),
        ),
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
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildMetaInfo() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildMetaRow('Identity ID', _currentUser['id'].toString()),
          const Divider(color: AppColors.border, height: 24),
          _buildMetaRow('System Access', 'Validated User'),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildEditableTile(
    String label,
    TextEditingController controller, {
    bool isPassword = false,
    int maxLines = 1,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: _isEditing ? AppColors.primary : AppColors.textSecondary,
              fontWeight: _isEditing ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        TextField(
          controller: controller,
          enabled: _isEditing,
          obscureText: isPassword,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: icon != null ? Icon(icon, size: 20) : null,
            fillColor: _isEditing ? AppColors.bgSurface : Colors.transparent,
            border: _isEditing ? null : InputBorder.none,
            enabledBorder: _isEditing ? null : InputBorder.none,
            focusedBorder: _isEditing ? null : InputBorder.none,
            contentPadding: _isEditing
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
                : EdgeInsets.zero,
          ),
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: _isEditing ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
