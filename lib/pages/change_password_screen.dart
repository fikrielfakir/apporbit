import 'package:flutter/material.dart';
import 'package:pos_final/apis/user.dart';
import 'package:pos_final/config.dart';
import '../locale/MyLocalizations.dart';
import '../widgets/custom_text_field.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String token;

  const ChangePasswordScreen({Key? key, required this.token}) : super(key: key);

  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  final User _userApi = User();

  @override
  void initState() {
    super.initState();
    print('[ChangePassword] Screen initialized with token: ${widget.token}');
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    print('[ChangePassword] Screen disposed');
    super.dispose();
  }

  Future<void> _submitForm() async {
    print('[ChangePassword] Submit form triggered');

    if (!_formKey.currentState!.validate()) {
      print('[ChangePassword] Form validation failed');
      return;
    }

    print('[ChangePassword] Form validated successfully');
    print('[ChangePassword] Current password: ${_currentPasswordController.text}');
    print('[ChangePassword] New password: ${_newPasswordController.text}');
    print('[ChangePassword] Confirm password: ${_confirmPasswordController.text}');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      print('[ChangePassword] Calling changePassword API...');
      final result = await _userApi.changePassword(
        token: widget.token,
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      print('[ChangePassword] API Response: $result');

      if (result['success'] == true) {
        print('[ChangePassword] Password changed successfully');
        setState(() {
          _successMessage = result['message'];
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        });
      } else {
        print('[ChangePassword] Password change failed: ${result['error']}');
        setState(() {
          _errorMessage = result['error'];
        });
      }
    } catch (e, stackTrace) {
      print('[ChangePassword] Exception occurred: $e');
      print('[ChangePassword] Stack trace: $stackTrace');
      setState(() {
        _errorMessage = AppLocalizations.of(context).translate('error_occurred_try_again');
      });
    } finally {
      print('[ChangePassword] API call completed');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[ChangePassword] Building widget...');
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('change_password')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_errorMessage != null)
                  Builder(
                    builder: (context) {
                      // Enhanced error logging
                      final errorLog = '''
            [${DateTime.now().toIso8601String()}] [ChangePassword] ERROR DISPLAYED:
            Message: $_errorMessage
            Context: ${context.widget}
            Form State:
            - Current Password: ${_currentPasswordController.text.isNotEmpty ? '*****' : 'empty'}
            - New Password: ${_newPasswordController.text.isNotEmpty ? '*****' : 'empty'}
            - Confirm Password: ${_confirmPasswordController.text.isNotEmpty ? '*****' : 'empty'}
            App State:
            - isLoading: $_isLoading
            - hasSuccess: ${_successMessage != null}
            ''';

                      debugPrint(errorLog);
                      print(errorLog);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).errorColor,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  ),
                if (_successMessage != null)
                  Builder(
                    builder: (context) {
                      // Success logging
                      print('[ChangePassword] SUCCESS: $_successMessage');
                      debugPrint('''
            [${DateTime.now().toIso8601String()}] [ChangePassword] SUCCESS:
            Message: $_successMessage
            Context: ${context.widget}
            ''');

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  ),
                CustomTextField(
                  controller: _currentPasswordController,
                  labelText: AppLocalizations.of(context).translate('current_password'),
                  obscureText: true,
                  validator: (value) {
                    print('[ChangePassword] Validating current password');
                    if (value == null || value.isEmpty) {
                      debugPrint('[ChangePassword] Validation failed: Current password empty');
                      return AppLocalizations.of(context).translate('enter_current_password');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _newPasswordController,
                  labelText: AppLocalizations.of(context).translate('new_password'),
                  obscureText: true,
                  validator: (value) {
                    print('[ChangePassword] Validating new password');
                    if (value == null || value.isEmpty) {
                      debugPrint('[ChangePassword] Validation failed: New password empty');
                      return AppLocalizations.of(context).translate('enter_new_password');
                    }
                    if (value.length < 6) {
                      debugPrint('[ChangePassword] Validation failed: New password too short');
                      return AppLocalizations.of(context).translate('password_min_length');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _confirmPasswordController,
                  labelText: AppLocalizations.of(context).translate('confirm_new_password'),
                  obscureText: true,
                  validator: (value) {
                    print('[ChangePassword] Validating password confirmation');
                    if (value != _newPasswordController.text) {
                      debugPrint('[ChangePassword] Validation failed: Passwords mismatch');
                      return AppLocalizations.of(context).translate('passwords_not_match');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : Text(AppLocalizations.of(context).translate('change_password')),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    final navigationLog = '''
          [${DateTime.now().toIso8601String()}] [ChangePassword] NAVIGATION:
          Action: Navigating to ForgotPasswordScreen
          Token: ${widget.token.isNotEmpty ? '*****' : 'empty'}
          ''';
                    print(navigationLog);
                    debugPrint(navigationLog);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ForgotPasswordScreen(token: widget.token),
                      ),
                    );
                  },
                  child: Text(AppLocalizations.of(context).translate('forgot_password')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  final String token;

  const ForgotPasswordScreen({Key? key, required this.token}) : super(key: key);

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  final User _userApi = User();

  @override
  void initState() {
    super.initState();
    print('[ForgotPassword] Screen initialized with token: ${widget.token}');
  }

  @override
  void dispose() {
    _emailController.dispose();
    print('[ForgotPassword] Screen disposed');
    super.dispose();
  }

  Future<void> _submitForm() async {
    print('[ForgotPassword] Submit form triggered');

    if (!_formKey.currentState!.validate()) {
      print('[ForgotPassword] Form validation failed');
      return;
    }

    print('[ForgotPassword] Form validated successfully');
    print('[ForgotPassword] Email: ${_emailController.text}');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      print('[ForgotPassword] Calling forgotPassword API...');
      final result = await _userApi.forgotPassword(
        token: widget.token,
        email: _emailController.text,
      );

      print('[ForgotPassword] API Response: $result');

      if (result['success'] == true) {
        print('[ForgotPassword] Password reset email sent successfully');
        setState(() {
          _successMessage = result['message'];
          _emailController.clear();
        });
      } else {
        print('[ForgotPassword] Password reset failed: ${result['error']}');
        setState(() {
          _errorMessage = result['error'];
        });
      }
    } catch (e, stackTrace) {
      print('[ForgotPassword] Exception occurred: $e');
      print('[ForgotPassword] Stack trace: $stackTrace');
      setState(() {
        _errorMessage = AppLocalizations.of(context).translate('error_occurred_try_again');
      });
    } finally {
      print('[ForgotPassword] API call completed');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[ForgotPassword] Building widget...');
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('forgot_password')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).errorColor),
                    ),
                  ),
                if (_successMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                Text(
                  AppLocalizations.of(context).translate('forgot_password_instructions'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                CustomTextField(
                  controller: _emailController,
                  labelText: AppLocalizations.of(context).translate('email_address'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    print('[ForgotPassword] Validating email');
                    if (value == null || value.isEmpty) {
                      return AppLocalizations.of(context).translate('enter_email_address');
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return AppLocalizations.of(context).translate('enter_valid_email');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : Text(AppLocalizations.of(context).translate('send_reset_link')),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    print('[ForgotPassword] Navigating back to ChangePasswordScreen');
                    Navigator.pop(context);
                  },
                  child: Text(AppLocalizations.of(context).translate('back_to_change_password')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}