import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // ── Validators ────────────────────────────────────────────

  String? _validateFirstName(String? v) {
    if (v == null || v.trim().isEmpty) return 'First name is required';
    if (v.trim().length < 2) return 'Minimum 2 characters';
    if (!RegExp(r"^[a-zA-Z\s'-]+$").hasMatch(v.trim())) {
      return 'Only letters, spaces, hyphens allowed';
    }
    return null;
  }

  String? _validateLastName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Last name is required';
    if (v.trim().length < 2) return 'Minimum 2 characters';
    if (!RegExp(r"^[a-zA-Z\s'-]+$").hasMatch(v.trim())) {
      return 'Only letters, spaces, hyphens allowed';
    }
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w.+\-]+@[a-zA-Z\d\-]+\.[a-zA-Z]{2,}$')
        .hasMatch(v.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Minimum 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Include at least one uppercase letter';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Include at least one number';
    if (!RegExp(r'[!@#\$&*~%^()_\-+=<>?/]').hasMatch(v)) {
      return 'Include at least one special character';
    }
    return null;
  }

  // Sri Lanka phone: 07X XXXXXXX (10 digits starting with 07)
  // Supports: 070–079 prefixes (all current LK mobile operators)
  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required';
    final cleaned = v.replaceAll(RegExp(r'[\s\-()]'), '');
    // Allow optional +94 country code
    final normalised = cleaned.startsWith('+94')
        ? '0${cleaned.substring(3)}'
        : cleaned.startsWith('94') && cleaned.length == 11
            ? '0${cleaned.substring(2)}'
            : cleaned;
    if (!RegExp(r'^0(7[0-9])\d{7}$').hasMatch(normalised)) {
      return 'Enter a valid LK mobile number (e.g. 077XXXXXXX)';
    }
    return null;
  }

  String? _validateAddress(String? v) {
    if (v == null || v.trim().isEmpty) return 'Address is required';
    if (v.trim().length < 5) return 'Enter a more detailed address';
    return null;
  }

  // ── Submit ────────────────────────────────────────────────

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.signup({
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'phone_no': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
      });

      if (response['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Identity created. Initialize login.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else {
        _showError(response['message'] ?? 'Registration failed');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Ambient glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'Sign Up',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create a new account',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),

                    // ── First & Last Name ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'First Name',
                              prefixIcon:
                                  Icon(Icons.person_outline_rounded, size: 20),
                            ),
                            validator: _validateFirstName,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'Last Name',
                              prefixIcon: Icon(Icons.badge_outlined, size: 20),
                            ),
                            validator: _validateLastName,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Email ──
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        hintText: 'Email',
                        prefixIcon:
                            Icon(Icons.alternate_email_rounded, size: 20),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 20),

                    // ── Password ──
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Icon(Icons.key_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible,
                          ),
                        ),
                      ),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 20),

                    // ── Phone Number ──
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        // Only allow digits, spaces, hyphens, +, ()
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[\d\s\-+()\+]')),
                        LengthLimitingTextInputFormatter(15),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'Phone Number (e.g. 077XXXXXXX)',
                        prefixIcon:
                            Icon(Icons.phone_iphone_rounded, size: 20),
                        helperText:
                            'Sri Lanka mobile: 070 – 079 prefix supported',
                        helperStyle: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: 20),

                    // ── Address ──
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Address',
                        prefixIcon:
                            Icon(Icons.location_on_outlined, size: 20),
                      ),
                      validator: _validateAddress,
                    ),
                    const SizedBox(height: 48),

                    GradientButton(
                      label: 'Sign Up',
                      isLoading: _isLoading,
                      onPressed: _signup,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }
}
