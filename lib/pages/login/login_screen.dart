import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:pos_final/constants.dart';
import 'package:pos_final/helpers/AppTheme.dart';
import 'package:pos_final/locale/MyLocalizations.dart';

import 'view_model_manger/login_cubit.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    return BlocProvider(
      create: (context) => LoginCubit(),
      child: BlocConsumer<LoginCubit, LoginState>(
        listener: (context, state) {
          if (state is LoginFailed) {
            LoginCubit.get(context).isLoading = false;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context).translate('invalid_credentials'),
                  style: const TextStyle(fontSize: 16),
                ),
                backgroundColor: Colors.red.shade800,
                behavior: SnackBarBehavior.floating,
                margin: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                duration: const Duration(seconds: 3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          } else if (state is LoginSuccessfully) {
            LoginCubit.get(context).navigateToHome(context);
          }
        },
        builder: (context, state) {
          var cubit = LoginCubit.get(context);
          return Scaffold(
            body: Stack(
              children: [
                // Background image
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/splash.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
                // Gradient overlay for better readability

                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Form(
                      key: cubit.formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: size.height * 0.08),
                          // Logo and welcome animation
                          Center(
                            child: Lottie.asset(
                              'assets/lottie/welcome.json',
                              height: size.height * 0.3,
                            ),
                          ),
                          SizedBox(height: size.height * 0.06),
                          // Login form card with elevation for better visual separation
                          Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Heading
                                  Text(
                                    AppLocalizations.of(context).translate('welcome_back'),
                                    style: AppTheme.getTextStyle(
                                      cubit.themeData.textTheme.headlineSmall,
                                      fontWeight: 700,
                                      color: kDefaultColor,
                                    ),
                                  ),
                                  Text(
                                    AppLocalizations.of(context).translate('login'),
                                    style: AppTheme.getTextStyle(
                                      cubit.themeData.textTheme.bodyMedium,
                                      fontWeight: 500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  SizedBox(height: 24),
                                  // Username field
                                  _buildTextField(
                                    context,
                                    cubit,
                                    controller: cubit.usernameController,
                                    hintText: AppLocalizations.of(context).translate('username'),
                                    prefixIcon: Icon(MdiIcons.accountOutline, color: kDefaultColor),
                                    validator: (value) {
                                      if (value!.isEmpty) {
                                        return AppLocalizations.of(context)
                                            .translate('please_enter_username');
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 20),
                                  // Password field
                                  _buildTextField(
                                    context,
                                    cubit,
                                    controller: cubit.passwordController,
                                    hintText: AppLocalizations.of(context).translate('password'),
                                    isPassword: true,
                                    prefixIcon: Icon(MdiIcons.lockOutline, color: kDefaultColor),
                                    suffixIcon: IconButton(
                                      color: kDefaultColor,
                                      icon: Icon(
                                        cubit.passwordVisible
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () {
                                        cubit.passwordVisible = !cubit.passwordVisible;
                                      },
                                    ),
                                    validator: (value) {
                                      if (value!.isEmpty) {
                                        return AppLocalizations.of(context)
                                            .translate('please_enter_password');
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 12),
                                  // Remember me and forgot password (optional)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          // Handle forgot password
                                        },
                                        child: Text(
                                          AppLocalizations.of(context).translate('forget_password'),
                                          style: TextStyle(
                                            color: kDefaultColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 32),
                          // Login button with loading state
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: cubit.isLoading
                                  ? null
                                  : () async {
                                await cubit.checkOnLogin(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kDefaultColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: kDefaultColor.withOpacity(0.6),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: cubit.isLoading
                                  ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                                  : Text(
                                AppLocalizations.of(context).translate('login'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: size.height * 0.1),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField(
      BuildContext context,
      LoginCubit cubit, {
        required TextEditingController controller,
        required String hintText,
        required FormFieldValidator<String> validator,
        bool isPassword = false,
        Widget? prefixIcon,
        Widget? suffixIcon,
      }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? !cubit.passwordVisible : false,
      validator: validator,
      style: AppTheme.getTextStyle(
        cubit.themeData.textTheme.bodyLarge,
        color: cubit.themeData.colorScheme.onBackground,
        fontWeight: 500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTheme.getTextStyle(
          cubit.themeData.textTheme.bodyMedium,
          color: Colors.grey.shade500,
          fontWeight: 400,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kDefaultColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        errorStyle: TextStyle(
          color: Colors.red.shade700,
          fontSize: 12,
        ),
      ),
    );
  }
}