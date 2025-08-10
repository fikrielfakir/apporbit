import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../apis/api.dart';
import '../models/stock_transfer.dart';
import '../models/system.dart';
import '../../../locale/MyLocalizations.dart';

class EditStockTransferScreen extends StatefulWidget {
  final String transferId;
  final int locationId;
  final int transferLocationId;

  const EditStockTransferScreen({
    Key? key,
    required this.transferId,
    required this.locationId,
    required this.transferLocationId,
  }) : super(key: key);

  @override
  State<EditStockTransferScreen> createState() => _EditStockTransferScreenState();
}

class _EditStockTransferScreenState extends State<EditStockTransferScreen> {
  final _api = Api();
  late StockTransfer _transfer;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadTransfer();
  }

  Future<void> _loadTransfer() async {
    try {
      final token = await System().getToken();
      final transfer = await _api.stockTransfer.getStockTransfer(
        token: token,
        transferId: widget.transferId,
      );

      if (!mounted) return;

      setState(() {
        _transfer = transfer;
        _selectedStatus = transfer.status;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load transfer: ${e.toString()}');
      if (!mounted) return;
      _showErrorSnackbar(AppLocalizations.of(context).translate('error_loading_transfer'));
      Navigator.pop(context);
    }
  }

  Future<void> _updateStatus() async {
    if (_selectedStatus == _transfer.status || _isSaving) return;

    // Show confirmation dialog before updating status
    final confirmed = await _showStatusChangeConfirmation();
    if (!confirmed) {
      setState(() => _selectedStatus = _transfer.status); // Revert selection
      return;
    }

    setState(() => _isSaving = true);

    try {
      final token = await System().getToken();

      final updatedTransfer = await _api.stockTransfer.updateStockTransferStatus(
        token: token,
        transferId: widget.transferId,
        status: _selectedStatus!,
      );

      if (!mounted) return;

      setState(() {
        _transfer = updatedTransfer;
        _selectedStatus = updatedTransfer.status;
      });

      _showSuccessSnackbar(
          '${AppLocalizations.of(context).translate('finals')} ${_getLocalizedStatus(_selectedStatus!)}'
      );
    } catch (e) {
      debugPrint('Failed to update status ${e.toString()}');
      _showErrorSnackbar(AppLocalizations.of(context).translate('error_updating_status'));
      // Revert selection on error
      setState(() => _selectedStatus = _transfer.status);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _showStatusChangeConfirmation() async {
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final statusColor = _getStatusColor(_selectedStatus!);

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(20),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade50.withOpacity(0.8),
                    Colors.white.withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated icon with pulse effect
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.9, end: 1).animate(
                        CurvedAnimation(
                          parent: ModalRoute.of(context)!.animation!,
                          curve: Curves.elasticOut,
                        ),
                      ),
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              statusColor.withOpacity(0.2),
                              Colors.transparent,
                            ],
                            radius: 0.8,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          size: 60,
                          color: statusColor,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Title with slide animation
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0, -0.3),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: ModalRoute.of(context)!.animation!,
                        curve: Curves.easeOutBack,
                      )),
                      child: Text(
                        AppLocalizations.of(context).translate('confirm_status_change'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 12),

                    // Status badge with gradient and animation
                    FadeTransition(
                      opacity: ModalRoute.of(context)!.animation!,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              statusColor.withOpacity(0.7),
                              statusColor,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Text(
                          _getLocalizedStatus(_selectedStatus!).toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 28),

                    // Direction-aware slide to confirm button
                    _buildSlideToConfirmButton(context, isRTL, statusColor),
                    SizedBox(height: 16),

                    // Cancel button with bounce animation
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.9, end: 1).animate(
                        CurvedAnimation(
                          parent: ModalRoute.of(context)!.animation!,
                          curve: Curves.elasticOut,
                        ),
                      ),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        ),
                        child: Text(
                          AppLocalizations.of(context).translate('cancel'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop(false);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ) ?? false;
  }

  Widget _buildSlideToConfirmButton(BuildContext context, bool isRTL, Color statusColor) {
    double buttonPosition = 0;
    bool isConfirmed = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            if (!isConfirmed) {
              setState(() {
                // Handle RTL direction
                buttonPosition += isRTL ? -details.delta.dx : details.delta.dx;
                buttonPosition = buttonPosition.clamp(0, 180).toDouble();
              });
            }
          },
          onHorizontalDragEnd: (details) {
            if (buttonPosition > 150 && !isConfirmed) {
              setState(() {
                isConfirmed = true;
                buttonPosition = 180;
                HapticFeedback.heavyImpact();
              });
              Future.delayed(Duration(milliseconds: 300), () {
                Navigator.of(context).pop(true);
              });
            } else {
              setState(() {
                buttonPosition = 0;
              });
            }
          },
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Animated gradient background
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  width: buttonPosition,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withOpacity(0.2),
                        statusColor.withOpacity(0.4),
                      ],
                      begin: isRTL ? Alignment.centerRight : Alignment.centerLeft,
                      end: isRTL ? Alignment.centerLeft : Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),

                // Draggable button with direction-aware icon
                AnimatedPositioned(
                  duration: Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  left: isRTL ? null : buttonPosition,
                  right: isRTL ? buttonPosition : null,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor,
                          Color.lerp(statusColor, Colors.black, 0.1)!,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      isConfirmed
                          ? Icons.check
                          : isRTL ? Icons.arrow_forward_ios: Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),

                // Centered text
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 80),
                    child: Text(
                      isConfirmed
                          ? AppLocalizations.of(context).translate('confirmed')
                          : AppLocalizations.of(context).translate('slide_to_confirm'),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getLocalizedStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppLocalizations.of(context).translate('pending');
      case 'in_transit':
        return AppLocalizations.of(context).translate('in_transit');
      case 'completed':
        return AppLocalizations.of(context).translate('completed');
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green.shade600;
      case 'in_transit':
        return Colors.orange.shade600;
      case 'pending':
        return Colors.blue.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('transfer_details')),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTransfer,
            tooltip: AppLocalizations.of(context).translate('refresh'),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTransferInfoCard(),
            SizedBox(height: 24),
            if (_transfer.status.toLowerCase() != 'final')
              _buildStatusCard(),
            SizedBox(height: 24),
            _buildProductsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    _transfer.refNo,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_transfer.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(_transfer.status),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getLocalizedStatus(_transfer.status).toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(_transfer.status),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.arrow_outward,
              label: AppLocalizations.of(context).translate('from'),
              value: '${_transfer.locationName} (${AppLocalizations.of(context).translate('id')}: ${_transfer.locationId})',
            ),
            SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.arrow_downward,
              label: AppLocalizations.of(context).translate('to'),
              value: '${_transfer.transferLocationName} (${AppLocalizations.of(context).translate('id')}: ${_transfer.transferLocationId})',
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                SizedBox(width: 8),
                Text(_transfer.formattedDate),
                SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                SizedBox(width: 8),
                Text(_transfer.formattedTime),
              ],
            ),
            if (_transfer.additionalNotes != null &&
                _transfer.additionalNotes!.isNotEmpty) ...[
              SizedBox(height: 16),
              _buildNotesSection(),
            ],
            SizedBox(height: 16),
            Divider(height: 1, color: Colors.grey.shade200),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context).translate('total_amount'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_transfer.finalTotal.toStringAsFixed(2)} MAD',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).primaryColor),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.note, size: 16, color: Colors.grey.shade600),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              _transfer.additionalNotes!,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final statusList = ['completed'];
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50.withOpacity(0.3),
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center, // Centered content
            children: [
              // Header with animation
              SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0, -0.2),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: ModalRoute.of(context)!.animation!,
                  curve: Curves.easeOutCubic,
                )),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sync_alt, size: 20, color: Colors.blue.shade600),
                    SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).translate('update_status').toUpperCase(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Status selection with sliding action
              for (final status in statusList)
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: _buildStatusSliderOption(status, isRTL),
                ),

              if (_isSaving) ...[
                SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Theme.of(context).primaryColor,
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSliderOption(String status, bool isRTL) {
    double buttonPosition = 0;
    bool isActivated = _selectedStatus == status;
    final statusColor = _getStatusColor(status);

    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            if (!isActivated) {
              setState(() {
                // Handle RTL drag direction
                buttonPosition += isRTL ? -details.delta.dx : details.delta.dx;
                buttonPosition = buttonPosition.clamp(0, 120).toDouble();
              });
            }
          },
          onHorizontalDragEnd: (details) {
            if (buttonPosition > 100 && !isActivated) {
              setState(() {
                isActivated = true;
                buttonPosition = 120;
                HapticFeedback.mediumImpact();
              });
              Future.delayed(Duration(milliseconds: 200), () {
                setState(() {
                  _selectedStatus = status;
                  _updateStatus();
                });
              });
            } else {
              setState(() {
                buttonPosition = 0;
              });
            }
          },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.grey.shade50,
                  Colors.grey.shade100,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActivated
                    ? statusColor.withOpacity(0.5)
                    : Colors.grey.shade300,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Animated gradient background
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  width: buttonPosition,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        statusColor.withOpacity(0.2),
                        statusColor.withOpacity(0.4),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),

                // Status content (centered)
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: isActivated
                                ? statusColor
                                : Colors.grey.shade400,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            _getLocalizedStatus(status).toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isActivated
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade600,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(width: 12),
                        Icon(
                          isActivated ? Icons.check_circle :
                          isRTL ? Icons.arrow_back_ios : Icons.arrow_forward_ios,

                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),

                // Draggable button with directional icon
                if (!isActivated)
                  Positioned(
                    left: isRTL ? null : buttonPosition,
                    right: isRTL ? buttonPosition : null,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white,
                            Colors.grey.shade50,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isRTL ? Icons.arrow_forward_ios: Icons.arrow_forward_ios,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).translate('transfer_items').toUpperCase(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 16),
            ..._transfer.lines.map((line) => Column(
              children: [
                _buildProductItem(line),
                if (_transfer.lines.indexOf(line) != _transfer.lines.length - 1)
                  Divider(height: 24, color: Colors.grey.shade200),
              ],
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildProductItem(StockTransferLine line) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            line.quantity.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.productName,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
              if (line.variationName.isNotEmpty) ...[
                SizedBox(height: 2),
                Text(
                  line.variationName,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${line.unitPrice.toStringAsFixed(2)} MAD',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '${line.lineTotal.toStringAsFixed(2)} MAD',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}