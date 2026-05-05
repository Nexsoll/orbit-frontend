import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:super_up/app/core/api_service/emergency_contacts/emergency_contacts_api_service.dart';

class EmergencyContactsView extends StatefulWidget {
  const EmergencyContactsView({super.key});

  @override
  State<EmergencyContactsView> createState() => _EmergencyContactsViewState();
}

class _EmergencyContactsViewState extends State<EmergencyContactsView> {
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    try {
      final list = await EmergencyContactsApiService.getMyContacts();
      if (mounted) setState(() => _contacts = list);
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: 'Failed to load contacts: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAddDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relationCtrl = TextEditingController();

    await showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Add Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: nameCtrl,
              placeholder: 'Name',
              padding: const EdgeInsets.all(12),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: phoneCtrl,
              placeholder: 'Phone Number',
              keyboardType: TextInputType.phone,
              padding: const EdgeInsets.all(12),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: relationCtrl,
              placeholder: 'Relation (optional)',
              padding: const EdgeInsets.all(12),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              final relation = relationCtrl.text.trim();
              if (name.isEmpty || phone.isEmpty) {
                VAppAlert.showErrorSnackBar(context: context, message: 'Name and phone are required');
                return;
              }
              Navigator.of(ctx).pop();
              try {
                await EmergencyContactsApiService.addContact(
                  name: name,
                  phone: phone,
                  relation: relation.isEmpty ? null : relation,
                );
                if (mounted) {
                  VAppAlert.showSuccessSnackBar(context: context, message: 'Contact added');
                  _loadContacts();
                }
              } catch (e) {
                if (mounted) {
                  VAppAlert.showErrorSnackBar(context: context, message: 'Failed to add contact: $e');
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteContact(String id, String name) async {
    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to delete $name?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await EmergencyContactsApiService.deleteContact(id);
      if (mounted) {
        VAppAlert.showSuccessSnackBar(context: context, message: 'Contact deleted');
        _loadContacts();
      }
    } catch (e) {
      if (mounted) {
        VAppAlert.showErrorSnackBar(context: context, message: 'Failed to delete: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: isDark ? Colors.black : const Color(0xFFc9cfc8),
        middle: const Text('Emergency Contacts'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _showAddDialog,
          child: const Icon(CupertinoIcons.add, color: Color(0xFFB48648)),
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : _contacts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.phone_circle,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No emergency contacts yet',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        CupertinoButton(
                          onPressed: _showAddDialog,
                          child: const Text('Add Contact'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      final name = contact['name']?.toString() ?? '';
                      final phone = contact['phone']?.toString() ?? '';
                      final relation = contact['relation']?.toString();
                      final id = contact['_id']?.toString() ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? CupertinoColors.darkBackgroundGray : CupertinoColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: CupertinoColors.systemGrey4,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB48648).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                CupertinoIcons.person_fill,
                                color: Color(0xFFB48648),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    phone,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (relation != null && relation.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      relation,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade500,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => _deleteContact(id, name),
                              child: const Icon(
                                CupertinoIcons.trash,
                                color: CupertinoColors.systemRed,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
