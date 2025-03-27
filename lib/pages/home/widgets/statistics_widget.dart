import 'package:flutter/material.dart';

import '../../../locale/MyLocalizations.dart';

class Statistics extends StatelessWidget {
  const Statistics({
    Key? key,
    this.businessSymbol = '',
    this.totalSales,
    this.totalSalesAmount = 0,
    this.totalReceivedAmount = 0,
    this.totalDueAmount = 0,
    required this.themeData,
  }) : super(key: key);

  final String businessSymbol;
  final int? totalSales;
  final double totalSalesAmount, totalReceivedAmount, totalDueAmount;
  final ThemeData themeData;

  static const List<Color> blocksColor = [
    Color(0xff009dff),
    Color(0xffff9400),
    Color(0xff62ad00),
    Color(0xff9b0819)
  ];

  static const List<String> blocksName = [
    'number_of_sales',
    'sales_amount',
    'paid_amount',
    'due_amount'
  ];

  static const List<String> blocksImagesPath = [
    'assets/images/sales.png',
    'assets/images/total_sales.png',
    'assets/images/payed_money.png',
    'assets/images/recived_money.png'
  ];

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive sizing
    final screenSize = MediaQuery.of(context).size;
    final blockPadding = screenSize.width * 0.03; // 3% of screen width
    final isTablet = screenSize.width > 600;

    return LayoutBuilder(
        builder: (context, constraints) {
          // Adjust grid layout based on available width
          final crossAxisCount = isTablet ? 4 : 2;
          final childAspectRatio = isTablet ? 3 / 2 : 4 / 3;

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: blockPadding,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: blockPadding,
            ),
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            itemCount: 4,
            padding: EdgeInsets.all(blockPadding),
            itemBuilder: (context, index) {
              // Format the amounts in a cleaner way
              String formattedAmount = '';
              if (index == 0) {
                formattedAmount = formatQuantity(totalSales ?? 0);
              } else if (index == 1) {
                formattedAmount = '$businessSymbol ${formatCurrency(totalSalesAmount)}';
              } else if (index == 2) {
                formattedAmount = '$businessSymbol ${formatCurrency(totalReceivedAmount)}';
              } else {
                formattedAmount = '$businessSymbol ${formatCurrency(totalDueAmount)}';
              }

              return AnimatedStatBlock(
                themeData: themeData,
                blockColor: blocksColor[index],
                index: index,
                image: blocksImagesPath[index],
                subject: AppLocalizations.of(context).translate(blocksName[index]),
                amount: formattedAmount,
                delay: index * 0.2, // Staggered delay
              );
            },
          );
        }
    );
  }

  // Helper methods moved inside the class
  String formatQuantity(int value) {
    // Format number with commas for thousands
    return value.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},'
    );
  }

  String formatCurrency(double value) {
    // Format currency with 2 decimal places
    return value.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},'
    );
  }
}

class AnimatedStatBlock extends StatefulWidget {
  const AnimatedStatBlock({
    Key? key,
    required this.blockColor,
    required this.index,
    required this.themeData,
    required this.subject,
    required this.amount,
    required this.image,
    this.delay = 0.0,
  }) : super(key: key);

  final Color blockColor;
  final int index;
  final ThemeData themeData;
  final String subject, amount, image;
  final double delay;

  @override
  State<AnimatedStatBlock> createState() => _AnimatedStatBlockState();
}

class _AnimatedStatBlockState extends State<AnimatedStatBlock>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Delay each animation based on index
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).round()), () {
      if (mounted) _controller.forward();
    });

    // Decide the direction based on the index
    final direction = widget.index.isEven ? 1.0 : -1.0;

    _slideAnimation = Tween<Offset>(
      begin: Offset(direction, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: StatBlock(
          themeData: widget.themeData,
          amount: widget.amount,
          subject: widget.subject,
          backgroundColor: widget.blockColor,
          image: widget.image,
        ),
      ),
    );
  }
}

class StatBlock extends StatelessWidget {
  const StatBlock({
    Key? key,
    required this.themeData,
    required this.amount,
    required this.subject,
    required this.backgroundColor,
    required this.image,
  }) : super(key: key);

  final ThemeData themeData;
  final String amount, subject, image;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            backgroundColor,
            backgroundColor.withOpacity(0.8),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Handle tap if needed
            },
            splashColor: Colors.white.withOpacity(0.1),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center, // Centers the children
                    children: [
                      Image.asset(
                        image,
                        height: 42,
                        width: 42,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    subject,
                    style: themeData.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    amount,
                    style: themeData.textTheme.bodyLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}