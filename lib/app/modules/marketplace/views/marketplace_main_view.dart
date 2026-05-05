import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:file_picker/file_picker.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:v_platform/v_platform.dart';
import 'package:super_up/app/core/services/location_service.dart';
import 'package:super_up/app/modules/ride/views/location_search_view.dart';
import 'package:super_up/app/core/services/user_files_service.dart';
import 'package:super_up/app/modules/marketplace/services/marketplace_api_service.dart';
import 'package:super_up/app/modules/marketplace/views/create_marketplace_listing_view.dart';
import 'package:super_up/app/modules/marketplace/views/marketplace_my_listings_view.dart';
import 'package:super_up/app/modules/marketplace/views/marketplace_category_feed_view.dart';
import 'package:super_up/app/modules/marketplace/views/marketplace_listing_details_view.dart';
import 'package:super_up/app/modules/marketplace/views/marketplace_profile_view.dart';
import 'package:super_up/app/modules/marketplace/views/marketplace_search_view.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:super_up/app/core/app_config/app_config_controller.dart';
import 'package:super_up/app/core/services/balance_service.dart';
import 'package:v_chat_sdk_core/v_chat_sdk_core.dart';

import 'marketplace_map_preview_view.dart';

enum _SellerStatus {
  approved,
}

class MarketplaceMainView extends StatefulWidget {
  const MarketplaceMainView({super.key});

  @override
  State<MarketplaceMainView> createState() => _MarketplaceMainViewState();
}

class _MarketplaceMainViewState extends State<MarketplaceMainView> {
  int _selectedTabIndex = 1; // 0: Sell, 1: For you (default), 2: Categories, 3: Filters
  int _sellerTab = 0; // 0: Tools, 1: Analytics
  StreamSubscription? _unReadSub;
  int _marketplaceUnreadRooms = 0;
  bool _refreshingUnread = false;
  String? _locationLabel;
  double? _locationLat;
  double? _locationLng;
  bool _loadingLocation = false;
  int _selectedCategoryFilterIndex = 0; // 0: Trending, 1: Recently Posted
  double _radiusKm = 10;
  int? _minPrice;
  int? _maxPrice;
  String? _condition;
  final TextEditingController _minPriceCtrl = TextEditingController();
  final TextEditingController _maxPriceCtrl = TextEditingController();
  _SellerStatus _sellerStatus = _SellerStatus.approved;
  String? _sellerIdFileName;
  bool _isUploadingSellerId = false;

  late final MarketplaceApiService _marketApi;

  num _soldEarnings = 0;
  bool _loadingSoldEarnings = false;

  bool _loadingAnalytics = false;
  String? _analyticsError;
  Map<String, dynamic>? _analytics;
  bool _loadingFeed = false;
  String? _feedError;
  List<Map<String, dynamic>> _feedItems = const [];

  // Promotion state
  bool _loadingPromotion = false;
  List<Map<String, dynamic>> _publishedListings = [];
  List<Map<String, dynamic>> _myPromotedListings = [];
  double _promotionWeeklyFee = 100;
  double _promotionMonthlyFee = 350;

  // Featured listings for home feed
  List<Map<String, dynamic>> _featuredListings = [];
  bool _loadingFeatured = false;

  String _formatSellerIdUploadError(Object e) {
    final msg = e.toString().replaceFirst('Exception: ', '').trim();
    if (msg.contains('no URL returned')) {
      return 'Upload failed. Please check your internet connection and try again.';
    }
    if (msg.startsWith('Error uploading files:')) {
      return msg.replaceFirst('Error uploading files:', '').trim();
    }
    return msg.isEmpty ? 'Upload failed. Please try again.' : msg;
  }

