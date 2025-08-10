import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../helpers/AppTheme.dart';
import '../helpers/SizeConfig.dart';
import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';

class Splash extends StatefulWidget {
  static int themeType = 1;

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with TickerProviderStateMixin {
  ThemeData themeData = AppTheme.getThemeFromThemeMode(Splash.themeType);
  CustomAppTheme customAppTheme = AppTheme.getCustomAppTheme(Splash.themeType);
  String? selectedLanguage;

  // Animation controllers
  late AnimationController _logoAnimationController;
  late AnimationController _contentAnimationController;
  late AnimationController _pulseAnimationController;

  // Animations
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Logo animation controller
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );

    // Content animation controller - starts after logo animation
    _contentAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );

    // Pulse animation for the logo
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Logo animations
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Content animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentAnimationController,
        curve: Interval(0.2, 0.8, curve: Curves.easeInOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _contentAnimationController,
        curve: Interval(0.3, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    // Pulse animation for logo
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Start animations in sequence
    _logoAnimationController.forward().then((_) {
      _contentAnimationController.forward();
    });

    changeLanguage();
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _contentAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  void changeLanguage() async {
    var prefs = await SharedPreferences.getInstance();
    selectedLanguage = prefs.getString('language_code') ?? Config().defaultLanguage;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    MySize().init(context);

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



          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: MySize.size24!),
              child: Column(
                  children: [
                  SizedBox(height: MySize.size16),

              // App logo at the top
              ScaleTransition(
                scale: _logoScaleAnimation,
                child: FadeTransition(
                  opacity: _logoOpacityAnimation,
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      height: MySize.size60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(MySize.size12!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: MySize.size16!,
                        vertical: MySize.size8!,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Text(
                          //   "",
                          //   style: AppTheme.getTextStyle(
                          //       themeData.textTheme.titleLarge,
                          //       color: Color(0xff9e1f63),
                          //       fontWeight: 900,
                          //       fontSize: 34
                          //   ),
                          // ),
                          Image.asset(
                            'assets/images/logo.png',
                            height: MySize.size40,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.apps,
                              color: Color(0xff9e1f63),
                              size: MySize.size32,
                            ),
                          ),
                          SizedBox(width: MySize.size12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Welcome animation
              Expanded(
                flex: 5,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                  SizedBox(height: MySize.size20),
                  _buildShimmerText(
                    AppLocalizations.of(context).translate('welcome'),
                    themeData.textTheme.headlineMedium,
                  ),
                  SizedBox(height: MySize.size8),
                  Text(
                    "Experience the app in your language",
                    style: AppTheme.getTextStyle(
                      themeData.textTheme.bodyMedium,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: 400,
                    ),
                    textAlign: TextAlign.center,
                  ),

                        Hero(
                          tag: "app_logo",
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(MySize.size20!),

                            ),
                            // padding: EdgeInsets.all(MySize.size16!),
                            child: Lottie.asset(
                              'assets/lottie/welcome.json',
                              width: MySize.safeWidth! * 0.7,
                              fit: BoxFit.fitWidth,
                            ),
                          ),
                        ),
                      ],
                ),
              ),
            ),
          ),

          // Actions section
          Expanded(
            flex: 3,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Language selection button with animation
                  _buildAnimatedButton(
                    onTap: () {
                      showLanguageDialog();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.language,
                              color: Colors.white,
                              size: MySize.size22,
                            ),
                            SizedBox(width: MySize.size12),
                            Text(
                              AppLocalizations.of(context).translate('language'),
                              style: AppTheme.getTextStyle(
                                themeData.textTheme.bodyLarge,
                                color: Colors.white,
                                fontWeight: 500,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: MySize.size16,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: MySize.size24),

                  // Login button with ripple effect
                  _buildLoginButton(),

                  if (Config().showRegister)
                    Padding(
                      padding: EdgeInsets.only(top: MySize.size20!),
                      child: _buildRegisterButton(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    ),
    ],
    ),
    );
  }

  // Shimmer text effect for welcome text
  Widget _buildShimmerText(String text, TextStyle? baseStyle) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.8),
            Colors.white,
          ],
          stops: [0.0, 0.5, 1.0],
          begin: Alignment(-1.0, -0.2),
          end: Alignment(1.0, 0.2),
          tileMode: TileMode.clamp,
        ).createShader(bounds);
      },
      child: Text(
        text,
        style: AppTheme.getTextStyle(
          baseStyle,
          color: Colors.white,
          fontWeight: 700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Animated button with hover effect
  Widget _buildAnimatedButton({required VoidCallback onTap, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300),
      builder: (context, value, _) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.white.withOpacity(0.1),
            highlightColor: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(MySize.size12!),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: MySize.size16!,
                vertical: MySize.size12!,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(MySize.size12!),
                color: Colors.white.withOpacity(0.05),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  // Login button with animation
  Widget _buildLoginButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Opacity(
            opacity: value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MySize.size12!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.2),
                    blurRadius: 12 * value,
                    spreadRadius: 2 * value,
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () async {
                  await Helper().requestAppPermission();
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  if (prefs.getInt('userId') != null) {
                    Config.userId = prefs.getInt('userId');
                    Helper().jobScheduler();
                    Navigator.of(context).pushReplacementNamed('/layout');
                  } else {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
                style: ElevatedButton.styleFrom(
                  primary: Colors.white,
                  onPrimary: Color(0xff9e1f63),
                  shadowColor: Colors.black26,
                  elevation: 6 * value,
                  padding: EdgeInsets.symmetric(vertical: MySize.size16!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MySize.size12!),
                  ),
                  minimumSize: Size(double.infinity, MySize.size56!),
                ),
                child: Text(
                  AppLocalizations.of(context).translate('login'),
                  style: AppTheme.getTextStyle(
                    themeData.textTheme.titleMedium,
                    color: Color(0xff9e1f63),
                    fontWeight: 600,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Register button with animation
  Widget _buildRegisterButton() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: TextButton(
            onPressed: () async {
              await launch('${Config.baseUrl}/business/register');
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: MySize.size16!,
                vertical: MySize.size8!,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppLocalizations.of(context).translate('register'),
                  style: AppTheme.getTextStyle(
                    themeData.textTheme.bodyLarge,
                    color: Colors.white,
                    fontWeight: 500,
                  ),
                ),
                SizedBox(width: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: Duration(milliseconds: 800),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(8 * (1 - value), 0),
                      child: Opacity(
                        opacity: value,
                        child: Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                          size: MySize.size16,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showLanguageDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 20 * (1.0 - value)),
            child: Opacity(
              opacity: value,
              child: Container(
                decoration: BoxDecoration(
                  color: themeData.colorScheme.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(MySize.size24!),
                    topRight: Radius.circular(MySize.size24!),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: MySize.size24!,
                  vertical: MySize.size16!,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar for bottom sheet
                    Center(
                      child: Container(
                        width: MySize.size40,
                        height: 4,
                        margin: EdgeInsets.only(bottom: MySize.size16!),
                        decoration: BoxDecoration(
                          color: themeData.colorScheme.onBackground.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context).translate('language'),
                          style: AppTheme.getTextStyle(
                            themeData.textTheme.titleLarge,
                            fontWeight: 600,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close),
                          splashRadius: 24,
                        ),
                      ],
                    ),
                    SizedBox(height: MySize.size16),
                    Container(
                      height: 250,
                      child: _buildLanguageList(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLanguageList() {
    var appLanguage = Provider.of<AppLanguage>(context);

    return ListView.builder(
      itemCount: Config().lang.length,
      itemBuilder: (context, index) {
        final language = Config().lang[index];
        final isSelected = language['languageCode'] == selectedLanguage;

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: Duration(milliseconds: 300 + (index * 100)),
          curve: Curves.easeOut,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(30 * (1.0 - value), 0),
              child: Opacity(
                opacity: value,
                child: InkWell(
                  onTap: () {
                    appLanguage.changeLanguage(
                      Locale(language['languageCode']),
                      language['languageCode'],
                    );
                    selectedLanguage = language['languageCode'];
                    Navigator.pop(context);
                  },
                  splashColor: themeData.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(MySize.size8!),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: MySize.size12!, horizontal: MySize.size8!),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: themeData.dividerColor,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(MySize.size8!),
                            border: Border.all(
                              color: isSelected
                                  ? themeData.colorScheme.primary
                                  : themeData.colorScheme.primary.withOpacity(0.2),
                              width: isSelected ? 2 : 1,
                            ),
                            color: isSelected
                                ? themeData.colorScheme.primary.withOpacity(0.1)
                                : Colors.transparent,
                          ),
                          padding: EdgeInsets.all(MySize.size8!),
                          child: Text(
                            language['flag'] ?? "🌐",
                            style: TextStyle(fontSize: MySize.size20),
                          ),
                        ),
                        SizedBox(width: MySize.size16),
                        Expanded(
                          child: Text(
                            language['name'],
                            style: AppTheme.getTextStyle(
                              themeData.textTheme.bodyLarge,
                              fontWeight: isSelected ? 600 : 400,
                              color: isSelected
                                  ? themeData.colorScheme.primary
                                  : themeData.colorScheme.onBackground,
                            ),
                          ),
                        ),
                        if (isSelected)
                          AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            child: Icon(
                              Icons.check_circle,
                              color: themeData.colorScheme.primary,
                              size: MySize.size22,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}