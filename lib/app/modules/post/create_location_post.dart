import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:super_up/app/core/api_service/post/post_api_service.dart';
import 'package:super_up/app/modules/ride/views/location_search_view.dart';
import 'package:super_up_core/super_up_core.dart';

import 'post_caption_editor.dart';

const _kPrimary = Color(0xFFB48648);

class CreateLocationPost extends StatefulWidget {
  final String? initialCaption;

  const CreateLocationPost({super.key, this.initialCaption});

  @override
  State<CreateLocationPost> createState() => _CreateLocationPostState();
}

class _CreateLocationPostState extends State<CreateLocationPost> {
  final _postApiService = GetIt.I.get<PostApiService>();
  final _captionController = TextEditingController();

  LatLng? _pickedLatLng;
  String _placeName = '';
  String _address = '';
  bool _isPosting = false;

  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    if (widget.initialCaption != null) {
      _captionController.text = widget.initialCaption!;
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _openSearch() async {
    final result = await Navigator.of(context).push<LocationSearchResult>(
      CupertinoPageRoute(
        builder: (_) => const LocationSearchView(
          title: 'Search location',
          allowUseCurrentLocation: true,
        ),
      ),
    );
    if (result == null) return;
    await _setLocation(result.latLng, result.address);
  }

  Future<void> _setLocation(LatLng latLng, String address) async {
    String name = address;
    try {
      final marks = await geocoding.placemarkFromCoordinates(
          latLng.latitude, latLng.longitude);
      if (marks.isNotEmpty) {
        final m = marks.first;
        name = [m.name, m.locality, m.country]
            .where((s) => s != null && s.trim().isNotEmpty)
            .join(', ');
      }
    } catch (_) {}

    setState(() {
      _pickedLatLng = latLng;
      _placeName = name;
      _address = address;
    });

    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
  }

  Future<void> _onMapTap(LatLng pos) async {
    await _setLocation(pos, '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
  }

  Future<void> _submitPost() async {
    if (_pickedLatLng == null) {
      VAppAlert.showErrorSnackBar(
          context: context, message: 'Please select a location first');
      return;
    }

    final caption = _captionController.text.trim();
    final location = {
      'latitude': _pickedLatLng!.latitude,
      'longitude': _pickedLatLng!.longitude,
      'address': _address,
      'placeName': _placeName,
    };

    await vSafeApiCall(
      onLoading: () {
        setState(() => _isPosting = true);
      },
      request: () => _postApiService.createLocationPost(
        caption: caption,
        location: location,
      ),
      onSuccess: (_) {
        if (mounted) {
          setState(() => _isPosting = false);
          PostApiService.notifySocialFeedRefresh();
          Navigator.of(context).pop(true);
        }
      },
      onError: (e, _) {
        setState(() => _isPosting = false);
        VAppAlert.showErrorSnackBar(context: context, message: e.toString());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final fg = isDark ? Colors.white : Colors.black87;

    return SafeArea(
      child: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search bar
                  GestureDetector(
                    onTap: _openSearch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8)
                        ],
                      ),
                      child: Row(children: [
                        const Icon(Icons.search, color: _kPrimary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _pickedLatLng == null
                                ? 'Search for a place…'
                                : _placeName.isNotEmpty
                                    ? _placeName
                                    : _address,
                            style: TextStyle(
                              color: _pickedLatLng == null
                                  ? fg.withValues(alpha: 0.4)
                                  : fg,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_pickedLatLng != null)
                          GestureDetector(
                            onTap: () => setState(() {
                              _pickedLatLng = null;
                              _placeName = '';
                              _address = '';
                            }),
                            child: Icon(Icons.close,
                                size: 18,
                                color: fg.withValues(alpha: 0.4)),
                          ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Map preview
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 240,
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _pickedLatLng ?? const LatLng(0, 0),
                          zoom: _pickedLatLng != null ? 14 : 2,
                        ),
                        onMapCreated: (c) => _mapController = c,
                        onTap: _onMapTap,
                        markers: _pickedLatLng != null
                            ? {
                                Marker(
                                  markerId: const MarkerId('selected'),
                                  position: _pickedLatLng!,
                                  infoWindow: InfoWindow(
                                    title: _placeName.isNotEmpty
                                        ? _placeName
                                        : 'Selected',
                                  ),
                                )
                              }
                            : {},
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                      ),
                    ),
                  ),

                  if (_pickedLatLng != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _kPrimary.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.location_on,
                            color: _kPrimary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_placeName.isNotEmpty)
                                  Text(_placeName,
                                      style: TextStyle(
                                          color: fg,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                Text(_address,
                                    style: TextStyle(
                                        color: fg.withValues(alpha: 0.55),
                                        fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ]),
                        ),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 20),
                  Text('Caption (optional)',
                      style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  const SizedBox(height: 8),
                  PostCaptionEditor(
                    controller: _captionController,
                    textColor: fg,
                    placeholderColor: fg.withValues(alpha: 0.4),
                    highlightColor: _kPrimary,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8)
                      ],
                    ),
                  ),
                ]),
          ),
        ),

        // Post button
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isPosting || _pickedLatLng == null
                    ? null
                    : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      _kPrimary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: _isPosting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.location_on, size: 20),
                label: Text(
                  _isPosting ? 'Posting…' : 'Post Location',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
