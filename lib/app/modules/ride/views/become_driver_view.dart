// Copyright 2023, the hatem ragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up/app/core/api_service/drivers/drivers_api_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';
import 'package:super_up/app/core/services/user_files_service.dart';
import 'package:super_up/app/core/app_config/app_config_controller.dart';

class BecomeDriverView extends StatefulWidget {
  const BecomeDriverView({super.key});

  @override
  State<BecomeDriverView> createState() => _BecomeDriverViewState();
}

class _BecomeDriverViewState extends State<BecomeDriverView> {
  final _formKey = GlobalKey<FormState>();
  
  // Text controllers
  String? _selectedVehicleType;
  final _modelCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  
  // Orbit categories
  final List<String> _vehicleTypes = [
    'Orbit Comfort',
    'OrbitX',
    'Economy',
    'OrbitXL',
    'OrbitGreen',
    'Women only',
    'Orbit Share',
    'Orbit Vans',
    'Orbit Motorbikes',
    'Orbit Electric',
    'Orbit Send',
    'Orbit Food',
  ];
  
  // Uploaded file URLs (stored after upload)
  String? _idImageUrl;
  String? _passportPhotoUrl;
  String? _licenseUrl;
  String? _logbookUrl;
  String? _insuranceUrl;
  String? _inspectionUrl;
  String? _kraPinUrl;
  String? _vehicleImageUrl;
  
  bool _isLoading = false;
  bool _isUploading = false; // for any single file upload
  String? _uploadingDocType; // tracks which document is currently uploading
  bool _hasPending = false;
  bool _isApproved = false;
  double _subscriptionFee = 0;

  @override
  void initState() {
    super.initState();
    _refreshAndLoadConfig();
    _checkExistingApplication();
  }

  Future<void> _refreshAndLoadConfig() async {
    try {
      await GetIt.I.get<VAppConfigController>().refreshAppConfig();
    } catch (_) {}
    _loadConfig();
  }

  void _loadConfig() {
    final config = VAppConfigController.appConfig;
    if (!mounted) return;
    setState(() {
      _subscriptionFee = config.driverSubscriptionFee ?? 0;
    });
  }

  Future<void> _showApprovedDialog() async {
    if (!mounted) return;
    await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Application Approved'),
        content: const Text('Congratulations! You are approved as a driver.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _checkExistingApplication() async {
    try {
      final latest = await DriversApiService.myLatest();
      if (!mounted) return;
      final status = latest?['status']?.toString().toLowerCase();
      if (status == 'pending') {
        _hasPending = true;
        await _showPendingDialog();
        setState(() {});
      } else if (status == 'approved') {
        _isApproved = true;
        await _showApprovedDialog();
        setState(() {});
      }
    } catch (e) {
      // ignore check errors silently
    }
  }

  Future<void> _showPendingDialog() async {
    if (!mounted) return;
    await showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Application Pending'),
        content: const Text('Your driver application is pending review. We will notify you once approved.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
  
  Future<void> _pickFile(String type) async {
    if (_isUploading) return;
    try {
      VPlatformFile? picked;
      // Decide picker based on document type
      switch (type) {
        case 'ID/Passport':
        case "Driver's License":
        case 'Passport Photo':
        case 'Vehicle Image':
          picked = await VAppPick.getImage(isFromCamera: type == 'Passport Photo');
          break;
        case 'Logbook':
        case 'Insurance':
        case 'Inspection Report':
        case 'KRA Pin':
          // Let user choose any file (images or docs)
          final choice = await VAppAlert.showModalSheetWithActions(
            context: context,
            cancelLabel: 'Cancel',
            content: [
              ModelSheetItem(id: 'files', title: 'Pick Document', iconData: const Icon(CupertinoIcons.doc)),
              ModelSheetItem(id: 'media', title: 'Pick Photo/Video', iconData: const Icon(CupertinoIcons.photo_on_rectangle)),
            ],
          );
          if (choice == null) return;
          if (choice.id == 'files') {
            final files = await VAppPick.getFiles();
            picked = files?.firstOrNull;
          } else if (choice.id == 'media') {
            final files = await VAppPick.getMedia();
            picked = files?.firstOrNull;
          }
          break;
        default:
          final files = await VAppPick.getFiles();
          picked = files?.firstOrNull;
      }

      if (picked == null) return;

      setState(() {
        _isUploading = true;
        _uploadingDocType = type;
      });
      final uploaded = await UserFilesService.uploadFiles([picked]);
      if (uploaded.isEmpty || uploaded.first.networkUrl == null) {
        throw Exception('Upload failed');
      }
      final url = uploaded.first.networkUrl!;

      setState(() {
        switch (type) {
          case 'ID/Passport':
            _idImageUrl = url;
            break;
          case 'Passport Photo':
            _passportPhotoUrl = url;
            break;
          case "Driver's License":
            _licenseUrl = url;
            break;
          case 'Logbook':
            _logbookUrl = url;
            break;
          case 'Insurance':
            _insuranceUrl = url;
            break;
          case 'Inspection Report':
            _inspectionUrl = url;
            break;
          case 'KRA Pin':
            _kraPinUrl = url;
            break;
          case 'Vehicle Image':
            _vehicleImageUrl = url;
            break;
        }
      });

      if (mounted) {
        VAppAlert.showSuccessSnackBar(context: context, message: 'Uploaded');
      }
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: 'Upload failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadingDocType = null;
        });
      }
    }
  }
  