  Future<void> _pickAndUploadingHelper(Future<void> Function() action) async {
    if (!mounted) return;
    setState(() => _isUploadingSellerId = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _isUploadingSellerId = false);
      }
    }
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    double toRad(double d) => d * 3.141592653589793 / 180.0;
    final dLat = toRad(lat2 - lat1);
    final dLng = toRad(lng2 - lng1);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(toRad(lat1)) * cos(toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  Future<void> _loadAnalytics() async {
    if (_loadingAnalytics) return;
    if (!mounted) return;
    setState(() {
      _loadingAnalytics = true;
      _analyticsError = null;
    });
    try {
      final data = await _marketApi.myAnalytics();
      if (!mounted) return;
      setState(() {
        _analytics = data;
        _loadingAnalytics = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analyticsError = e.toString();
        _loadingAnalytics = false;
      });
    }
  }

  Future<void> _loadPromotionData() async {
    if (_loadingPromotion) return;
    if (!mounted) return;
    setState(() => _loadingPromotion = true);
    try {
      // Refresh app config to get latest promotion fees
      await GetIt.I.get<VAppConfigController>().refreshAppConfig();
      final results = await Future.wait([
        _marketApi.getPublishedListingsForPromotion(),
        _marketApi.getMyPromotedListings(),
      ]);
      // Load promotion fees from fresh app config
      try {
        final cfg = VAppConfigController.appConfig;
        _promotionWeeklyFee = cfg.marketplacePromotionWeeklyFee ?? 100;
        _promotionMonthlyFee = cfg.marketplacePromotionMonthlyFee ?? 350;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _publishedListings = results[0];
        _myPromotedListings = results[1];
        _loadingPromotion = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPromotion = false);
      VAppAlert.showErrorSnackBar(message: e.toString(), context: context);
    }
  }

  Future<void> _loadFeaturedListings() async {
    if (_loadingFeatured) return;
    if (!mounted) return;
    setState(() => _loadingFeatured = true);
    try {
      final data = await _marketApi.getFeaturedListings(limit: 10);
      if (!mounted) return;
      setState(() {
        _featuredListings = data;
        _loadingFeatured = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingFeatured = false);
    }
  }

  String _norm(String s) {
    return s.trim().toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '');
  }

  List<Map<String, dynamic>> _applyLocalConditionFilter(List<Map<String, dynamic>> items) {
    final c = (_condition ?? '').trim();
    if (c.isEmpty) return items;
    final target = _norm(c);
    return items.where((it) {
      final v = (it['condition'] ?? '').toString();
      if (v.trim().isEmpty) return false;
      return _norm(v) == target;
    }).toList();
  }

  int _hash(String s) {
    var h = 0;
    for (final cu in s.codeUnits) {
      h = 0x1fffffff & (h + cu);
      h = 0x1fffffff & (h + ((0x0007ffff & h) << 10));
      h ^= (h >> 6);
    }
    h = 0x1fffffff & (h + ((0x03ffffff & h) << 3));
    h ^= (h >> 11);
    h = 0x1fffffff & (h + ((0x00003fff & h) << 15));
    return h;
  }

  int _listingTimeMs(Map<String, dynamic> it) {
    final v = it['publishedAt'] ?? it['createdAt'];
    if (v is num) return v.toInt();
    if (v is String) {
      try {
        return DateTime.parse(v).millisecondsSinceEpoch;
      } catch (_) {
        return 0;
      }
    }
    return 0;
  }

  List<Map<String, dynamic>> _applySort(List<Map<String, dynamic>> items) {
    if (items.length < 2) return items;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 0 = Trending Items, 1 = Recently Posted
    if (_selectedCategoryFilterIndex == 1) {
      final out = List<Map<String, dynamic>>.from(items);
      out.sort((a, b) => _listingTimeMs(b).compareTo(_listingTimeMs(a)));
      return out;
    }

    // Trending: bias to newer posts but shuffle deterministically by id
    double score(Map<String, dynamic> it) {
      final id = (it['_id'] ?? it['id'] ?? it['title'] ?? '').toString();
      final t = _listingTimeMs(it);
      final ageH = t <= 0 ? 1e6 : ((now - t) / 3600000.0);
      final recency = 1.0 / (1.0 + (ageH / 12.0)); // 12h half-life-ish
      final rnd = (_hash(id) % 1000) / 1000.0;
      return (recency * 0.85) + (rnd * 0.15);
    }

    final out = List<Map<String, dynamic>>.from(items);
    out.sort((a, b) => score(b).compareTo(score(a)));
    return out;
  }

  List<Map<String, dynamic>> _applyLocalDistanceFilter(List<Map<String, dynamic>> items) {
    final lat = _locationLat;
    final lng = _locationLng;
    if (lat == null || lng == null) return items;
    final radius = _radiusKm;
    if (radius <= 0) return items;

    return items.where((it) {
      final dLat = (it['locationLat'] as num?)?.toDouble();
      final dLng = (it['locationLng'] as num?)?.toDouble();
      if (dLat == null || dLng == null) return false;
      return _haversineKm(lat, lng, dLat, dLng) <= radius;
    }).toList();
  }

  List<Map<String, dynamic>> _applyLocalPriceFilter(List<Map<String, dynamic>> items) {
    final minP = _minPrice;
    final maxP = _maxPrice;
    if (minP == null && maxP == null) return items;

    return items.where((it) {
      final p = (it['price'] as num?)?.toInt();
      if (p == null) return false;
      if (minP != null && p < minP) return false;
      if (maxP != null && p > maxP) return false;
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _unReadSub?.cancel();
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    super.dispose();
  }

  Widget _headerBadge(int count) {
    if (count <= 0) return const SizedBox.shrink();
    return PositionedDirectional(
      end: -2,
      top: -2,
      child: Container(
        width: 14,
        height: 14,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _marketApi = GetIt.I.get<MarketplaceApiService>();
    unawaited(_loadSoldEarnings());
    unawaited(_loadAnalytics());
    unawaited(_loadFeaturedListings());
    _loadLocation();
    _loadSellerStatus();
    _loadForYouFeed();
    _listenMarketplaceUnread();
  }

  Future<void> _loadSoldEarnings() async {
    if (_loadingSoldEarnings) return;
    if (mounted) {
      setState(() => _loadingSoldEarnings = true);
    } else {
      _loadingSoldEarnings = true;
    }
    try {
      final items = await _marketApi.myListings(status: 'published');
      num total = 0;
      for (final it in items) {
        final isSold = (it['isSold'] == true) ||
            (it['isSold']?.toString().trim().toLowerCase() == 'true');
        if (!isSold) continue;
        final v = it['soldPrice'] ?? it['price'];
        final n = v is num ? v : num.tryParse(v?.toString() ?? '');
        if (n != null && n > 0) total += n;
      }
      if (!mounted) return;
      setState(() => _soldEarnings = total);
    } catch (_) {
      // ignore
    } finally {
      if (!mounted) return;
      setState(() => _loadingSoldEarnings = false);
    }
  }

  Future<void> _showEarningsDialog() async {
    await _loadSoldEarnings();
    if (!mounted) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) {
        return CupertinoAlertDialog(
          title: const Text('Your earnings'),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Sold items total: ${_formatKes(_soldEarnings)}'),
                const SizedBox(height: 8),
                const Text(
                  'To withdraw, go to Settings > Withdraw.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _listenMarketplaceUnread() {
    unawaited(_refreshMarketplaceUnread());
    try {
      _unReadSub?.cancel();
      _unReadSub = VChatController.I.nativeApi.streams.messageStream
          .where((e) => e is VInsertMessageEvent)
          .listen((_) {
        unawaited(_refreshMarketplaceUnread());
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _refreshMarketplaceUnread() async {
    if (_refreshingUnread) return;
    _refreshingUnread = true;
    try {
      final rooms = await VChatController.I.nativeApi.local.room.getRooms(
        limit: 200,
      );
      final count = rooms
          .where(
            (r) =>
                r.roomType == VRoomType.o &&
                !r.isArchived &&
                (r.unReadCount) > 0,
          )
          .length;
      if (!mounted) return;
      if (_marketplaceUnreadRooms != count) {
        setState(() => _marketplaceUnreadRooms = count);
      }
    } catch (_) {
      // ignore
    } finally {
      _refreshingUnread = false;
    }
  }

  Future<void> _loadForYouFeed() async {
    if (!mounted) return;
    setState(() {
      _loadingFeed = true;
      _feedError = null;
    });
    try {
      final list = await _marketApi.feed(
        limit: 40,
        lat: _locationLat,
        lng: _locationLng,
        radiusKm: (_locationLat != null && _locationLng != null) ? _radiusKm : null,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        condition: _condition,
      );
      if (!mounted) return;
      var filtered = _applyLocalDistanceFilter(list);
      filtered = _applyLocalPriceFilter(filtered);
      filtered = _applyLocalConditionFilter(filtered);
      filtered = _applySort(filtered);
      setState(() {
        _feedItems = filtered;
        _loadingFeed = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedError = e.toString();
        _loadingFeed = false;
      });
    }
  }

  Future<void> _loadLocation() async {
    setState(() {
      _loadingLocation = true;
    });
    try {
      final pos = await LocationService.instance.getCurrentLocation();
      if (!mounted) return;
      if (pos == null) {
        setState(() {
          _locationLabel = 'Set location';
          _locationLat = null;
          _locationLng = null;
          _loadingLocation = false;
        });
        return;
      }
      final placemarks =
          await geocoding.placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (!mounted) return;
      final p = placemarks.isNotEmpty ? placemarks.first : null;
      final city = (p?.locality?.isNotEmpty ?? false)
          ? p!.locality
          : (p?.subAdministrativeArea?.isNotEmpty ?? false)
              ? p!.subAdministrativeArea
              : (p?.administrativeArea?.isNotEmpty ?? false)
                  ? p!.administrativeArea
                  : null;
      final country = (p?.country?.isNotEmpty ?? false) ? p!.country : null;
      final parts = <String>[];
      if (city != null) parts.add(city);
      if (country != null) parts.add(country);
      setState(() {
        _locationLabel = parts.isNotEmpty ? parts.join(', ') : 'Current location';
        _locationLat = pos.latitude;
        _locationLng = pos.longitude;
        _loadingLocation = false;
      });

      if (_selectedTabIndex == 1) {
        await _loadForYouFeed();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationLabel = 'Set location';
        _locationLat = null;
        _locationLng = null;
        _loadingLocation = false;
      });
    }
  }

  Future<void> _loadSellerStatus() async {
    if (!mounted) return;
    setState(() {
      _sellerStatus = _SellerStatus.approved;
    });
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<LocationSearchResult>(
      CupertinoPageRoute(
        builder: (_) => const LocationSearchView(
          title: 'Choose location',
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _locationLabel = result.address;
        _locationLat = result.latLng.latitude;
        _locationLng = result.latLng.longitude;
      });

      if (_selectedTabIndex == 1) {
        await _loadForYouFeed();
      }
    }
  }

  void _onTabSelected(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
    if (index == 1 && !_loadingFeed && _feedItems.isEmpty) {
      _loadForYouFeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return CupertinoPageScaffold(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            const SizedBox(height: 12),
            _buildTabs(theme),
            const SizedBox(height: 16),
            _buildSectionHeader(theme),
            const SizedBox(height: 8),
            Expanded(
              child: _buildTabBody(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody(CupertinoThemeData theme) {
    if (_selectedTabIndex == 0) {
      return _buildSellCtaBody(theme);
    }
    if (_selectedTabIndex == 2) {
      return _buildCategoriesList(theme);
    }
    if (_selectedTabIndex == 3) {
      return _buildFiltersBody(theme);
    }
    return _buildItemsGrid(theme);
  }

  Widget _buildFiltersBody(CupertinoThemeData theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _filterCard(
          child: _buildCategoryFilters(theme),
        ),
        const SizedBox(height: 18),
        _filterCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Distance',
                style: theme.textTheme.textStyle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _locationLat == null || _locationLng == null
                    ? 'Set a location first to filter nearby listings.'
                    : 'Showing listings within ${_radiusKm.round()} km',
                style: theme.textTheme.textStyle.copyWith(
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoSlider(
                min: 1,
                max: 50,
                value: _radiusKm.clamp(1, 50),
                onChanged: (_locationLat == null || _locationLng == null)
                    ? null
                    : (v) {
                        setState(() => _radiusKm = v);
                      },
                onChangeEnd: (_locationLat == null || _locationLng == null)
                    ? null
                    : (_) {
                        _loadForYouFeed();
                      },
              ),
              const SizedBox(height: 10),
              Text(
                'Tip: change your location from the top bar to see nearby listings.',
                style: theme.textTheme.textStyle.copyWith(
                  fontSize: 13,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: CupertinoColors.systemGrey5,
            onPressed: () async {
              await _loadForYouFeed();
              if (!mounted) return;
              await Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => MarketplaceMapPreviewView(
                    listings: List<Map<String, dynamic>>.from(_feedItems),
                    centerLat: _locationLat,
                    centerLng: _locationLng,
                  ),
                ),
              );
            },
            child: const Text('Map preview'),
          ),
        ),
      ],
    );
  }

  Widget _filterCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: CupertinoColors.systemGrey4,
          width: 0.5,
        ),
      ),
      child: child,
    );
  }

  Widget _buildCategoryFilters(CupertinoThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildCategoryFilterChip(
          label: 'Trending Items',
          index: 0,
          theme: theme,
        ),
        _buildCategoryFilterChip(
          label: 'Recently Posted',
          index: 1,
          theme: theme,
        ),
        GestureDetector(
          onTap: _openAdvancedFilters,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.slider_horizontal_3,
                  size: 16,
                  color: Color(0xFFB48648),
                ),
                const SizedBox(width: 4),
                Text(
                  'Advanced Filters',
                  style: theme.textTheme.textStyle.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSellCtaBody(CupertinoThemeData theme) {
    final child = _buildSellerDashboardCard(theme);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: child,
    );
  }

  Widget _buildSellApplyCard(CupertinoThemeData theme) {
    return _buildSellerCardContainer(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFB48648).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.bag_badge_plus,
                  size: 30,
                  color: Color(0xFFB48648),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Become a seller and earn with Orbit Business',
                      style: theme.textTheme.textStyle.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF4A3215),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Turn your items into income and reach thousands of Orbit users nearby.',
                      style: theme.textTheme.textStyle.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF5E4732),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _SellHeroChip(icon: CupertinoIcons.sparkles, label: 'Featured exposure'),
              _SellHeroChip(icon: CupertinoIcons.location_solid, label: 'Local buyers nearby'),
              _SellHeroChip(icon: CupertinoIcons.checkmark_seal, label: 'Trusted verification'),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSellFeatureRow(
                theme,
                icon: CupertinoIcons.bolt_fill,
                text:
                    'List your products in minutes and appear in buyer searches.',
              ),
              const SizedBox(height: 8),
              _buildSellFeatureRow(
                theme,
                icon: CupertinoIcons.chat_bubble_2_fill,
                text:
                    'Chat with buyers and manage deals directly inside Orbit Chat.',
              ),
              const SizedBox(height: 8),
              _buildSellFeatureRow(
                theme,
                icon: CupertinoIcons.checkmark_seal_fill,
                text: 'Get a verified seller badge to build instant trust.',
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: _isUploadingSellerId ? null : _onBecomeSellerPressed,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10,
              ),
              child: _isUploadingSellerId
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CupertinoActivityIndicator(),
                        SizedBox(width: 8),
                        Text(
                          'Uploading ID…',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  : const Text(
                      'Become a seller',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellInReviewCard(CupertinoThemeData theme) {
    return _buildSellerCardContainer(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFB48648).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.clock_solid,
                  size: 26,
                  color: Color(0xFFB48648),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seller verification in review',
                      style: theme.textTheme.textStyle.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'We are reviewing your application. You will be notified once approved.',
                      style: theme.textTheme.textStyle.copyWith(
                        fontSize: 13,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_sellerIdFileName != null)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB48648).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ID: $_sellerIdFileName',
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFB48648),
                    ),
                  ),
                ),
              ],
            ),
          if (_sellerIdFileName != null) const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: CupertinoColors.systemGrey4,
              onPressed: _loadSellerStatus,
              child: const Text('Refresh status'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerDashboardCard(CupertinoThemeData theme) {
    return _buildSellerCardContainer(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seller tools',
            style: theme.textTheme.textStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<int>(
              groupValue: _sellerTab,
              onValueChanged: (v) {
                if (v == null) return;
                setState(() => _sellerTab = v);
                if (v == 1) {
                  unawaited(_loadAnalytics());
                }
                if (v == 2) {
                  unawaited(_loadPromotionData());
                }
              },
              children: const {
                0: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text('Tools'),
                ),
                1: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text('Analytics'),
                ),
                2: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Text('Promote'),
                ),
              },
            ),
          ),
          const SizedBox(height: 12),
          if (_sellerTab == 0)
            Row(
              children: [
                _buildSellerToolTile(
                  theme,
                  icon: CupertinoIcons.add_circled_solid,
                  label: 'Add listing',
                  onTap: () {
                    Navigator.of(context)
                        .push<bool>(
                      CupertinoPageRoute(
                        builder: (_) => const CreateMarketplaceListingView(),
                      ),
                    )
                        .then((changed) {
                      if (changed == true) {
                        _loadForYouFeed();
                      }
                      unawaited(_loadSoldEarnings());
                      unawaited(_loadAnalytics());
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildSellerToolTile(
                  theme,
                  icon: CupertinoIcons.list_bullet,
                  label: 'Your listings',
                  onTap: () {
                    Navigator.of(context)
                        .push<bool>(
                      CupertinoPageRoute(
                        builder: (_) => const MarketplaceMyListingsView(),
                      ),
                    )
                        .then((_) {
                      _loadForYouFeed();
                      unawaited(_loadSoldEarnings());
                      unawaited(_loadAnalytics());
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildSellerToolTile(
                  theme,
                  icon: CupertinoIcons.money_dollar_circle_fill,
                  label: 'Your earnings',
                  subtitle: _loadingSoldEarnings ? '...' : _formatKes(_soldEarnings),
                  onTap: _showEarningsDialog,
                ),
              ],
            ),
          if (_sellerTab == 1)
            _buildAnalyticsBody(theme),
          if (_sellerTab == 2)
            _buildPromoteBody(theme),
        ],
      ),
    );
  }

  Widget _buildPromoteBody(CupertinoThemeData theme) {
    if (_loadingPromotion) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    // Filter out already promoted listings
    final promotedIds = _myPromotedListings.map((l) => l['_id'] ?? l['id']).toSet();
    final availableListings = _publishedListings
        .where((l) => !promotedIds.contains(l['_id'] ?? l['id']))
        .where((l) => l['isPromoted'] != true)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pricing info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFB48648).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.star_fill, color: Color(0xFFB48648), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Promote your listing to Featured',
                      style: theme.textTheme.textStyle.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '7 Days: KSh ${_promotionWeeklyFee.toStringAsFixed(0)} • 30 Days: KSh ${_promotionMonthlyFee.toStringAsFixed(0)}',
                      style: theme.textTheme.textStyle.copyWith(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Currently promoted listings
        if (_myPromotedListings.isNotEmpty) ...[
          Text(
            'Your promoted listings',
            style: theme.textTheme.textStyle.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ..._myPromotedListings.map((listing) => _buildPromotedListingTile(theme, listing)),
          const SizedBox(height: 16),
        ],

        // Available listings to promote
        Text(
          'Select a listing to promote',
          style: theme.textTheme.textStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        if (availableListings.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'No published listings available to promote.\nCreate and publish a listing first.',
                textAlign: TextAlign.center,
                style: theme.textTheme.textStyle.copyWith(
                  color: CupertinoColors.systemGrey,
                  fontSize: 13,
                ),
              ),
            ),
          )
        else
          ...availableListings.map((listing) => _buildListingToPromoteTile(theme, listing)),
      ],
    );
  }

  Widget _buildPromotedListingTile(CupertinoThemeData theme, Map<String, dynamic> listing) {
    final title = (listing['title'] ?? 'Untitled').toString();
    final media = listing['media'] as List?;
    final firstImage = media?.isNotEmpty == true ? (media!.first['url'] ?? '').toString() : '';
    final expiresAt = listing['promotionExpiresAt'] != null
        ? DateTime.tryParse(listing['promotionExpiresAt'].toString())
        : null;
    final plan = (listing['promotionPlan'] ?? '').toString();
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isExpired ? CupertinoColors.systemRed.withValues(alpha: 0.1) : CupertinoColors.systemGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isExpired ? CupertinoColors.systemRed.withValues(alpha: 0.3) : CupertinoColors.systemGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: firstImage.isNotEmpty
                ? VPlatformCacheImageWidget(
                    source: VPlatformFile.fromUrl(networkUrl: firstImage),
                    fit: BoxFit.cover,
                    size: const Size(44, 44),
                  )
                : Container(
                    width: 44,
                    height: 44,
                    color: CupertinoColors.systemGrey5,
                    child: const Icon(CupertinoIcons.photo, size: 20),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.textStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isExpired
                      ? 'Expired'
                      : 'Active until ${expiresAt != null ? DateFormat('MMM d').format(expiresAt) : 'N/A'} (${plan == 'weekly' ? '7d' : '30d'})',
                  style: theme.textTheme.textStyle.copyWith(
                    fontSize: 11,
                    color: isExpired ? CupertinoColors.systemRed : CupertinoColors.systemGreen,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFB48648),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'FEATURED',
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingToPromoteTile(CupertinoThemeData theme, Map<String, dynamic> listing) {
    final title = (listing['title'] ?? 'Untitled').toString();
    final price = listing['price'];
    final media = listing['media'] as List?;
    final firstImage = media?.isNotEmpty == true ? (media!.first['url'] ?? '').toString() : '';
    final listingId = (listing['_id'] ?? listing['id']).toString();

    return GestureDetector(
      onTap: () => _showPromoteDialog(listingId, title),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: firstImage.isNotEmpty
                  ? VPlatformCacheImageWidget(
                      source: VPlatformFile.fromUrl(networkUrl: firstImage),
                      fit: BoxFit.cover,
                      size: const Size(44, 44),
                    )
                  : Container(
                      width: 44,
                      height: 44,
                      color: CupertinoColors.systemGrey5,
                      child: const Icon(CupertinoIcons.photo, size: 20),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.textStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (price != null)
                    Text(
                      'KSh $price',
                      style: theme.textTheme.textStyle.copyWith(
                        fontSize: 12,
                        color: const Color(0xFFB48648),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.star,
              color: Color(0xFFB48648),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPromoteDialog(String listingId, String title) async {
    String selectedPlan = 'weekly';
    final balance = BalanceService.instance.balance;

    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final fee = selectedPlan == 'weekly' ? _promotionWeeklyFee : _promotionMonthlyFee;
          final canAfford = balance >= fee;

          return CupertinoActionSheet(
            title: Text('Promote "$title"'),
            message: Column(
              children: [
                const SizedBox(height: 8),
                Text('Wallet Balance: KSh ${balance.toStringAsFixed(0)}'),
                const SizedBox(height: 12),
                CupertinoSlidingSegmentedControl<String>(
                  groupValue: selectedPlan,
                  onValueChanged: (v) {
                    if (v != null) setModalState(() => selectedPlan = v);
                  },
                  children: {
                    'weekly': Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text('7 Days - KSh ${_promotionWeeklyFee.toStringAsFixed(0)}'),
                    ),
                    'monthly': Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text('30 Days - KSh ${_promotionMonthlyFee.toStringAsFixed(0)}'),
                    ),
                  },
                ),
                const SizedBox(height: 8),
                if (!canAfford)
                  const Text(
                    'Insufficient balance. Top up your wallet first.',
                    style: TextStyle(color: CupertinoColors.destructiveRed, fontSize: 12),
                  ),
              ],
            ),
            actions: [
              CupertinoActionSheetAction(
                onPressed: canAfford
                    ? () {
                        Navigator.of(ctx).pop();
                        _processPromotion(listingId, selectedPlan, fee);
                      }
                    : () {},
                child: Text(
                  'Pay KSh ${fee.toStringAsFixed(0)} from Wallet',
                  style: TextStyle(
                    color: canAfford ? CupertinoColors.activeBlue : CupertinoColors.systemGrey,
                  ),
                ),
              ),
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _showMpesaPaymentDialog(listingId, selectedPlan, fee);
                },
                child: Text('Pay KSh ${fee.toStringAsFixed(0)} via M-Pesa'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          );
        },
      ),
    );
  }

  Future<void> _processPromotion(String listingId, String plan, double fee) async {
    VAppAlert.showLoading(context: context);
    try {
      // Deduct from wallet
      await BalanceService.instance.subtractFromBalance(fee);

      // Promote the listing
      await _marketApi.promoteListing(
        listingId: listingId,
        plan: plan,
        paidAmount: fee,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading
      VAppAlert.showSuccessSnackBar(
        message: 'Listing promoted successfully!',
        context: context,
      );

      // Reload promotion data
      await _loadPromotionData();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading
      VAppAlert.showErrorSnackBar(message: e.toString(), context: context);
    }
  }

  Future<void> _showMpesaPaymentDialog(String listingId, String plan, double fee) async {
    final phoneCtrl = TextEditingController();
    try {
      final myPhone = AppAuth.myProfile.phoneNumber;
      if (myPhone != null && myPhone.isNotEmpty) {
        phoneCtrl.text = myPhone;
      }
    } catch (_) {}

    await showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('M-Pesa Payment'),
        content: Column(
          children: [
            const SizedBox(height: 12),
            Text('Amount: KSh ${fee.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: phoneCtrl,
              placeholder: 'M-Pesa phone (07XXXXXXXX)',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            const Text(
              'You will receive an M-Pesa STK push to authorize payment.',
              style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              final phone = phoneCtrl.text.trim();
              if (phone.isEmpty) {
                VAppAlert.showErrorSnackBar(message: 'Enter phone number', context: context);
                return;
              }
              Navigator.of(ctx).pop();
              await _initiateMpesaPromotion(listingId, plan, fee, phone);
            },
            child: const Text('Pay'),
          ),
        ],
      ),
    );
  }

  Future<void> _initiateMpesaPromotion(String listingId, String plan, double fee, String phone) async {
    VAppAlert.showLoading(context: context, message: 'Initiating M-Pesa payment...');
    try {
      // Initiate M-Pesa STK push
      final url = Uri.parse('${SConstants.sApiBaseUrl}/payments/mpesa/stk/initiate');
      final accessToken = VAppPref.getHashedString(key: SStorageKeys.vAccessToken.name);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };
      final body = jsonEncode({
        'amount': fee,
        'phone': phone,
        'accountReference': 'PROMO-$listingId',
        'description': 'Marketplace listing promotion',
      });

      final res = await http.post(url, headers: headers, body: body);
      if (res.statusCode != 200) {
        throw Exception('Failed to initiate payment');
      }

      final parsed = jsonDecode(res.body) as Map<String, dynamic>;
      if ((parsed['code'] as int?) != 2000) {
        throw Exception(parsed['message'] ?? 'Payment initiation failed');
      }

      final txData = parsed['data'] as Map<String, dynamic>;
      final txId = txData['id'] as String?;

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading

      // Show polling dialog
      if (txId != null) {
        await _pollMpesaPayment(txId, listingId, plan, fee);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading
      VAppAlert.showErrorSnackBar(message: e.toString(), context: context);
    }
  }

  Future<void> _pollMpesaPayment(String txId, String listingId, String plan, double fee) async {
    // Show a simple waiting dialog with manual confirmation
    bool? confirmed = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Complete M-Pesa Payment'),
        content: const Column(
          children: [
            SizedBox(height: 12),
            CupertinoActivityIndicator(),
            SizedBox(height: 12),
            Text('Check your phone for the M-Pesa prompt and enter your PIN to complete the payment.'),
            SizedBox(height: 8),
            Text(
              'Tap "Done" after completing the payment.',
              style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Done'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // User says they completed payment, promote the listing
      VAppAlert.showLoading(context: context);
      try {
        await _marketApi.promoteListing(
          listingId: listingId,
          plan: plan,
          paidAmount: fee,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        VAppAlert.showSuccessSnackBar(
          message: 'Listing promoted successfully!',
          context: context,
        );
        await _loadPromotionData();
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();
        VAppAlert.showErrorSnackBar(message: e.toString(), context: context);
      }
    }
  }

  Widget _buildAnalyticsBody(CupertinoThemeData theme) {
    if (_loadingAnalytics) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    if (_analyticsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _analyticsError ?? 'Failed to load analytics',
            style: theme.textTheme.textStyle.copyWith(
              color: CupertinoColors.destructiveRed,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: CupertinoColors.systemGrey4,
              onPressed: _loadAnalytics,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    final a = _analytics ?? const <String, dynamic>{};
    final totalLikes = (a['totalLikes'] as num?) ?? num.tryParse('${a['totalLikes'] ?? 0}') ?? 0;
    final totalViews = (a['totalViews'] as num?) ?? num.tryParse('${a['totalViews'] ?? 0}') ?? 0;
    final listingsCount = (a['listingsCount'] as num?) ??
        num.tryParse('${a['listingsCount'] ?? 0}') ??
        0;
    final itemsRaw = a['items'];
    final items = itemsRaw is List
        ? List<Map<String, dynamic>>.from(
            itemsRaw.map((e) => Map<String, dynamic>.from(e as Map)),
          )
        : const <Map<String, dynamic>>[];

    Widget metric(String label, num value, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: const Color(0xFFB48648)),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value.toInt().toString(),
                style: theme.textTheme.textStyle.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            metric('Likes', totalLikes, CupertinoIcons.heart_fill),
            const SizedBox(width: 8),
            metric('Views', totalViews, CupertinoIcons.eye_fill),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              'Listings: ${listingsCount.toInt()}',
              style: theme.textTheme.textStyle.copyWith(
                fontSize: 13,
                color: CupertinoColors.systemGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _loadAnalytics,
              child: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (items.isEmpty)
          Text(
            'No published listings yet.',
            style: theme.textTheme.textStyle.copyWith(
              fontSize: 13,
              color: CupertinoColors.systemGrey,
            ),
          ),
        if (items.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final it = items[index];
              final title = (it['title'] ?? '').toString();
              final likes = (it['likesCount'] as num?) ??
                  num.tryParse('${it['likesCount'] ?? 0}') ??
                  0;
              final views = (it['viewsCount'] as num?) ??
                  num.tryParse('${it['viewsCount'] ?? 0}') ??
                  0;
              final isHidden = (it['isHidden'] == true) ||
                  (it['isHidden']?.toString().trim().toLowerCase() == 'true');
              final isSold = (it['isSold'] == true) ||
                  (it['isSold']?.toString().trim().toLowerCase() == 'true');
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.isEmpty ? 'Untitled' : title,
                            style: theme.textTheme.textStyle.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isSold)
                          const Text(
                            'sold',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.activeGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (!isSold && isHidden)
                          const Text(
                            'hidden',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.destructiveRed,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(CupertinoIcons.heart_fill, size: 14, color: const Color(0xFFB48648)),
                        const SizedBox(width: 4),
                        Text('${likes.toInt()}'),
                        const SizedBox(width: 12),
                        Icon(CupertinoIcons.eye_fill, size: 14, color: const Color(0xFFB48648)),
                        const SizedBox(width: 4),
                        Text('${views.toInt()}'),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSellerToolTile(
    CupertinoThemeData theme, {
    required IconData icon,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey5,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: const Color(0xFFB48648),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.textStyle.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.textStyle.copyWith(
                    fontSize: 11,
                    color: CupertinoColors.systemGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSellerCardContainer(
    CupertinoThemeData theme, {
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF6EB), Color(0xFFFFE6CF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE3B177),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSellFeatureRow(
    CupertinoThemeData theme, {
    required IconData icon,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFFB48648),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF).withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text,
              style: theme.textTheme.textStyle.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4B3826),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onBecomeSellerPressed() {
    // TODO: Replace with real seller verification/ID upload flow
    showCupertinoDialog(
      context: context,
      builder: (ctx) {
        return CupertinoAlertDialog(
          title: const Text('Seller verification'),
          content: const Text(
            'To become a seller, please upload a photo of your ID card. '
            'This step helps keep Marketplace safe for everyone.',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Not now'),
            ),
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _pickAndUploadSellerId();
              },
              isDefaultAction: true,
              child: const Text('Upload ID'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickAndUploadSellerId() async {
    await _pickAndUploadingHelper(() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return; // user cancelled
      }

      final picked = result.files.single;

      // Use VAppAlert.showLoading for a more consistent and reliable loading UI
      VAppAlert.showLoading(context: context);
      bool loadingShown = true;

      try {
        // Convert PlatformFile to VPlatformFile for existing upload pipeline
        VPlatformFile vFile;
        if (picked.bytes != null) {
          vFile = VPlatformFile.fromBytes(
            name: picked.name,
            bytes: picked.bytes!,
          );
        } else if (picked.path != null) {
          vFile = VPlatformFile.fromPath(fileLocalPath: picked.path!);
        } else {
          throw Exception('Selected file has no data');
        }

        // Upload to /user/files using existing service
        final uploaded = await UserFilesService.uploadFiles([vFile]);
        if (uploaded.isEmpty || uploaded.first.networkUrl == null) {
          throw Exception('Upload failed – no URL returned');
        }

        // Seller verification has been removed; no admin approval is required.
        // Keep this upload flow harmless (e.g., in case older UI paths call it).
        if (!mounted) return;
        setState(() {
          _sellerStatus = _SellerStatus.approved;
          _sellerIdFileName = picked.name;
        });
      } finally {
        if (loadingShown && mounted) {
          Navigator.of(context).pop();
          loadingShown = false;
        }
      }

      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (ctx) {
          return CupertinoAlertDialog(
            title: const Text('Submitted'),
            content: const Text(
              'Done.',
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }).catchError((e) {
      final errMsg = _formatSellerIdUploadError(e);
      showCupertinoDialog(
        context: context,
        builder: (ctx) {
          return CupertinoAlertDialog(
            title: const Text('Upload failed'),
            content: Text(errMsg),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    });
  }

  Widget _buildCategoryFilterChip({
    required String label,
    required int index,
    required CupertinoThemeData theme,
  }) {
    final selected = _selectedCategoryFilterIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategoryFilterIndex = index;
        });
        _loadForYouFeed();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFB48648)
              : CupertinoColors.systemGrey5,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: theme.textTheme.textStyle.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color:
                selected ? CupertinoColors.white : CupertinoColors.label,
          ),
        ),
      ),
    );
  }

  Future<void> _openAdvancedFilters() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return CupertinoActionSheet(
          title: const Text('Advanced Filters'),
          message: const Text(
            'Filter by price range and condition (New, used, like-new).',
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _showPriceFilterSheet();
              },
              child: const Text('Filter by price'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                _showConditionFilterSheet();
              },
              child: const Text('Filter by condition'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        );
      },
    );
  }

  Future<void> _showPriceFilterSheet() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: CupertinoPopupSurface(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              color: CupertinoColors.systemBackground.resolveFrom(ctx),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Price filter',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: _minPriceCtrl,
                          placeholder: 'Min',
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CupertinoTextField(
                          controller: _maxPriceCtrl,
                          placeholder: 'Max',
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          color: CupertinoColors.systemGrey5,
                          onPressed: () {
                            _minPriceCtrl.clear();
                            _maxPriceCtrl.clear();
                            setState(() {
                              _minPrice = null;
                              _maxPrice = null;
                            });
                            Navigator.of(ctx).pop();
                            _loadForYouFeed();
                          },
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CupertinoButton(
                          color: const Color(0xFFB48648),
                          onPressed: () {
                            final minT = _minPriceCtrl.text.trim();
                            final maxT = _maxPriceCtrl.text.trim();
                            setState(() {
                              _minPrice = minT.isEmpty ? null : int.tryParse(minT);
                              _maxPrice = maxT.isEmpty ? null : int.tryParse(maxT);
                            });
                            Navigator.of(ctx).pop();
                            _loadForYouFeed();
                          },
                          child: const Text(
                            'Apply',
                            style: TextStyle(color: CupertinoColors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showConditionFilterSheet() async {
    const options = <String>['New', 'Used', 'Like-new'];
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return CupertinoActionSheet(
          title: const Text('Condition'),
          message: const Text('Choose condition to filter listings.'),
          actions: [
            for (final o in options)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _condition = o;
                  });
                  _loadForYouFeed();
                },
                child: Text(o),
              ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _condition = null;
                });
                _loadForYouFeed();
              },
              child: const Text('Clear condition'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        );
      },
    );
  }

  Widget _buildHeader(CupertinoThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () => Navigator.of(context).pop(),
            child: const Icon(
              CupertinoIcons.back,
              size: 24,
              color: Color(0xFF6B4A1D),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Orbit Business',
                style: theme.textTheme.textStyle.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => const MarketplaceProfileView(),
                    ),
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: CupertinoColors.systemGrey2,
                      child: Icon(
                        CupertinoIcons.person,
                        size: 18,
                        color: Color(0xFF6B4A1D),
                      ),
                    ),
                    _headerBadge(_marketplaceUnreadRooms),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => MarketplaceSearchView(
                        lat: _locationLat,
                        lng: _locationLng,
                        radiusKm:
                            (_locationLat != null && _locationLng != null) ? _radiusKm : null,
                        minPrice: _minPrice,
                        maxPrice: _maxPrice,
                        condition: _condition,
                      ),
                    ),
                  );
                },
                child: const CircleAvatar(
                  radius: 16,
                  backgroundColor: CupertinoColors.systemGrey2,
                  child: Icon(
                    CupertinoIcons.search,
                    size: 18,
                    color: Color(0xFF6B4A1D),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(CupertinoThemeData theme) {
    final labels = ['Sell', 'For you', 'Categories'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          ...List.generate(labels.length, (index) {
            final selected = _selectedTabIndex == index;
            return Padding(
              padding:
                  EdgeInsets.only(right: index == labels.length - 1 ? 0 : 8),
              child: GestureDetector(
                onTap: () => _onTabSelected(index),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFB48648)
                        : CupertinoColors.systemGrey5,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    labels[index],
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? CupertinoColors.white
                          : CupertinoColors.label,
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
          _buildFilterTab(theme),
        ],
      ),
    );
  }

  Widget _buildFilterTab(CupertinoThemeData theme) {
    final selected = _selectedTabIndex == 3;
    return GestureDetector(
      onTap: () => _onTabSelected(3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              selected ? const Color(0xFFB48648) : CupertinoColors.systemGrey5,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.slider_horizontal_3,
              size: 16,
              color:
                  selected ? CupertinoColors.white : const Color(0xFFB48648),
            ),
            const SizedBox(width: 4),
            Text(
              'Filter',
              style: theme.textTheme.textStyle.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    selected ? CupertinoColors.white : CupertinoColors.label,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(CupertinoThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _selectedTabIndex == 2
                ? 'Categories'
                : _selectedTabIndex == 3
                    ? 'Filters'
                    : "Today's picks",
            style: theme.textTheme.textStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_selectedTabIndex == 0 || _selectedTabIndex == 1)
            GestureDetector(
              onTap: _pickLocation,
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.location_solid,
                    size: 16,
                    color: Color(0xFFB48648),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _loadingLocation
                        ? 'Locating...'
                        : (_locationLabel ?? 'Set location'),
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 14,
                      color: const Color(0xFFB48648),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList(CupertinoThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: _categories.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final cat = _categories[index];
        return CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (_) => MarketplaceCategoryFeedView(category: cat.name),
              ),
            );
          },
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey5,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  cat.icon,
                  size: 20,
                  color: const Color(0xFFB48648),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  cat.name,
                  style: theme.textTheme.textStyle.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_forward,
                size: 16,
                color: CupertinoColors.systemGrey,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemsGrid(CupertinoThemeData theme) {
    if (_loadingFeed) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_feedError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _feedError!,
            textAlign: TextAlign.center,
            style: theme.textTheme.textStyle.copyWith(
              color: CupertinoColors.systemGrey,
              fontSize: 13,
            ),
          ),
        ),
      );
    }
    if (_feedItems.isEmpty && _featuredListings.isEmpty) {
      return Center(
        child: Text(
          'No listings yet',
          style: theme.textTheme.textStyle.copyWith(
            color: CupertinoColors.systemGrey,
            fontSize: 13,
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Featured section
        if (_featuredListings.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.star_fill, color: Color(0xFFB48648), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Featured',
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFB48648),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _featuredListings.length,
                itemBuilder: (context, index) {
                  final item = _featuredListings[index];
                  return _buildFeaturedListingCard(theme, item);
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
        // Regular feed
        if (_feedItems.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Text(
                'For you',
                style: theme.textTheme.textStyle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = _feedItems[index];
                  return _buildListingCard(theme, item);
                },
                childCount: _feedItems.length,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFeaturedListingCard(CupertinoThemeData theme, Map<String, dynamic> item) {
    final title = (item['title'] ?? '').toString();
    final price = (item['price'] as num?);
    final imgUrl = _firstImageUrl(item);

    return GestureDetector(
      onTap: () {
        Navigator.of(context)
            .push(
          CupertinoPageRoute(
            builder: (_) => MarketplaceListingDetailsView(listing: item),
          ),
        )
            .then((_) {
          unawaited(_loadSoldEarnings());
          unawaited(_loadAnalytics());
        });
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFB48648).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                    child: imgUrl != null
                        ? VPlatformCacheImageWidget(
                            source: VPlatformFile.fromUrl(networkUrl: imgUrl),
                            fit: BoxFit.cover,
                            size: const Size(160, 120),
                          )
                        : Container(
                            color: CupertinoColors.systemGrey5,
                            child: const Center(
                              child: Icon(CupertinoIcons.photo, size: 30),
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.textStyle.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (price != null)
                        Text(
                          _formatKes(price),
                          style: theme.textTheme.textStyle.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB48648),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // Featured badge
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFB48648),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.star_fill, color: CupertinoColors.white, size: 10),
                    SizedBox(width: 3),
                    Text(
                      'FEATURED',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatKes(num? value) {
    if (value == null) return '';
    final f = NumberFormat('#,##0', 'en_KE');
    return 'KES ${f.format(value)}';
  }

  String? _firstImageUrl(Map<String, dynamic> listing) {
    final media = listing['media'];
    if (media is List) {
      for (final m in media) {
        if (m is Map) {
          final type = (m['type'] ?? '').toString();
          final url = (m['url'] ?? '').toString();
          if (type == 'image' && url.isNotEmpty) {
            return url;
          }
        }
      }
    }
    return null;
  }

  Widget _buildListingCard(CupertinoThemeData theme, Map<String, dynamic> item) {
    final title = (item['title'] ?? '').toString();
    final price = (item['price'] as num?);
    final imgUrl = _firstImageUrl(item);
    final isPromoted = item['isPromoted'] == true;

    return GestureDetector(
      onTap: () {
        Navigator.of(context)
            .push(
          CupertinoPageRoute(
            builder: (_) => MarketplaceListingDetailsView(listing: item),
          ),
        )
            .then((_) {
          unawaited(_loadSoldEarnings());
          unawaited(_loadAnalytics());
        });
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(14),
          border: isPromoted
              ? Border.all(color: const Color(0xFFB48648).withValues(alpha: 0.4), width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: Container(
                      width: double.infinity,
                      color: CupertinoColors.systemGrey5,
                      child: imgUrl == null
                          ? const Icon(
                              CupertinoIcons.photo,
                              size: 40,
                              color: CupertinoColors.systemGrey,
                            )
                          : VPlatformCacheImageWidget(
                              source: VPlatformFile.fromUrl(networkUrl: imgUrl),
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  if (isPromoted)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB48648),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.star_fill, color: CupertinoColors.white, size: 8),
                            SizedBox(width: 2),
                            Text(
                              'FEATURED',
                              style: TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatKes(price),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: CupertinoColors.label,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.textStyle.copyWith(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceCategory {
  final String name;
  final IconData icon;

  const _MarketplaceCategory({
    required this.name,
    required this.icon,
  });
}

class _SellHeroChip extends StatelessWidget {
  const _SellHeroChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF4A3215).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCB07E), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: const Color(0xFFB48648),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF5A3F23),
                ),
          ),
        ],
      ),
    );
  }
}

const List<_MarketplaceCategory> _categories = [
  _MarketplaceCategory(
    name: 'Real Estate',
    icon: CupertinoIcons.house_fill,
  ),
  _MarketplaceCategory(
    name: 'Vehicles',
    icon: CupertinoIcons.car_detailed,
  ),
  _MarketplaceCategory(
    name: 'Electronics',
    icon: CupertinoIcons.tv,
  ),
  _MarketplaceCategory(
    name: 'Home & Furniture',
    icon: CupertinoIcons.bed_double,
  ),
  _MarketplaceCategory(
    name: 'Clothing & Fashion',
    icon: CupertinoIcons.bag,
  ),
  _MarketplaceCategory(
    name: 'Pets & Animals',
    icon: CupertinoIcons.paw,
  ),
  _MarketplaceCategory(
    name: 'Services',
    icon: CupertinoIcons.wrench,
  ),
  _MarketplaceCategory(
    name: 'Business & Industrial',
    icon: CupertinoIcons.briefcase,
  ),
  _MarketplaceCategory(
    name: 'Kids & Baby',
    icon: CupertinoIcons.cube_box,
  ),
  _MarketplaceCategory(
    name: 'Sports & Fitness',
    icon: CupertinoIcons.sportscourt,
  ),
  _MarketplaceCategory(
    name: 'Books',
    icon: CupertinoIcons.book,
  ),
  _MarketplaceCategory(
    name: 'Music & Hobbies',
    icon: CupertinoIcons.music_note_2,
  ),
];

