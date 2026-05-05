// Copyright 2023, the hatemragab project author.
// All rights reserved. Use of this source code is governed by a
// MIT license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:s_translation/generated/l10n.dart';
import '../../../../../core/services/call_background_service.dart';

class CallBackgroundSettingsPage extends StatefulWidget {
  const CallBackgroundSettingsPage({super.key});

  @override
  State<CallBackgroundSettingsPage> createState() => _CallBackgroundSettingsPageState();
}

class _CallBackgroundSettingsPageState extends State<CallBackgroundSettingsPage> {
  final CallBackgroundService _service = CallBackgroundService.instance;
  bool _isLoading = false;
  String? _currentImagePath;
  bool _isEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    await _service.init();
    setState(() {
      _currentImagePath = _service.backgroundImagePath;
      _isEnabled = _service.isBackgroundEnabled;
    });
  }

  Future<void> _pickImage() async {
    setState(() => _isLoading = true);
    
    try {
      final String? imagePath = await _service.pickAndSaveBackgroundImage();
      if (imagePath != null) {
        setState(() {
          _currentImagePath = imagePath;
          _isEnabled = true;
        });
        
        if (mounted) {
          _showMessage('Background image updated successfully');
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Failed to update background image');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeImage() async {
    setState(() => _isLoading = true);
    
    try {
      await _service.removeBackgroundImage();
      setState(() {
        _currentImagePath = null;
        _isEnabled = false;
      });
      
      if (mounted) {
        _showMessage('Background image removed');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Failed to remove background image');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleEnabled(bool enabled) async {
    setState(() => _isLoading = true);
    
    try {
      await _service.setBackgroundEnabled(enabled);
      setState(() => _isEnabled = enabled);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update setting')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        leading: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Icon(CupertinoIcons.chevron_back, color: Colors.white),
          ),
        ),
        middle: const Text('Call Background'),
        previousPageTitle: S.of(context).settings,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview section
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildPreview(),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Settings section
              CupertinoListSection(
                backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
                header: const Text('BACKGROUND SETTINGS', style: TextStyle(color: Colors.black)),
                children: [
                  CupertinoListTile(
                    title: const Text('Enable Custom Background'),
                    trailing: CupertinoSwitch(
                      value: _isEnabled && _currentImagePath != null,
                      activeColor: const Color(0xFFB48648),
                      onChanged: _currentImagePath != null ? _toggleEnabled : null,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              CupertinoListSection(
                backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
                header: const Text('ACTIONS', style: TextStyle(color: Colors.black)),
                children: [
                  CupertinoListTile(
                    title: const Text('Choose Background Image'),
                    leading: const Icon(CupertinoIcons.photo, color: Color(0xFFB48648)),
                    trailing: _isLoading 
                        ? const CupertinoActivityIndicator()
                        : const Icon(CupertinoIcons.chevron_right, color: Color(0xFFB48648)),
                    onTap: _isLoading ? null : _pickImage,
                  ),
                  if (_currentImagePath != null)
                    CupertinoListTile(
                      title: const Text('Remove Background'),
                      leading: const Icon(CupertinoIcons.delete, color: Colors.red),
                      trailing: _isLoading 
                          ? const CupertinoActivityIndicator()
                          : const Icon(CupertinoIcons.chevron_right, color: Color(0xFFB48648)),
                      onTap: _isLoading ? null : _removeImage,
                    ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Info section (grey background with white text)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(CupertinoIcons.info_circle, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'About Call Backgrounds',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Custom backgrounds will appear in video call boxes when your camera is off or when other participants have their cameras disabled. This helps personalize your calling experience.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_currentImagePath != null && _isEnabled) {
      if (kIsWeb) {
        // Web: Use base64 image from SharedPreferences
        return FutureBuilder<String?>(
          future: _getWebImageBase64(_currentImagePath!),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              try {
                final Uint8List imageBytes = base64Decode(snapshot.data!);
                return Image.memory(
                  imageBytes,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildDefaultPreview();
                  },
                );
              } catch (e) {
                return _buildDefaultPreview();
              }
            }
            return _buildDefaultPreview();
          },
        );
      } else {
        // Mobile/Desktop: Use file system
        return Image.file(
          File(_currentImagePath!),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultPreview();
          },
        );
      }
    }
    
    return _buildDefaultPreview();
  }

  Widget _buildDefaultPreview() {
    return Container(
      color: Colors.grey.shade900,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.videocam_fill,
              color: Colors.white70,
              size: 48,
            ),
            SizedBox(height: 8),
            Text(
              'Default Background',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (kIsWeb) {
      // On web, use a simple print statement or console log
      if (kDebugMode) {
        print('CallBackground: $message');
      }
    } else {
      // On mobile, show Cupertino dialog
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Call Background'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }

  Future<String?> _getWebImageBase64(String webImageKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(webImageKey);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting web image base64: $e');
      }
      return null;
    }
  }
}