  Future<void> _submitForm() async {
    if (_hasPending) {
      await _showPendingDialog();
      return;
    }
    if (_isApproved) {
      await _showApprovedDialog();
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      await DriversApiService.createApplication(
        vehicleType: _selectedVehicleType ?? '',
        vehicleModel: _modelCtrl.text.trim(),
        vehiclePlate: _plateCtrl.text.trim(),
        vehicleCapacity: int.tryParse(_capacityCtrl.text.trim()),
        idImageUrl: _idImageUrl,
        selfieImageUrl: _passportPhotoUrl,
        licenseUrl: _licenseUrl,
        logbookUrl: _logbookUrl,
        insuranceUrl: _insuranceUrl,
        inspectionUrl: _inspectionUrl,
        kraPinUrl: _kraPinUrl,
        vehicleImageUrl: _vehicleImageUrl,
      );
      _hasPending = true;
      if (mounted) VAppAlert.showSuccessSnackBar(context: context, message: 'Application submitted');
      if (mounted) await _showPendingDialog();
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();
        final isInsufficient = errorMsg.contains('Insufficient wallet balance');
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(isInsufficient ? 'Insufficient Balance' : 'Error'),
            content: Text(
              isInsufficient
                  ? 'You need at least KSh ${_subscriptionFee.toStringAsFixed(0)} in your wallet to apply. Please top up your wallet and try again.'
                  : 'Failed to submit application: $errorMsg',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text(
          'Become a Driver',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: CupertinoTheme.of(context).barBackgroundColor,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFEEBA)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(CupertinoIcons.info, color: Color(0xFF8A6D3B), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _subscriptionFee > 0
                              ? 'Driver subscription fee: KSh ${_subscriptionFee.toStringAsFixed(0)}/month. This will be deducted from your wallet upon submission.'
                              : 'Join Orbit Ride for free. No subscription fee is required to become a driver.',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Hero Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB48648), Color(0xFF8B6914)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB48648).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.car_detailed,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Join Orbit Drivers',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Start earning by becoming a verified driver',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Vehicle Details Section
                _buildSectionHeader('Vehicle Details', CupertinoIcons.car_fill),
                const SizedBox(height: 16),
                
                _buildInputField(
                  label: 'Vehicle Type',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? CupertinoColors.darkBackgroundGray : CupertinoColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CupertinoColors.systemGrey4,
                        width: 1,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedVehicleType,
                        hint: Text(
                          'Select vehicle type',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : CupertinoColors.systemGrey,
                          ),
                        ),
                        isExpanded: true,
                        icon: const Icon(CupertinoIcons.chevron_down, size: 20),
                        dropdownColor: isDark ? CupertinoColors.darkBackgroundGray : CupertinoColors.white,
                        style: TextStyle(
                          color: isDark ? Colors.white : CupertinoColors.label,
                        ),
                        items: _vehicleTypes.map((String type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Text(
                              type,
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.white : CupertinoColors.label,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedVehicleType = newValue;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                
                _buildInputField(
                  label: 'Vehicle Model',
                  child: CupertinoTextField(
                    controller: _modelCtrl,
                    placeholder: 'e.g., Toyota Camry 2020',
                    style: TextStyle(
                      color: isDark ? Colors.white : CupertinoColors.label,
                    ),
                    placeholderStyle: TextStyle(
                      color: isDark ? Colors.white70 : CupertinoColors.placeholderText,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? CupertinoColors.darkBackgroundGray : CupertinoColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CupertinoColors.systemGrey4,
                        width: 1,
                      ),
                    ),
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(CupertinoIcons.car_detailed, color: Color(0xFFB48648), size: 20),
                    ),
                  ),
                ),
                
                _buildInputField(
                  label: 'Number Plate',
                  child: CupertinoTextField(
                    controller: _plateCtrl,
                    placeholder: 'e.g., KBA 123A',
                    style: TextStyle(
                      color: isDark ? Colors.white : CupertinoColors.label,
                    ),
                    placeholderStyle: TextStyle(
                      color: isDark ? Colors.white70 : CupertinoColors.placeholderText,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? CupertinoColors.darkBackgroundGray : CupertinoColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CupertinoColors.systemGrey4,
                        width: 1,
                      ),
                    ),
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(CupertinoIcons.number, color: Color(0xFFB48648), size: 20),
                    ),
                  ),
                ),
                
                _buildInputField(
                  label: 'Vehicle Capacity',
                  child: CupertinoTextField(
                    controller: _capacityCtrl,
                    placeholder: 'e.g., 4 passengers',
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: isDark ? Colors.white : CupertinoColors.label,
                    ),
                    placeholderStyle: TextStyle(
                      color: isDark ? Colors.white70 : CupertinoColors.placeholderText,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? CupertinoColors.darkBackgroundGray : CupertinoColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CupertinoColors.systemGrey4,
                        width: 1,
                      ),
                    ),
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(CupertinoIcons.person_2_fill, color: Color(0xFFB48648), size: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Document Uploads Section
                _buildSectionHeader('Required Documents', CupertinoIcons.doc_text_fill),
                const SizedBox(height: 16),
                
                // National ID or Passport
                _buildFileUploadRow(
                  'National ID or Passport',
                  _idImageUrl != null,
                  () => _pickFile('ID/Passport'),
                  'ID/Passport',
                ),
                
                // Passport Photo
                _buildFileUploadRow(
                  'Passport Photo',
                  _passportPhotoUrl != null,
                  () => _pickFile('Passport Photo'),
                  'Passport Photo',
                ),
                
                // Driver's License
                _buildFileUploadRow(
                  'Driver\'s License',
                  _licenseUrl != null,
                  () => _pickFile('Driver\'s License'),
                  'Driver\'s License',
                ),
                
                // Logbook
                _buildFileUploadRow(
                  'Logbook',
                  _logbookUrl != null,
                  () => _pickFile('Logbook'),
                  'Logbook',
                ),
                
                // PSV/Car Insurance
                _buildFileUploadRow(
                  'PSV/Car Insurance',
                  _insuranceUrl != null,
                  () => _pickFile('Insurance'),
                  'Insurance',
                ),
                
                // Vehicle Inspection Report
                _buildFileUploadRow(
                  'Vehicle Inspection Report',
                  _inspectionUrl != null,
                  () => _pickFile('Inspection Report'),
                  'Inspection Report',
                ),
                
                // KRA Pin
                _buildFileUploadRow(
                  'KRA Pin',
                  _kraPinUrl != null,
                  () => _pickFile('KRA Pin'),
                  'KRA Pin',
                ),
                
                // Vehicle Image
                _buildFileUploadRow(
                  'Vehicle Image',
                  _vehicleImageUrl != null,
                  () => _pickFile('Vehicle Image'),
                  'Vehicle Image',
                ),
                
                const SizedBox(height: 32),
                
                // Submit Button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB48648), Color(0xFF8B6914)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB48648).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    onPressed: (_isLoading || _isUploading || _hasPending || _isApproved) ? null : _submitForm,
                    child: _isLoading
                        ? const CupertinoActivityIndicator(color: Colors.white)
                        : const Text(
                            'Submit Application',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFB48648).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFB48648),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildInputField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.systemGrey,
          ),
        ),
        const SizedBox(height: 8),
        child,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFileUploadRow(String title, bool uploaded, VoidCallback onTap, String docType) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final isThisDocUploading = _isUploading && _uploadingDocType == docType;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? CupertinoColors.darkBackgroundGray : CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: uploaded ? Colors.green.withOpacity(0.3) : CupertinoColors.systemGrey4,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: uploaded 
                  ? Colors.green.withOpacity(0.1) 
                  : const Color(0xFFB48648).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              uploaded ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.doc,
              color: uploaded ? Colors.green : const Color(0xFFB48648),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : CupertinoColors.label,
                  ),
                ),
                if (uploaded)
                  const Text(
                    'Uploaded',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green,
                    ),
                  ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _isUploading ? null : onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: uploaded ? Colors.green : const Color(0xFFB48648),
                borderRadius: BorderRadius.circular(8),
              ),
              child: isThisDocUploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CupertinoActivityIndicator(
                      color: Colors.white,
                      radius: 8,
                    ),
                  )
                : Text(
                    uploaded ? 'Change' : 'Upload',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
