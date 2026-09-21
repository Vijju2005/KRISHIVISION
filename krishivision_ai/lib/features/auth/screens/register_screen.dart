import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _otpVerified = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _showOtpDialog(VoidCallback onOtpComplete) {
    final otpCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Verify Phone Number', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the 4-digit OTP code sent to your phone number for validation.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '0000',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (otpCtrl.text == '1234' || otpCtrl.text.length == 4) {
                  Navigator.pop(context);
                  onOtpComplete();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid code! Enter any 4 digit code e.g. 1234.')),
                  );
                }
              },
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (!_otpVerified) {
      _showOtpDialog(() {
        setState(() {
          _otpVerified = true;
        });
        _completeRegistration();
      });
    } else {
      _completeRegistration();
    }
  }

  void _completeRegistration() async {
    final success = await ref.read(authProvider.notifier).register(
          _nameCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _phoneCtrl.text.trim(),
          _passCtrl.text.trim(),
        );

    if (mounted) {
      if (success) {
        context.go('/home');
      } else {
        final error = ref.read(authProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Registration failed'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: Stack(
        children: [
          // Leaf background decorations at top-left and top-right (stylized vectors)
          Positioned(
            top: -20,
            left: -20,
            child: Icon(
              Icons.eco_rounded,
              size: 100,
              color: AppColors.primary.withOpacity(0.06),
            ),
          ),
          Positioned(
            top: 60,
            right: -10,
            child: Icon(
              Icons.spa_rounded,
              size: 80,
              color: AppColors.primary.withOpacity(0.04),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Agriculture satellite branding header
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: Image.asset(
                                'assets/app_logo.png',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Join KrishiVision',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Set up satellite farm monitoring',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Full Name Input
                        TextFormField(
                          controller: _nameCtrl,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primaryDark),
                            hintText: 'Enter full name',
                            labelText: 'Full Name',
                            labelStyle: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppColors.primaryDark, width: 2.0),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppColors.border),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Full Name is required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Phone Number Input
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.phone_android_rounded, color: AppColors.primaryDark),
                            hintText: 'Enter mobile number',
                            labelText: 'Mobile Number',
                            labelStyle: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppColors.primaryDark, width: 2.0),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppColors.border),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Mobile number is required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Email Address Input
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryDark),
                            hintText: 'Enter email address',
                            labelText: 'Email Address',
                            labelStyle: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppColors.primaryDark, width: 2.0),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppColors.border),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Email is required';
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val)) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Password Input
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscurePass,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primaryDark),
                            hintText: 'Create password',
                            labelText: 'Password',
                            labelStyle: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppColors.primaryDark, width: 2.0),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppColors.border),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textGrey),
                              onPressed: () => setState(() => _obscurePass = !_obscurePass),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Password is required';
                            if (val.length < 6) return 'Password must be at least 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Confirm Password Input
                        TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscureConfirm,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primaryDark),
                            hintText: 'Confirm password',
                            labelText: 'Confirm Password',
                            labelStyle: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppColors.primaryDark, width: 2.0),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: AppColors.border),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textGrey),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Password confirmation is required';
                            if (val != _passCtrl.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Submit Button
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: state.isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: state.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(_otpVerified ? 'Register' : 'Verify & Register', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Return to Login
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Already have an account? ',
                              style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                            ),
                            GestureDetector(
                              onTap: () => context.pop(),
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  color: AppColors.primaryDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
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
}
