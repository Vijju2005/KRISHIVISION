import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _obscure = true;
  bool _isPhoneLogin = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = 'rameshfarmer@gmail.com';
    _passCtrl.text = 'farmer123';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneCtrl.text.trim();
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final formattedPhone = cleanPhone.startsWith('91') && cleanPhone.length == 12 
        ? '+$cleanPhone' 
        : '+91$cleanPhone';

    final success = await ref.read(authProvider.notifier).requestOtp(formattedPhone);
    if (mounted) {
      if (success) {
        context.push('/otp-verify', extra: formattedPhone);
      } else {
        final error = ref.read(authProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Failed to send OTP code'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).login(
          _emailCtrl.text.trim(),
          _passCtrl.text.trim(),
        );

    if (mounted) {
      if (success) {
        context.go('/home');
      } else {
        final error = ref.read(authProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Login failed'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleGoogleSignIn() async {
    final success = await ref.read(authProvider.notifier).signInWithGoogle();
    if (mounted) {
      if (success) {
        context.go('/home');
      } else {
        final error = ref.read(authProvider).errorMessage;
        if (error != null && error.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  void _handleSocialSignIn(String provider, String email, String name, String id) async {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  provider == 'google'
                      ? const GoogleIcon(size: 30)
                      : const Icon(Icons.facebook, size: 30, color: Color(0xFF1877F2)),
                  const SizedBox(width: 12),
                  Text(
                    provider == 'google' ? 'Sign in with Google' : 'Continue with Facebook',
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Text(name[0], style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                ),
                title: Text(
                  name, 
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                ),
                subtitle: Text(
                  email,
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextGrey : AppColors.textGrey,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded, 
                  size: 16,
                  color: isDark ? Colors.white54 : AppColors.textGrey,
                ),
                onTap: () async {
                  Navigator.pop(context);
                  _triggerSocialAuth(provider, email, name, id);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _triggerSocialAuth(String provider, String email, String name, String id) async {
    final success = await ref.read(authProvider.notifier).loginWithSocial(
          provider: provider,
          email: email,
          fullName: name,
          id: id,
        );

    if (mounted) {
      if (success) {
        context.go('/home');
      } else {
        final error = ref.read(authProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Social Authentication failed'),
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
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'assets/app_logo.png',
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Welcome Back!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Sign in to continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textGrey,
                          ),
                        ),
                        const SizedBox(height: 32),

                        if (_isPhoneLogin) ...[
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.primaryDark),
                              hintText: 'Enter 10-digit mobile number',
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
                              if (val == null || val.isEmpty) return 'Phone number is required';
                              final clean = val.replaceAll(RegExp(r'\D'), '');
                              if (clean.length < 10) return 'Enter a valid 10-digit number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: state.isLoading ? null : _sendOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryDark,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 1,
                              ),
                              child: state.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      'SEND OTP',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                    ),
                            ),
                          ),
                        ] else ...[
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
                              if (!val.contains('@')) return 'Enter a valid email address';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primaryDark),
                              hintText: 'Enter password',
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
                                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textGrey),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Password is required';
                              return null;
                            },
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.push('/forgot-password'),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: state.isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryDark,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 1,
                              ),
                              child: state.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                    )
                                  : const Text(
                                      'LOGIN',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                    ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isPhoneLogin = !_isPhoneLogin;
                            });
                          },
                          child: Text(
                            _isPhoneLogin ? 'Login with Email & Password' : 'Login with Mobile Number & OTP',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        const Text(
                          'or continue with',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                        ),
                        const SizedBox(height: 16),
                        _buildSocialButton(
                          label: 'Continue with Google',
                          iconWidget: const GoogleIcon(),
                          onTap: _handleGoogleSignIn,
                        ),
                        const SizedBox(height: 12),
                        _buildSocialButton(
                          label: 'Continue with Facebook',
                          iconWidget: const Icon(Icons.facebook, size: 24, color: Color(0xFF1877F2)),
                          onTap: () => _handleSocialSignIn('facebook', 'ramesh.facebook@gmail.com', 'Facebook Farmer', 'facebook123'),
                        ),
                        const SizedBox(height: 32),

                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              "New to KrishiVision? ",
                              style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                            ),
                            GestureDetector(
                              onTap: () => context.push('/register'),
                              child: const Text(
                                'Sign Up',
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
          if (state.isLoading)
            Container(
              color: Colors.black.withOpacity(0.55),
              child: Center(
                child: Card(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Authenticating...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required String label,
    required Widget iconWidget,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        foregroundColor: isDark ? Colors.white : AppColors.textDark,
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget,
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class GoogleIcon extends StatelessWidget {
  final double size;
  const GoogleIcon({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: GoogleIconPainter(),
      ),
    );
  }
}

class GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w / 2;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.22
      ..strokeCap = StrokeCap.square;

    final center = Offset(w / 2, h / 2);
    final rect = Rect.fromCircle(center: center, radius: r - paint.strokeWidth / 2);

    // Red sector (top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.5, 2.0, false, paint);

    // Yellow sector (left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -3.9, 1.4, false, paint);

    // Green sector (bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.8, 1.5, false, paint);

    // Blue sector (right & horizontal line)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.9, 1.7, false, paint);

    final linePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    
    // Draw the horizontal bar
    final barRect = Rect.fromLTWH(w / 2, h / 2 - paint.strokeWidth / 2, w / 2, paint.strokeWidth);
    canvas.drawRect(barRect, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
