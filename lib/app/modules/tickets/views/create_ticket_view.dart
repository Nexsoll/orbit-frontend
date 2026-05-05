import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import '../services/tickets_api_service.dart';

class CreateTicketView extends StatefulWidget {
  const CreateTicketView({super.key});

  @override
  State<CreateTicketView> createState() => _CreateTicketViewState();
}

class _CreateTicketViewState extends State<CreateTicketView> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  DateTime? _expiryDate;
  VPlatformFile? _selectedImage;
  bool _saving = false;
  int _quantity = 1;
  String? _selectedCategory;

  static const _brand = Color(0xFFB48648);

  final List<String> _categories = const [
    'Movie',
    'Sports',
    'Transport',
    'Music',
    'Conference',
    'Food & Dining',
    'Tech',
    'Travel',
    'Education',
    'Entertainment',
    'Other',
  ];

  late final TicketsApiService _api;

  @override
  void initState() {
    super.initState();
    _api = GetIt.I.get<TicketsApiService>();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = int.tryParse(_priceCtrl.text.trim());

    if (name.isEmpty) {
      VAppAlert.showErrorSnackBar(context: context, message: 'Please enter ticket name');
      return;
    }
    if (price == null || price <= 0) {
      VAppAlert.showErrorSnackBar(context: context, message: 'Please enter a valid price');
      return;
    }
    if (_quantity < 1) {
      VAppAlert.showErrorSnackBar(context: context, message: 'Quantity must be at least 1');
      return;
    }
    if (_expiryDate == null) {
      VAppAlert.showErrorSnackBar(context: context, message: 'Please select expiry date');
      return;
    }

    setState(() => _saving = true);
    try {
      await _api.createTicket(
        name: name,
        priceKes: price,
        expiryDate: _expiryDate!.toUtc().toIso8601String(),
        quantity: _quantity,
        category: _selectedCategory,
        image: _selectedImage,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final file = await VAppPick.getImage();
      if (file != null) {
        setState(() => _selectedImage = file);
      }
    } catch (e) {
      VAppAlert.showErrorSnackBar(context: context, message: 'Failed to pick image: $e');
    }
  }

  void _clearImage() {
    setState(() => _selectedImage = null);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (_) => Container(
        height: 260,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _expiryDate ?? now.add(const Duration(days: 30)),
                minimumDate: now,
                maximumDate: now.add(const Duration(days: 365 * 5)),
                onDateTimeChanged: (d) {
                  _expiryDate = d;
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CupertinoButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: const Text('Select'),
                  onPressed: () => Navigator.pop(context, _expiryDate ?? now.add(const Duration(days: 30))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  String get _expiryLabel {
    if (_expiryDate == null) return 'Select expiry date';
    return '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        transitionBetweenRoutes: false,
        middle: const Text('Create Ticket'),
        trailing: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const CupertinoActivityIndicator()
              : const Text(
                  'Save',
                  style: TextStyle(
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          color: _brand,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ticket Name',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              CupertinoTextField(
                controller: _nameCtrl,
                placeholder: 'e.g. Concert VIP Pass',
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ticket Image',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6.resolveFrom(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: _selectedImage != null
                      ? Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: _buildSelectedImage(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedImage!.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minSize: 30,
                              onPressed: _clearImage,
                              child: const Icon(
                                CupertinoIcons.xmark_circle_fill,
                                color: CupertinoColors.destructiveRed,
                                size: 22,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const Icon(CupertinoIcons.photo, size: 20, color: _brand),
                            const SizedBox(width: 8),
                            Text(
                              'Add image',
                              style: TextStyle(
                                color: CupertinoColors.placeholderText.resolveFrom(context),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              if (_selectedImage != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Image will be blurred until someone buys this ticket',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Category',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final picked = await showCupertinoModalPopup<String>(
                    context: context,
                    builder: (ctx) => CupertinoActionSheet(
                      title: const Text('Select Category'),
                      actions: _categories.map((c) => CupertinoActionSheetAction(
                        onPressed: () => Navigator.pop(ctx, c),
                        child: Text(c),
                      )).toList(),
                      cancelButton: CupertinoActionSheetAction(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                  );
                  if (picked != null) {
                    setState(() => _selectedCategory = picked);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6.resolveFrom(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.tag, size: 20, color: _brand),
                      const SizedBox(width: 8),
                      Text(
                        _selectedCategory ?? 'Select category',
                        style: TextStyle(
                          color: _selectedCategory == null
                              ? CupertinoColors.placeholderText.resolveFrom(context)
                              : CupertinoColors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Quantity',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minSize: 0,
                    color: CupertinoColors.systemGrey5.resolveFrom(context),
                    borderRadius: BorderRadius.circular(8),
                    onPressed: _quantity <= 1
                        ? null
                        : () => setState(() => _quantity = (_quantity - 1).clamp(1, 999)),
                    child: const Text('-', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$_quantity',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 12),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minSize: 0,
                    color: CupertinoColors.systemGrey5.resolveFrom(context),
                    borderRadius: BorderRadius.circular(8),
                    onPressed: () => setState(() => _quantity = (_quantity + 1).clamp(1, 999)),
                    child: const Text('+', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Price (KES)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              CupertinoTextField(
                controller: _priceCtrl,
                placeholder: 'e.g. 500',
                keyboardType: TextInputType.number,
                padding: const EdgeInsets.all(12),
              ),
              const SizedBox(height: 20),
              const Text(
                'Expiry Date',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6.resolveFrom(context),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.calendar, size: 20, color: _brand),
                      const SizedBox(width: 8),
                      Text(
                        _expiryLabel,
                        style: TextStyle(
                          color: _expiryDate == null
                              ? CupertinoColors.placeholderText
                              : CupertinoColors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedImage() {
    final img = _selectedImage!;
    if (img.bytes != null) {
      return Image.memory(
        Uint8List.fromList(img.bytes!),
        width: 50,
        height: 50,
        fit: BoxFit.cover,
      );
    }
    if (img.fileLocalPath != null && File(img.fileLocalPath!).existsSync()) {
      return Image.file(
        File(img.fileLocalPath!),
        width: 50,
        height: 50,
        fit: BoxFit.cover,
      );
    }
    return const SizedBox(width: 50, height: 50);
  }
}
