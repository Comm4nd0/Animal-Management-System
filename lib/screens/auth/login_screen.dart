import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/animal_provider.dart';
import '../../utils/app_theme.dart';

/// Login screen shared between web and mobile.
/// On web it renders a wider, centered card layout.
/// On mobile it renders a standard full-width form.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: kIsWeb ? Colors.grey.shade100 : null,
      appBar: kIsWeb
          ? null
          : AppBar(
              title: const Text('Log In'),
            ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: isWide ? 440 : double.infinity,
            margin: EdgeInsets.symmetric(
              horizontal: isWide ? 0 : 24,
              vertical: 24,
            ),
            child: kIsWeb
                ? Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: _buildForm(context),
                    ),
                  )
                : _buildForm(context),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logo and title
          const Icon(Icons.pets, size: 56, color: AppTheme.primaryColor),
          const SizedBox(height: 8),
          Text(
            'Pedigree Manager',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sign in to your account',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 32),

          // Email field
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password field
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _login(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              return null;
            },
          ),
          const SizedBox(height: 8),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password reset coming soon'),
                  ),
                );
              },
              child: Text(
                'Forgot password?',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Login button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Log In'),
            ),
          ),
          const SizedBox(height: 20),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),
          const SizedBox(height: 16),

          // Register link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: TextStyle(color: Colors.grey.shade600),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/register'),
                child: const Text('Create Account'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final api = ApiService();
      final result = await api.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      final provider = context.read<AnimalProvider>();
      provider.setAuthToken(result['token'] as String);

      // Load data after login
      await provider.loadAll();

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged in successfully')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.statusCode == 401
            ? 'Invalid email or password'
            : 'Login failed: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      // If API is unreachable, allow offline login
      Navigator.pushReplacementNamed(context, '/dashboard');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged in (offline mode)')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
