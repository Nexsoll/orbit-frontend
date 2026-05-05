import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_up/app/core/api_service/drivers/drivers_api_service.dart';
import 'package:super_up_core/super_up_core.dart';

class VehicleDetailsView extends StatefulWidget {
  const VehicleDetailsView({super.key});

  @override
  State<VehicleDetailsView> createState() => _VehicleDetailsViewState();
}

class _VehicleDetailsViewState extends State<VehicleDetailsView> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final latest = await DriversApiService.myLatest();
      if (!mounted) return;
      setState(() {
        _data = latest;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load vehicle details';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final navBar = CupertinoNavigationBar(
      transitionBetweenRoutes: false,
      leading: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.of(context).pop(),
        child: const Row(
          children: [
            Icon(CupertinoIcons.chevron_back, color: Color(0xFFB48648)),
            SizedBox(width: 2),
            Text('Back', style: TextStyle(color: Color(0xFFB48648))),
          ],
        ),
      ),
      middle: const Text('Vehicle Details'),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _fetch,
        child: const Icon(CupertinoIcons.refresh, color: Color(0xFFB48648)),
      ),
    );

    final body = _buildBody(context);

    return CupertinoPageScaffold(
      navigationBar: navBar,
      child: SafeArea(top: false, child: body),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            CupertinoButton(
              onPressed: _fetch,
              child: const Text('Retry'),
            )
          ],
        ),
      );
    }
    if (_data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(CupertinoIcons.car_detailed, size: 40),
            SizedBox(height: 8),
            Text('No vehicle details found'),
          ],
        ),
      );
    }

    final d = _data!;
    String s(Object? v) => (v == null || (v is String && v.isEmpty)) ? '-' : v.toString();

    final items = [
      _InfoRow(label: 'Status', value: s(d['status'])),
      _InfoRow(label: 'Vehicle Type', value: s(d['vehicleType'])),
      _InfoRow(label: 'Vehicle Model', value: s(d['vehicleModel'])),
      _InfoRow(label: 'Plate Number', value: s(d['vehiclePlate'])),
      _InfoRow(label: 'Capacity', value: s(d['vehicleCapacity'])),
      _InfoRow(label: 'Submitted At', value: s(d['createdAt'])),
    ];

    final docs = [
      if (s(d['licenseUrl']) != '-') _DocRow(label: 'Driving License', url: d['licenseUrl']),
      if (s(d['logbookUrl']) != '-') _DocRow(label: 'Logbook', url: d['logbookUrl']),
      if (s(d['insuranceUrl']) != '-') _DocRow(label: 'Insurance', url: d['insuranceUrl']),
      if (s(d['inspectionUrl']) != '-') _DocRow(label: 'Inspection', url: d['inspectionUrl']),
      if (s(d['kraPinUrl']) != '-') _DocRow(label: 'KRA PIN', url: d['kraPinUrl']),
      if (s(d['idImageUrl']) != '-') _DocRow(label: 'ID', url: d['idImageUrl']),
      if (s(d['selfieImageUrl']) != '-') _DocRow(label: 'Selfie', url: d['selfieImageUrl']),
      if (s(d['vehicleImageUrl']) != '-') _DocRow(label: 'Vehicle Photo', url: d['vehicleImageUrl']),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
          ),
          child: Column(children: items),
        ),
        if (docs.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...docs,
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  final String label;
  final String url;
  const _DocRow({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(CupertinoIcons.doc_text, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            onPressed: () {
              VAppAlert.showSuccessSnackBar(
                context: context,
                message: 'Opening…',
              );
              // Optionally open in webview or external browser
              // launchUrl(Uri.parse(url));
            },
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}
