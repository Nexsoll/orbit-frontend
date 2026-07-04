import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:super_up/app/core/services/location_service.dart';
import 'package:super_up/app/core/services/openai_service.dart';
import 'package:super_up/app/modules/marketplace/services/marketplace_api_service.dart';
import 'package:super_up/app/modules/ride/views/location_search_view.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

import 'marketplace_listing_preview_view.dart';

class CreateMarketplaceListingView extends StatefulWidget {
  final Map<String, dynamic>? initialListing;

  const CreateMarketplaceListingView({
    super.key,
    this.initialListing,
  });

  @override
  State<CreateMarketplaceListingView> createState() =>
      _CreateMarketplaceListingViewState();
}

class _CreateMarketplaceListingViewState
    extends State<CreateMarketplaceListingView> {
  late final MarketplaceApiService _api;
  late final OpenAIService _openAI;
  bool _generatingAiText = false;

  static const _accentColor = Color(0xFFB48648);

  final _titleCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _squareFootageCtrl = TextEditingController();
  final _vehicleMakeCtrl = TextEditingController();
  final _vehicleModelCtrl = TextEditingController();
  final _vehicleYearCtrl = TextEditingController();
  final _vehicleMileageCtrl = TextEditingController();
  final _vehicleVinCtrl = TextEditingController();
  final _vehicleHistoryCtrl = TextEditingController();
  final _homeFurnitureDimensionsCtrl = TextEditingController();
  final _homeFurniturePickupNotesCtrl = TextEditingController();
  final _clothingFashionColorCtrl = TextEditingController();
  final _petsVaccinationRecordsCtrl = TextEditingController();
  final _businessIndustrialMinQtyCtrl = TextEditingController();
  final _booksMusicHobbiesAuthorCtrl = TextEditingController();
  final _booksMusicHobbiesInstrumentCtrl = TextEditingController();

  String? _category;
  String? _brand;
  String? _condition;
  String? _priceType;

  String? _locationLabel;
  double? _locationLat;
  double? _locationLng;

  bool _loading = false;
  bool _loadingCategories = false;
  bool _loadingLocation = false;
  List<String> _categories = const [];

  String? _editingId;

  bool _publishAsHidden = false;

  bool _deliveryAvailable = false;

  String? _realEstateTransactionType;
  String? _realEstatePropertyType;
  int? _realEstateBedrooms;
  int? _realEstateBathrooms;
  bool _realEstateFurnished = false;
  List<String> _realEstateAmenities = [];

  List<String> _sportsOutdoorGearTags = [];

  bool _booksMusicHobbiesCollectible = false;

  String? _vehicleType;
  String? _vehicleTransmission;
  String? _vehicleFuelType;

  String? _electronicsWarrantyStatus;

  String? _clothingFashionSize;

  String? _petsAnimalsType;
  String? _petsAnimalsBreed;

  String? _servicesCategory;

  bool _businessIndustrialBulkOrder = false;

  final List<_DraftMediaItem> _media = [];

  static const _conditions = <String>[
    'New',
    'Like New',
    'Used',
    'Refurbished',
  ];

  static const _priceTypes = <String>[
    'fixed',
    'negotiable',
  ];

  static const _realEstateTransactionTypeOptions = <String>[
    'Buy',
    'Rent',
    'Lease',
  ];

  static const _realEstatePropertyTypes = <String>[
    'House',
    'Apartment',
    'Land',
    'Studio',
    'Office',
    'Shop',
    'Warehouse',
    'Other',
  ];

  static const _realEstateAmenitiesOptions = <String>[
    'Parking',
    'Pool',
    'Security',
    'Gym',
    'Garden',
    'Elevator',
    'Water',
    'Electricity',
    'WiFi',
  ];

  static const _vehicleTypes = <String>[
    'Car',
    'Motorbike',
    'Bicycle',
    'Truck',
    'Bus',
    'Van',
    'SUV',
    'Pickup',
    'Other',
  ];

  static const _vehicleTransmissionOptions = <String>[
    'Automatic',
    'Manual',
  ];

  static const _vehicleFuelTypeOptions = <String>[
    'Gasoline',
    'Diesel',
    'Hybrid',
    'Electric',
    'LPG',
    'Other',
  ];

  static const _electronicsWarrantyStatusOptions = <String>[
    'Under warranty',
    'No warranty',
    'Warranty available',
    'Expired',
    'Unknown',
  ];

  static const _clothingFashionSizeOptions = <String>[
    'XS',
    'S',
    'M',
    'L',
    'XL',
    'XXL',
    'One size',
    'Other',
  ];

  static const _petsAnimalsTypes = <String>[
    'Dog',
    'Cat',
    'Bird',
    'Fish',
    'Rabbit',
    'Other',
  ];

  static const _petsBreedsByType = <String, List<String>>{
    'Dog': <String>[
      'Labrador Retriever',
      'German Shepherd',
      'Golden Retriever',
      'Bulldog',
      'Poodle',
      'Rottweiler',
      'Beagle',
      'Doberman',
      'Mixed',
      'Other',
    ],
    'Cat': <String>[
      'Persian',
      'Siamese',
      'Maine Coon',
      'Bengal',
      'British Shorthair',
      'Sphynx',
      'Mixed',
      'Other',
    ],
    'Bird': <String>[
      'Parrot',
      'Parakeet',
      'Canary',
      'Cockatiel',
      'Lovebird',
      'Other',
    ],
    'Fish': <String>[
      'Goldfish',
      'Betta',
      'Guppy',
      'Koi',
      'Other',
    ],
    'Rabbit': <String>[
      'Dutch',
      'Lionhead',
      'Netherland Dwarf',
      'Flemish Giant',
      'Mixed',
      'Other',
    ],
    'Other': <String>['Other'],
  };

  static const _servicesCategoryOptions = <String>[
    'Home',
    'Professional',
    'Personal',
  ];

  static const _sportsOutdoorGearTagOptions = <String>[
    'Camping',
    'Hiking',
    'Fishing',
    'Cycling',
    'Running',
    'Climbing',
    'Water sports',
    'Winter sports',
    'Hunting',
    'Other',
  ];

  static const _fallbackCategories = <String>[
    'Electronics',
    'Phones & Tablets',
    'Computers',
    'Home Appliances',
    'Fashion',
    'Clothing & Fashion',
    'Pets & Animals',
    'Home & Furniture',
    'Furniture',
    'Real Estate',
    'Vehicles',
    'Sports',
    'Books',
    'Books, Music & Hobbies',
    'Music & Hobbies',
    'Services',
    'Business & Industrial',
    'Kids & Baby',
    'Other',
  ];

  bool get _isRealEstate => (_category ?? '').trim().toLowerCase() == 'real estate';

  bool get _isVehicle {
    final c = (_category ?? '').trim().toLowerCase();
    return c == 'vehicles' || c == 'vehicle';
  }

  bool get _isElectronics => (_category ?? '').trim().toLowerCase() == 'electronics';

  bool get _isHomeFurniture {
    final c = (_category ?? '').trim().toLowerCase();
    return c == 'home & furniture' || c == 'home and furniture';
  }

  bool get _isClothingFashion {
    final c = (_category ?? '').trim().toLowerCase();
    return c == 'clothing & fashion' || c == 'clothing and fashion' || c == 'fashion';
  }

  bool get _isPetsAnimals {
    final c = (_category ?? '').trim().toLowerCase();
    return c == 'pets & animals' || c == 'pets and animals';
  }

  bool get _isServices {
    final c = (_category ?? '').trim().toLowerCase();
    return c == 'services' || c == 'service';
  }

  bool get _isBusinessIndustrial {
    final c = (_category ?? '').trim().toLowerCase();
    return c == 'business & industrial' || c == 'business and industrial';
  }

  bool get _isKidsBaby {
    final c = (_category ?? '').trim().toLowerCase();
    return c == 'kids & baby' || c == 'kids and baby';
  }

  bool get _isSports {
    final c = (_category ?? '').trim().toLowerCase();
    return c == 'sports' || c == 'sports & fitness' || c == 'sports and fitness';
  }

  bool _isBooksMusicHobbiesCategory(String? category) {
    final c = (category ?? '').trim().toLowerCase();
    if (c.isEmpty) return false;
    if (c.contains('book')) return true;
    if (c.contains('music') && c.contains('hobb')) return true;
    return c == 'books' ||
        c == 'book' ||
        c == 'books, music & hobbies' ||
        c == 'books, music and hobbies' ||
        c == 'books music & hobbies' ||
        c == 'books music and hobbies' ||
        c == 'music & hobbies' ||
        c == 'music and hobbies' ||
        c == 'books & hobbies' ||
        c == 'books and hobbies' ||
        c == 'books & music' ||
        c == 'books and music';
  }

  bool get _isBooksMusicHobbies {
    return _isBooksMusicHobbiesCategory(_category);
  }

  String? get _sportsOutdoorGearTagsDisplay {
    if (_sportsOutdoorGearTags.isEmpty) return null;
    return _sportsOutdoorGearTags.join(', ');
  }

  String? get _servicesCategoryDisplay {
    final v = (_servicesCategory ?? '').trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v == 'home') return 'Home';
    if (v == 'professional') return 'Professional';
    if (v == 'personal') return 'Personal';
    return _servicesCategory;
  }

  List<String> get _petsBreedsForSelectedType {
    final t = (_petsAnimalsType ?? '').trim();
    if (t.isEmpty) return const <String>[];
    return _petsBreedsByType[t] ?? const <String>['Other'];
  }

  String? get _realEstateTransactionTypeDisplay {
    final v = (_realEstateTransactionType ?? '').trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v == 'buy') return 'Buy';
    if (v == 'rent') return 'Rent';
    if (v == 'lease') return 'Lease';
    return null;
  }

  String? get _realEstateAmenitiesDisplay {
    if (_realEstateAmenities.isEmpty) return null;
    return _realEstateAmenities.join(', ');
  }

  String? get _vehicleTransmissionDisplay {
    final v = (_vehicleTransmission ?? '').trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v == 'automatic') return 'Automatic';
    if (v == 'manual') return 'Manual';
    return null;
  }

  String? get _vehicleFuelTypeDisplay {
    final v = (_vehicleFuelType ?? '').trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v == 'gasoline') return 'Gasoline';
    if (v == 'diesel') return 'Diesel';
    if (v == 'hybrid') return 'Hybrid';
    if (v == 'electric') return 'Electric';
    if (v == 'lpg') return 'LPG';
    if (v == 'other') return 'Other';
    return _vehicleFuelType;
  }

  static const _brandsPhones = <String>[
    'Apple',
    'Samsung',
    'Huawei',
    'Xiaomi',
    'Tecno',
    'Infinix',
    'Nokia',
    'OPPO',
    'Vivo',
    'Realme',
    'Google',
    'OnePlus',
    'Sony',
    'LG',
    'Other',
  ];

  static const _brandsComputers = <String>[
    'Apple',
    'Dell',
    'HP',
    'Lenovo',
    'Asus',
    'Acer',
    'MSI',
    'Toshiba',
    'Microsoft',
    'Other',
  ];

  static const _brandsAppliances = <String>[
    'LG',
    'Samsung',
    'Hisense',
    'Haier',
    'Bosch',
    'Whirlpool',
    'Beko',
    'Panasonic',
    'Other',
  ];

  static const _brandsVehicles = <String>[
    'Toyota',
    'Nissan',
    'Honda',
    'Mazda',
    'Subaru',
    'Mitsubishi',
    'BMW',
    'Mercedes-Benz',
    'Audi',
    'Volkswagen',
    'Ford',
    'Land Rover',
    'Other',
  ];

  static const _brandsFashion = <String>[
    'Nike',
    'Adidas',
    'Puma',
    'Zara',
    'H&M',
    'Other',
  ];

  static const _brandsGeneric = <String>[
    'Apple',
    'Samsung',
    'LG',
    'Sony',
    'Dell',
    'HP',
    'Lenovo',
    'Nike',
    'Adidas',
    'Other',
  ];

  List<String> _brandsForCategory(String? category) {
    final c = (category ?? '').trim().toLowerCase();
    if (c.isEmpty) return _brandsGeneric;

    if (c.contains('phone') || c.contains('mobile') || c.contains('tablet')) {
      return _brandsPhones;
    }
    if (c.contains('computer') || c.contains('laptop') || c.contains('pc')) {
      return _brandsComputers;
    }
    if (c.contains('appliance') || c.contains('kitchen') || c.contains('fridge') || c.contains('washing')) {
      return _brandsAppliances;
    }
    if (c.contains('vehicle') || c.contains('car') || c.contains('motor') || c.contains('bike')) {
      return _brandsVehicles;
    }
    if (c.contains('fashion') || c.contains('cloth') || c.contains('shoe') || c.contains('apparel')) {
      return _brandsFashion;
    }

    if (c.contains('electronics')) return _brandsGeneric;
    return _brandsGeneric;
  }

  String _fullMediaUrl(String raw) {
    if (raw.trim().isEmpty) return raw;
    if (raw.startsWith('http')) return raw;
    return SConstants.baseMediaUrl + raw;
  }

  Future<Uint8List?> _firstListingImageBytes() async {
    for (final m in _media) {
      if (m.type != 'image') continue;
      if (m.localFile != null) {
        final b = await _readBytes(m.localFile!);
        if (b != null && b.isNotEmpty) return b;
      }
      if (m.url != null && m.url!.trim().isNotEmpty) {
        try {
          final res = await http.get(Uri.parse(_fullMediaUrl(m.url!)));
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
            return res.bodyBytes;
          }
        } catch (_) {}
      }
    }
    return null;
  }

  Future<void> _generateTitleOrDescription({
    required bool fillTitle,
    required bool fillDescription,
  }) async {
    if (_loading || _generatingAiText) return;

    final imgBytes = await _firstListingImageBytes();
    if (imgBytes == null || imgBytes.isEmpty) {
      if (!mounted) return;
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Add at least one photo first',
      );
      return;
    }

    setState(() => _generatingAiText = true);
    VAppAlert.showLoading(
      context: context,
      message: 'Generating...',
    );

    Map<String, String>? out;
    Object? err;
    try {
      final ctx = <String>[
        if ((_category ?? '').trim().isNotEmpty) 'Category: ${_category!.trim()}',
        if ((_brand ?? '').trim().isNotEmpty) 'Brand: ${_brand!.trim()}',
        if ((_condition ?? '').trim().isNotEmpty) 'Condition: ${_condition!.trim()}',
      ].join(', ');

      out = await _openAI.generateMarketplaceTitleDescriptionFromImage(
        imageBytes: imgBytes,
        context: ctx,
      );
    } catch (e) {
      err = e;
    } finally {
      await _closeLoadingIfAny();
    }

    if (!mounted) return;

    if (out == null) {
      setState(() => _generatingAiText = false);
      VAppAlert.showErrorSnackBar(
        context: context,
        message: err?.toString() ?? 'Failed to generate',
      );
      return;
    }

    setState(() {
      if (fillTitle) {
        final t = (out!['title'] ?? '').trim();
        if (t.isNotEmpty) _titleCtrl.text = t;
      }
      if (fillDescription) {
        final d = (out!['description'] ?? '').trim();
        if (d.isNotEmpty) _descCtrl.text = d;
      }
      _generatingAiText = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _api = GetIt.I.get<MarketplaceApiService>();
    _openAI = OpenAIService();
    _openAI.initialize();
    _hydrateInitial();
    _priceType ??= 'fixed';
    _categories = _fallbackCategories;
    _loadCategories();
    unawaited(_initAutoLocationIfEmpty());
  }

  void _hydrateInitial() {
    final m = widget.initialListing;
    if (m == null) return;

    _editingId = (m['_id'] ?? m['id'])?.toString();
    _publishAsHidden = (m['isHidden'] == true) ||
        (m['isHidden']?.toString().trim().toLowerCase() == 'true');

    _deliveryAvailable = (m['deliveryAvailable'] == true) ||
        (m['deliveryAvailable']?.toString().trim().toLowerCase() == 'true');
    _titleCtrl.text = (m['title'] ?? '').toString();

    final price = m['price'];
    if (price != null) {
      final p = (price as num).toInt();
      _priceCtrl.text = p.toString();
    }

    _descCtrl.text = (m['description'] ?? '').toString();
    _category = (m['category'] ?? '').toString().trim().isEmpty
        ? null
        : (m['category'] ?? '').toString();
    _brand = (m['brand'] ?? '').toString().trim().isEmpty
        ? null
        : (m['brand'] ?? '').toString();
    _condition = (m['condition'] ?? '').toString().trim().isEmpty
        ? null
        : (m['condition'] ?? '').toString();

    final tx = (m['realEstateTransactionType'] ?? '').toString().trim().toLowerCase();
    _realEstateTransactionType = tx.isEmpty ? null : tx;
    _realEstatePropertyType = (m['realEstatePropertyType'] ?? '').toString().trim().isEmpty
        ? null
        : (m['realEstatePropertyType'] ?? '').toString().trim();

    final bedsRaw = m['realEstateBedrooms'];
    _realEstateBedrooms = bedsRaw is num
        ? bedsRaw.toInt()
        : int.tryParse((bedsRaw ?? '').toString().trim());

    final bathsRaw = m['realEstateBathrooms'];
    _realEstateBathrooms = bathsRaw is num
        ? bathsRaw.toInt()
        : int.tryParse((bathsRaw ?? '').toString().trim());

    final sqftRaw = m['realEstateSquareFootage'];
    final sqft = sqftRaw is num
        ? sqftRaw.toInt()
        : int.tryParse((sqftRaw ?? '').toString().trim());
    _squareFootageCtrl.text = sqft == null ? '' : sqft.toString();

    final furnRaw = m['realEstateFurnished'];
    _realEstateFurnished = (furnRaw == true) ||
        (furnRaw?.toString().trim().toLowerCase() == 'true');

    final am = m['realEstateAmenities'];
    if (am is List) {
      _realEstateAmenities = am
          .map((e) => (e ?? '').toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final sportsTagsRaw = m['sportsOutdoorGearTags'];
    if (sportsTagsRaw is List) {
      _sportsOutdoorGearTags = sportsTagsRaw
          .map((e) => (e ?? '').toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    _booksMusicHobbiesAuthorCtrl.text =
        (m['booksMusicHobbiesAuthor'] ?? '').toString();
    _booksMusicHobbiesInstrumentCtrl.text =
        (m['booksMusicHobbiesInstrument'] ?? '').toString();
    _booksMusicHobbiesCollectible =
        (m['booksMusicHobbiesCollectible'] == true) ||
            (m['booksMusicHobbiesCollectible']?.toString().trim().toLowerCase() ==
                'true');

    _vehicleType = (m['vehicleType'] ?? '').toString().trim().isEmpty
        ? null
        : (m['vehicleType'] ?? '').toString().trim();
    _vehicleMakeCtrl.text = (m['vehicleMake'] ?? '').toString();
    _vehicleModelCtrl.text = (m['vehicleModel'] ?? '').toString();

    final yearRaw = m['vehicleYear'];
    final year = yearRaw is num
        ? yearRaw.toInt()
        : int.tryParse((yearRaw ?? '').toString().trim());
    _vehicleYearCtrl.text = year == null ? '' : year.toString();

    final milRaw = m['vehicleMileage'];
    final mil = milRaw is num
        ? milRaw.toInt()
        : int.tryParse((milRaw ?? '').toString().trim());
    _vehicleMileageCtrl.text = mil == null ? '' : mil.toString();

    final tr = (m['vehicleTransmission'] ?? '').toString().trim().toLowerCase();
    _vehicleTransmission = tr.isEmpty ? null : tr;

    final fr = (m['vehicleFuelType'] ?? '').toString().trim().toLowerCase();
    _vehicleFuelType = fr.isEmpty ? null : fr;

    _vehicleVinCtrl.text = (m['vehicleVin'] ?? '').toString();
    _vehicleHistoryCtrl.text = (m['vehicleHistoryNotes'] ?? '').toString();

    _electronicsWarrantyStatus = (m['electronicsWarrantyStatus'] ?? '').toString().trim().isEmpty
        ? null
        : (m['electronicsWarrantyStatus'] ?? '').toString().trim();

    _homeFurnitureDimensionsCtrl.text =
        (m['homeFurnitureItemDimensions'] ?? '').toString();
    _homeFurniturePickupNotesCtrl.text =
        (m['homeFurniturePickupDeliveryNotes'] ?? '').toString();

    _clothingFashionSize = (m['clothingFashionSize'] ?? '').toString().trim().isEmpty
        ? null
        : (m['clothingFashionSize'] ?? '').toString().trim();
    _clothingFashionColorCtrl.text = (m['clothingFashionColor'] ?? '').toString();

    _petsAnimalsType = (m['petsAnimalsType'] ?? '').toString().trim().isEmpty
        ? null
        : (m['petsAnimalsType'] ?? '').toString().trim();
    _petsAnimalsBreed = (m['petsAnimalsBreed'] ?? '').toString().trim().isEmpty
        ? null
        : (m['petsAnimalsBreed'] ?? '').toString().trim();
    _petsVaccinationRecordsCtrl.text =
        (m['petsAnimalsVaccinationRecords'] ?? '').toString();

    _servicesCategory = (m['servicesCategory'] ?? '').toString().trim().isEmpty
        ? null
        : (m['servicesCategory'] ?? '').toString().trim().toLowerCase();

    _businessIndustrialBulkOrder = (m['businessIndustrialBulkOrder'] == true) ||
        (m['businessIndustrialBulkOrder']?.toString().trim().toLowerCase() == 'true');
    final minQtyRaw = m['businessIndustrialMinQty'];
    final minQty = minQtyRaw is num
        ? minQtyRaw.toInt()
        : int.tryParse((minQtyRaw ?? '').toString().trim());
    _businessIndustrialMinQtyCtrl.text = minQty == null ? '' : minQty.toString();

    final pt = (m['priceType'] ?? '').toString().trim();
    _priceType = pt.isEmpty ? 'fixed' : (pt == 'negotiable' ? 'negotiable' : 'fixed');

    _locationLabel = (m['locationLabel'] ?? '').toString().trim().isEmpty
        ? null
        : (m['locationLabel'] ?? '').toString();
    _locationLat = (m['locationLat'] as num?)?.toDouble();
    _locationLng = (m['locationLng'] as num?)?.toDouble();

    final media = m['media'];
    if (media is List) {
      for (final item in media) {
        if (item is Map) {
          final url = (item['url'] ?? '').toString();
          final type = (item['type'] ?? '').toString();
          final mime = (item['mimeType'] ?? '').toString();
          if (url.isNotEmpty && (type == 'image' || type == 'video')) {
            _media.add(
              _DraftMediaItem(
                url: url,
                type: type,
                mimeType: mime.isEmpty ? null : mime,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<LocationSearchResult>(
      CupertinoPageRoute(
        builder: (_) => const LocationSearchView(
          title: 'Choose location',
        ),
      ),
    );

    if (!mounted) return;
    if (result == null) return;

    setState(() {
      _locationLabel = result.address;
      _locationLat = result.latLng.latitude;
      _locationLng = result.latLng.longitude;
    });
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final list = await _api.getCategories();
      if (!mounted) return;
      setState(() {
        final base = list.isNotEmpty ? list : _fallbackCategories;
        final hasRealEstate = base.any((e) => (e).toString().trim().toLowerCase() == 'real estate');
        final withRealEstate = hasRealEstate ? base : [...base, 'Real Estate'];
        final hasVehicles = withRealEstate.any((e) => (e).toString().trim().toLowerCase() == 'vehicles');
        _categories = hasVehicles ? withRealEstate : [...withRealEstate, 'Vehicles'];
        _loadingCategories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categories = _fallbackCategories;
        _loadingCategories = false;
      });
    }
  }

  Future<void> _initAutoLocationIfEmpty() async {
    if ((_locationLabel ?? '').trim().isNotEmpty && _locationLat != null && _locationLng != null) {
      return;
    }

    setState(() => _loadingLocation = true);
    try {
      final pos = await LocationService.instance.getCurrentLocation();
      if (!mounted) return;
      if (pos == null) {
        setState(() => _loadingLocation = false);
        return;
      }

      String? label;
      try {
        final placemarks = await geocoding.placemarkFromCoordinates(pos.latitude, pos.longitude);
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
        label = parts.isNotEmpty ? parts.join(', ') : null;
      } catch (_) {
        label = null;
      }

      setState(() {
        _locationLat = pos.latitude;
        _locationLng = pos.longitude;
        _locationLabel = label ?? _locationLabel ?? 'Current location';
        _loadingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingLocation = false);
    }
  }

  int get _imageCount => _media.where((m) => m.type == 'image').length;
  int get _videoCount => _media.where((m) => m.type == 'video').length;

  Future<Uint8List?> _readBytes(VPlatformFile file) async {
    try {
      if (file.bytes != null) return Uint8List.fromList(file.bytes!);
      if (file.fileLocalPath != null) {
        return await File(file.fileLocalPath!).readAsBytes();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _fileNameForUpscaled(VPlatformFile file) {
    final fallback = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final raw = file.name.isNotEmpty
        ? file.name
        : (file.fileLocalPath == null
            ? fallback
            : file.fileLocalPath!.split(RegExp(r'[\\/]+')).last);

    final dot = raw.lastIndexOf('.');
    final base = dot == -1 ? raw : raw.substring(0, dot);
    final safeBase = base.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_');
    return '${safeBase}_enhanced_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }

  Uint8List? _enhanceImageBytes(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    var image = img.bakeOrientation(decoded);

    const maxDim = 2048;
    final w = image.width;
    final h = image.height;
    if (w <= 0 || h <= 0) return null;

    final targetW = min(w * 2, maxDim);
    final targetH = max(1, (h * (targetW / w)).round());

    if (targetW != w || targetH != h) {
      image = img.copyResize(
        image,
        width: targetW,
        height: targetH,
        interpolation: img.Interpolation.cubic,
      );
    }

    final out = img.encodeJpg(image, quality: 95);
    return Uint8List.fromList(out);
  }

  Future<VPlatformFile?> _upscaleFile(VPlatformFile file) async {
    final bytes = await _readBytes(file);
    if (bytes == null) return null;

    final out = _enhanceImageBytes(bytes);
    if (out == null || out.isEmpty) return null;

    final name = _fileNameForUpscaled(file);

    if (VPlatforms.isWeb) {
      return VPlatformFile.fromBytes(name: name, bytes: out);
    }

    final outPath = '${Directory.systemTemp.path}/$name';
    await File(outPath).writeAsBytes(out, flush: true);
    return VPlatformFile.fromPath(fileLocalPath: outPath);
  }

  Future<void> _upscaleMediaAt(int index) async {
    if (index < 0 || index >= _media.length) return;
    final m = _media[index];
    if (m.type != 'image') return;
    if (m.localFile == null) {
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Please re-add this photo to upscale it',
      );
      return;
    }
    if (m.isUpscaling) return;

    setState(() => m.isUpscaling = true);
    VAppAlert.showLoading(
      context: context,
      message: 'Enhancing your image...',
    );

    VPlatformFile? upscaled;
    Object? err;
    try {
      upscaled = await _upscaleFile(m.localFile!);
    } catch (e) {
      err = e;
    } finally {
      await _closeLoadingIfAny();
    }

    if (!mounted) return;

    if (upscaled == null) {
      setState(() => m.isUpscaling = false);
      VAppAlert.showErrorSnackBar(
        context: context,
        message: err?.toString() ?? 'Failed to upscale image',
      );
      return;
    }

    setState(() {
      m.localFile = upscaled;
      m.url = null;
      m.mimeType = null;
      m.isUpscaling = false;
      m.isUpscaled = true;
    });
  }

  Future<void> _pickPhotos() async {
    final picked = await VAppPick.getImages();
    if (picked == null || picked.isEmpty) return;

    final available = 5 - _imageCount;
    if (available <= 0) {
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Maximum 5 photos allowed',
      );
      return;
    }

    final toAdd = picked.take(available).toList();
    setState(() {
      for (final f in toAdd) {
        _media.add(_DraftMediaItem(localFile: f, type: 'image'));
      }
    });

    if (picked.length > available) {
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Maximum 5 photos allowed',
      );
    }
  }

  Future<void> _pickVideo() async {
    if (_videoCount >= 1) {
      VAppAlert.showErrorSnackBar(
        context: context,
        message: 'Maximum 1 video allowed',
      );
      return;
    }

    final v = await VAppPick.getVideo();
    if (v == null) return;
    setState(() {
      _media.add(_DraftMediaItem(localFile: v, type: 'video'));
    });
  }

  Future<void> _showAddMediaSheet() async {
    if (_loading) return;
    final isRealEstate = _isRealEstate;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return CupertinoActionSheet(
          title: const Text('Add media'),
          message: Text(
            'Photos: $_imageCount/5, ${isRealEstate ? 'Video tour' : 'Video'}: $_videoCount/1',
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                unawaited(_pickPhotos());
              },
              child: const Text('Add photos'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (_videoCount >= 1) {
                  VAppAlert.showErrorSnackBar(
                    context: context,
                    message: 'Maximum 1 video allowed',
                  );
                  return;
                }
                unawaited(_pickVideo());
              },
              child: Text(
                _videoCount >= 1
                    ? (isRealEstate ? 'Add video tour (max 1 reached)' : 'Add video (max 1 reached)')
                    : (isRealEstate ? 'Add video tour' : 'Add video'),
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }

  Future<void> _removeMediaAt(int index) async {
    if (index < 0 || index >= _media.length) return;
    setState(() => _media.removeAt(index));
  }

  int? _parsePrice() {
    final t = _priceCtrl.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  int? _parseSquareFootage() {
    final t = _squareFootageCtrl.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  int? _parseVehicleYear() {
    final t = _vehicleYearCtrl.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  int? _parseVehicleMileage() {
    final t = _vehicleMileageCtrl.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  Future<List<Map<String, dynamic>>> _ensureUploadedMedia() async {
    final out = <Map<String, dynamic>>[];

    for (final m in _media) {
      if (m.url != null && m.url!.isNotEmpty) {
        out.add({
          'url': m.url,
          'type': m.type,
          if (m.mimeType != null) 'mimeType': m.mimeType,
        });
        continue;
      }
      if (m.localFile == null) continue;

      final res = await _api.uploadMedia(m.localFile!);
      final url = (res['url'] ?? '').toString();
      final type = (res['type'] ?? '').toString();
      final mime = (res['mimeType'] ?? '').toString();

      m.url = url;
      m.mimeType = mime.isEmpty ? null : mime;
      m.type = type.isEmpty ? m.type : type;

      out.add({
        'url': url,
        'type': m.type,
        if (m.mimeType != null) 'mimeType': m.mimeType,
      });
    }

    return out;
  }

  Map<String, dynamic> _buildPayload({
    required List<Map<String, dynamic>> media,
  }) {
    final isRealEstate = _isRealEstate;
    final isVehicle = _isVehicle;
    final isElectronics = _isElectronics;
    final isHomeFurniture = _isHomeFurniture;
    final isClothingFashion = _isClothingFashion;
    final isPetsAnimals = _isPetsAnimals;
    final isServices = _isServices;
    final isBusinessIndustrial = _isBusinessIndustrial;
    final isKidsBaby = _isKidsBaby;
    final isSports = _isSports;
    final isBooksMusicHobbies = _isBooksMusicHobbies;
    final isSpecial = isRealEstate || isVehicle;
    final price = _parsePrice();
    final sqft = _parseSquareFootage();
    final vYear = _parseVehicleYear();
    final vMileage = _parseVehicleMileage();
    return {
      if (_editingId != null) 'id': _editingId,
      'title': _titleCtrl.text.trim(),
      'price': price,
      'priceType': (_priceType ?? 'fixed'),
      'category': _category,
      'brand': (isSpecial || isHomeFurniture || isPetsAnimals || isServices || isBusinessIndustrial || isKidsBaby || isSports || isBooksMusicHobbies)
          ? null
          : _brand,
      'condition': (isSpecial || isPetsAnimals || isServices) ? null : _condition,
      'description': _descCtrl.text.trim(),
      'locationLabel': _locationLabel,
      'locationLat': _locationLat,
      'locationLng': _locationLng,
      'media': media,
      'expiresInDays': 30,
      'isHidden': _publishAsHidden,
      'deliveryAvailable': (isSpecial || isPetsAnimals || isServices) ? false : _deliveryAvailable,

      'electronicsWarrantyStatus': isElectronics ? _electronicsWarrantyStatus : null,

      'clothingFashionSize': isClothingFashion ? _clothingFashionSize : null,
      'clothingFashionColor':
          isClothingFashion ? _clothingFashionColorCtrl.text.trim() : null,

      'servicesCategory': isServices ? _servicesCategory : null,

      'businessIndustrialBulkOrder':
          isBusinessIndustrial ? _businessIndustrialBulkOrder : false,
      'businessIndustrialMinQty':
          isBusinessIndustrial && _businessIndustrialBulkOrder
              ? int.tryParse(_businessIndustrialMinQtyCtrl.text.trim())
              : null,

      'sportsOutdoorGearTags': isSports ? _sportsOutdoorGearTags : const <String>[],

      'booksMusicHobbiesAuthor':
          isBooksMusicHobbies ? _booksMusicHobbiesAuthorCtrl.text.trim() : null,
      'booksMusicHobbiesInstrument': isBooksMusicHobbies
          ? _booksMusicHobbiesInstrumentCtrl.text.trim()
          : null,
      'booksMusicHobbiesCollectible':
          isBooksMusicHobbies ? _booksMusicHobbiesCollectible : false,

      'petsAnimalsType': isPetsAnimals ? _petsAnimalsType : null,
      'petsAnimalsBreed': isPetsAnimals ? _petsAnimalsBreed : null,
      'petsAnimalsVaccinationRecords':
          isPetsAnimals ? _petsVaccinationRecordsCtrl.text.trim() : null,

      'homeFurnitureItemDimensions':
          isHomeFurniture ? _homeFurnitureDimensionsCtrl.text.trim() : null,
      'homeFurniturePickupDeliveryNotes':
          isHomeFurniture ? _homeFurniturePickupNotesCtrl.text.trim() : null,

      'realEstateTransactionType': isRealEstate ? _realEstateTransactionType : null,
      'realEstatePropertyType': isRealEstate ? _realEstatePropertyType : null,
      'realEstateBedrooms': isRealEstate ? _realEstateBedrooms : null,
      'realEstateBathrooms': isRealEstate ? _realEstateBathrooms : null,
      'realEstateSquareFootage': isRealEstate ? sqft : null,
      'realEstateFurnished': isRealEstate ? _realEstateFurnished : false,
      'realEstateAmenities': isRealEstate ? _realEstateAmenities : const <String>[],

      'vehicleType': isVehicle ? _vehicleType : null,
      'vehicleMake': isVehicle ? _vehicleMakeCtrl.text.trim() : null,
      'vehicleModel': isVehicle ? _vehicleModelCtrl.text.trim() : null,
      'vehicleYear': isVehicle ? vYear : null,
      'vehicleMileage': isVehicle ? vMileage : null,
      'vehicleTransmission': isVehicle ? _vehicleTransmission : null,
      'vehicleFuelType': isVehicle ? _vehicleFuelType : null,
      'vehicleVin': isVehicle ? _vehicleVinCtrl.text.trim() : null,
      'vehicleHistoryNotes': isVehicle ? _vehicleHistoryCtrl.text.trim() : null,
    };
  }

  String? get _priceTypeDisplay {
    final v = (_priceType ?? '').trim();
    if (v.isEmpty) return null;
    return v == 'negotiable' ? 'Negotiable' : 'Fixed';
  }

  void _validateDraft() {
    if (_imageCount > 5) {
      throw Exception('Maximum 5 photos allowed');
    }
    if (_videoCount > 1) {
      throw Exception('Maximum 1 video allowed');
    }

    final title = _titleCtrl.text.trim();
    if (title.isEmpty && _media.isEmpty) {
      throw Exception('Add a title or at least one photo to save a draft');
    }
  }

  void _validatePublishOrPreview() {
    final isRealEstate = _isRealEstate;
    final isVehicle = _isVehicle;
    final isPetsAnimals = _isPetsAnimals;
    final isServices = _isServices;
    final isBusinessIndustrial = _isBusinessIndustrial;
    final isSpecial = isRealEstate || isVehicle;
    if (_titleCtrl.text.trim().isEmpty) throw Exception('title is required');
    if ((_category ?? '').trim().isEmpty) throw Exception('category is required');
    if (!isSpecial && !isPetsAnimals && !isServices && (_condition ?? '').trim().isEmpty) {
      throw Exception('condition is required');
    }
    if (isServices && (_servicesCategory ?? '').trim().isEmpty) {
      throw Exception('service category is required');
    }
    if (isBusinessIndustrial && _businessIndustrialBulkOrder && _businessIndustrialMinQtyCtrl.text.trim().isEmpty) {
      throw Exception('min quantity is required');
    }
    if (isPetsAnimals && (_petsAnimalsType ?? '').trim().isEmpty) {
      throw Exception('animal type is required');
    }
    if (isPetsAnimals && (_petsAnimalsBreed ?? '').trim().isEmpty) {
      throw Exception('breed is required');
    }
    if (isRealEstate && (_realEstateTransactionType ?? '').trim().isEmpty) {
      throw Exception('transaction type is required');
    }
    if (isRealEstate && (_realEstatePropertyType ?? '').trim().isEmpty) {
      throw Exception('property type is required');
    }
    if (isVehicle && (_vehicleType ?? '').trim().isEmpty) {
      throw Exception('vehicle type is required');
    }
    if (isVehicle && _vehicleMakeCtrl.text.trim().isEmpty) {
      throw Exception('vehicle make is required');
    }
    if (isVehicle && _vehicleModelCtrl.text.trim().isEmpty) {
      throw Exception('vehicle model is required');
    }
    if (isVehicle && _parseVehicleYear() == null) {
      throw Exception('vehicle year is required');
    }

    if (_imageCount < 1) {
      throw Exception('At least one photo is required');
    }
    _validateDraft();
  }

  Future<void> _closeLoadingIfAny() async {
    if (!mounted) return;
    await Navigator.of(context, rootNavigator: true).maybePop();
  }

  Future<void> _showMissingFieldsDialog(List<String> missing) async {
    if (!mounted) return;
    if (missing.isEmpty) return;
    await VAppAlert.showOkAlertDialog(
      context: context,
      title: 'Missing required fields',
      content: missing.join('\n'),
    );
  }

  List<String> _missingFieldsForPublishOrPreview() {
    final isRealEstate = _isRealEstate;
    final isVehicle = _isVehicle;
    final isPetsAnimals = _isPetsAnimals;
    final isServices = _isServices;
    final isBusinessIndustrial = _isBusinessIndustrial;
    final isSpecial = isRealEstate || isVehicle;
    final missing = <String>[];
    if (_titleCtrl.text.trim().isEmpty) missing.add('- Title');
    if ((_category ?? '').trim().isEmpty) missing.add('- Category');
    if (!isSpecial && !isPetsAnimals && !isServices && (_condition ?? '').trim().isEmpty) {
      missing.add('- Condition');
    }
    if (isServices && (_servicesCategory ?? '').trim().isEmpty) {
      missing.add('- Service category');
    }
    if (isBusinessIndustrial && _businessIndustrialBulkOrder && _businessIndustrialMinQtyCtrl.text.trim().isEmpty) {
      missing.add('- Min qty');
    }
    if (isPetsAnimals && (_petsAnimalsType ?? '').trim().isEmpty) {
      missing.add('- Animal type');
    }
    if (isPetsAnimals && (_petsAnimalsBreed ?? '').trim().isEmpty) {
      missing.add('- Breed');
    }
    if (isRealEstate && (_realEstateTransactionType ?? '').trim().isEmpty) {
      missing.add('- Transaction type');
    }
    if (isRealEstate && (_realEstatePropertyType ?? '').trim().isEmpty) {
      missing.add('- Property type');
    }
    if (isVehicle && (_vehicleType ?? '').trim().isEmpty) missing.add('- Vehicle type');
    if (isVehicle && _vehicleMakeCtrl.text.trim().isEmpty) missing.add('- Make');
    if (isVehicle && _vehicleModelCtrl.text.trim().isEmpty) missing.add('- Model');
    if (isVehicle && _parseVehicleYear() == null) missing.add('- Year');
    if (_imageCount < 1) missing.add('- At least 1 photo');
    if (_imageCount > 5) missing.add('- Max 5 photos');
    if (_videoCount > 1) missing.add('- Max 1 video');
    return missing;
  }

  Future<void> _saveDraft() async {
    FocusScope.of(context).unfocus();
    try {
      _validateDraft();
    } catch (e) {
      if (!mounted) return;
      await _showMissingFieldsDialog(['- ${e.toString()}']);
      return;
    }

    setState(() => _loading = true);
    VAppAlert.showLoading(context: context);
    try {
      final uploadedMedia = await _ensureUploadedMedia();
      final payload = _buildPayload(media: uploadedMedia);

      // If editing a non-draft listing, create a new draft by not passing id
      if (widget.initialListing != null) {
        final status = (widget.initialListing!['status'] ?? '').toString();
        if (status != 'draft') {
          payload.remove('id');
        }
      }

      final doc = await _api.saveDraft(payload);
      _editingId = (doc['_id'] ?? doc['id'])?.toString();

      if (!mounted) return;
      await _closeLoadingIfAny();
      VAppAlert.showSuccessSnackBar(context: context, message: 'Draft saved');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      await _closeLoadingIfAny();
      await VAppAlert.showOkAlertDialog(
        context: context,
        title: 'Failed',
        content: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPreview() async {
    FocusScope.of(context).unfocus();
    final missing = _missingFieldsForPublishOrPreview();
    if (missing.isNotEmpty) {
      await _showMissingFieldsDialog(missing);
      return;
    }

    try {
      _validatePublishOrPreview();
    } catch (e) {
      if (!mounted) return;
      await VAppAlert.showOkAlertDialog(
        context: context,
        title: 'Missing required fields',
        content: e.toString(),
      );
      return;
    }

    setState(() => _loading = true);
    VAppAlert.showLoading(context: context);
    try {
      final uploadedMedia = await _ensureUploadedMedia();
      final payload = _buildPayload(media: uploadedMedia);
      final preview = await _api.preview(payload);

      if (!mounted) return;
      await _closeLoadingIfAny();
      setState(() => _loading = false);

      final changed = await Navigator.of(context).push<bool>(
        CupertinoPageRoute(
          builder: (_) => MarketplaceListingPreviewView(
            payload: payload,
            previewData: preview,
          ),
        ),
      );

      if (changed == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      await _closeLoadingIfAny();
      await VAppAlert.showOkAlertDialog(
        context: context,
        title: 'Failed',
        content: e.toString(),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _publish() async {
    FocusScope.of(context).unfocus();
    final missing = _missingFieldsForPublishOrPreview();
    if (missing.isNotEmpty) {
      await _showMissingFieldsDialog(missing);
      return;
    }

    try {
      _validatePublishOrPreview();
    } catch (e) {
      if (!mounted) return;
      await VAppAlert.showOkAlertDialog(
        context: context,
        title: 'Missing required fields',
        content: e.toString(),
      );
      return;
    }

    setState(() => _loading = true);
    VAppAlert.showLoading(context: context);
    try {
      final uploadedMedia = await _ensureUploadedMedia();
      final payload = _buildPayload(media: uploadedMedia);
      final doc = await _api.publish(payload);
      _editingId = (doc['_id'] ?? doc['id'])?.toString();

      if (!mounted) return;
      await _closeLoadingIfAny();
      VAppAlert.showSuccessSnackBar(context: context, message: 'Listing published');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      await _closeLoadingIfAny();
      await VAppAlert.showOkAlertDialog(
        context: context,
        title: 'Failed',
        content: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _showPicker({
    required String title,
    required List<String> items,
    required String? value,
  }) async {
    if (items.isEmpty) return null;
    return showCupertinoModalPopup<String>(
      context: context,
      builder: (popupCtx) {
        String current = value ?? items.first;
        final initialIndex = items.indexOf(current).clamp(0, items.length - 1);
        return SafeArea(
          top: false,
          child: Container(
            color: CupertinoColors.systemBackground.resolveFrom(popupCtx),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6.resolveFrom(popupCtx),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(popupCtx).pop(),
                        child: const Text('Cancel'),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(popupCtx).pop(current),
                        child: const Text('Select'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 216,
                  child: CupertinoPicker(
                    itemExtent: 36,
                    scrollController: FixedExtentScrollController(
                      initialItem: initialIndex,
                    ),
                    onSelectedItemChanged: (i) => current = items[i],
                    children: items.map((e) => Center(child: Text(e))).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _squareFootageCtrl.dispose();
    _vehicleMakeCtrl.dispose();
    _vehicleModelCtrl.dispose();
    _vehicleYearCtrl.dispose();
    _vehicleMileageCtrl.dispose();
    _vehicleVinCtrl.dispose();
    _vehicleHistoryCtrl.dispose();
    _homeFurnitureDimensionsCtrl.dispose();
    _homeFurniturePickupNotesCtrl.dispose();
    _clothingFashionColorCtrl.dispose();
    _petsVaccinationRecordsCtrl.dispose();
    _businessIndustrialMinQtyCtrl.dispose();
    _booksMusicHobbiesAuthorCtrl.dispose();
    _booksMusicHobbiesInstrumentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialListing != null;
    final initialStatus = editing ? (widget.initialListing!['status'] ?? '').toString() : '';
    final isEditingDraft = editing && initialStatus == 'draft';
    final isRealEstate = _isRealEstate;
    final isVehicle = _isVehicle;
    final isSpecial = isRealEstate || isVehicle;
    final isHomeFurniture = _isHomeFurniture;
    final isPetsAnimals = _isPetsAnimals;
    final isServices = _isServices;
    final isBusinessIndustrial = _isBusinessIndustrial;
    final isKidsBaby = _isKidsBaby;
    final isSports = _isSports;
    final isBooksMusicHobbies = _isBooksMusicHobbies;
    final isNewCategory = _category != null &&
        !_fallbackCategories.map((e) => e.toLowerCase()).contains(_category!.toLowerCase());
    final hideBrand = isSpecial ||
        isHomeFurniture ||
        isPetsAnimals ||
        isServices ||
        isBusinessIndustrial ||
        isKidsBaby ||
        isSports ||
        isBooksMusicHobbies ||
        isNewCategory;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(editing ? 'Edit listing' : 'Create listing'),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Media'),
              const SizedBox(height: 8),
              _mediaPickerCard(),
              const SizedBox(height: 10),
              _mediaGrid(),
              const SizedBox(height: 18),
              _sectionTitle('Details'),
              const SizedBox(height: 8),
              _field(
                label: 'Title',
                controller: _titleCtrl,
                labelTrailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: _loading || _generatingAiText
                      ? null
                      : () => _generateTitleOrDescription(
                            fillTitle: true,
                            fillDescription: false,
                          ),
                  child: Row(
                    children: const [
                      Icon(CupertinoIcons.sparkles, size: 14, color: _accentColor),
                      SizedBox(width: 4),
                      Text(
                        'Generate',
                        style: TextStyle(
                          fontSize: 12,
                          color: _accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _pickerField(
                      label: 'Category',
                      value: _category,
                      placeholder:
                          _loadingCategories ? 'Loading...' : 'Tap to select',
                      onTap: () async {
                        final picked = await _showPicker(
                          title: 'Category',
                          items: _categories,
                          value: _category,
                        );
                        if (picked != null && mounted) {
                          final wasRealEstate = (_category ?? '').trim().toLowerCase() == 'real estate';
                          final willBeRealEstate = picked.trim().toLowerCase() == 'real estate';
                          final wasVehicle = (_category ?? '').trim().toLowerCase() == 'vehicles' ||
                              (_category ?? '').trim().toLowerCase() == 'vehicle';
                          final willBeVehicle = picked.trim().toLowerCase() == 'vehicles' ||
                              picked.trim().toLowerCase() == 'vehicle';
                          final wasElectronics = (_category ?? '').trim().toLowerCase() == 'electronics';
                          final willBeElectronics = picked.trim().toLowerCase() == 'electronics';
                          final wasHomeFurniture =
                              (_category ?? '').trim().toLowerCase() == 'home & furniture' ||
                                  (_category ?? '').trim().toLowerCase() == 'home and furniture';
                          final willBeHomeFurniture =
                              picked.trim().toLowerCase() == 'home & furniture' ||
                                  picked.trim().toLowerCase() == 'home and furniture';
                          final wasClothingFashion =
                              (_category ?? '').trim().toLowerCase() == 'clothing & fashion' ||
                                  (_category ?? '').trim().toLowerCase() == 'clothing and fashion' ||
                                  (_category ?? '').trim().toLowerCase() == 'fashion';
                          final willBeClothingFashion =
                              picked.trim().toLowerCase() == 'clothing & fashion' ||
                                  picked.trim().toLowerCase() == 'clothing and fashion' ||
                                  picked.trim().toLowerCase() == 'fashion';
                          final wasPetsAnimals =
                              (_category ?? '').trim().toLowerCase() == 'pets & animals' ||
                                  (_category ?? '').trim().toLowerCase() == 'pets and animals';
                          final willBePetsAnimals =
                              picked.trim().toLowerCase() == 'pets & animals' ||
                                  picked.trim().toLowerCase() == 'pets and animals';
                          final wasServices =
                              (_category ?? '').trim().toLowerCase() == 'services' ||
                                  (_category ?? '').trim().toLowerCase() == 'service';
                          final willBeServices =
                              picked.trim().toLowerCase() == 'services' ||
                                  picked.trim().toLowerCase() == 'service';
                          final wasBusinessIndustrial =
                              (_category ?? '').trim().toLowerCase() == 'business & industrial' ||
                                  (_category ?? '').trim().toLowerCase() ==
                                      'business and industrial';
                          final willBeBusinessIndustrial =
                              picked.trim().toLowerCase() == 'business & industrial' ||
                                  picked.trim().toLowerCase() ==
                                      'business and industrial';
                          final wasKidsBaby =
                              (_category ?? '').trim().toLowerCase() == 'kids & baby' ||
                                  (_category ?? '').trim().toLowerCase() == 'kids and baby';
                          final willBeKidsBaby =
                              picked.trim().toLowerCase() == 'kids & baby' ||
                                  picked.trim().toLowerCase() == 'kids and baby';
                          final wasSports =
                              (_category ?? '').trim().toLowerCase() == 'sports' ||
                                  (_category ?? '').trim().toLowerCase() == 'sports & fitness' ||
                                  (_category ?? '').trim().toLowerCase() == 'sports and fitness';
                          final willBeSports =
                              picked.trim().toLowerCase() == 'sports' ||
                                  picked.trim().toLowerCase() == 'sports & fitness' ||
                                  picked.trim().toLowerCase() == 'sports and fitness';
                          final wasBooksMusicHobbies =
                              _isBooksMusicHobbiesCategory(_category);
                          final willBeBooksMusicHobbies =
                              _isBooksMusicHobbiesCategory(picked);
                          final brands = _brandsForCategory(picked);

                          setState(() {
                            _category = picked;
                            if (_brand != null && !brands.contains(_brand)) {
                              _brand = null;
                            }

                            if (willBeRealEstate || willBeVehicle) {
                              _brand = null;
                              _condition = null;
                              _deliveryAvailable = false;
                            }

                            if (willBeHomeFurniture) {
                              _brand = null;
                            }

                            if (willBePetsAnimals) {
                              _brand = null;
                              _condition = null;
                              _deliveryAvailable = false;
                            }

                            if (!wasServices && willBeServices) {
                              _servicesCategory = null;
                            }

                            if (willBeServices) {
                              _brand = null;
                              _condition = null;
                              _deliveryAvailable = false;
                            }

                            if (wasServices && !willBeServices) {
                              _servicesCategory = null;
                            }

                            if (wasBusinessIndustrial && !willBeBusinessIndustrial) {
                              _businessIndustrialBulkOrder = false;
                              _businessIndustrialMinQtyCtrl.text = '';
                            }

                            if (!wasBusinessIndustrial && willBeBusinessIndustrial) {
                              _brand = null;
                              _businessIndustrialBulkOrder = false;
                              _businessIndustrialMinQtyCtrl.text = '';
                            }

                            if (!wasKidsBaby && willBeKidsBaby) {
                              _brand = null;
                            }

                            if (!wasSports && willBeSports) {
                              _brand = null;
                              _sportsOutdoorGearTags = [];
                            }

                            if (wasSports && !willBeSports) {
                              _sportsOutdoorGearTags = [];
                            }

                            if (!wasBooksMusicHobbies && willBeBooksMusicHobbies) {
                              _brand = null;
                              _booksMusicHobbiesAuthorCtrl.text = '';
                              _booksMusicHobbiesInstrumentCtrl.text = '';
                              _booksMusicHobbiesCollectible = false;
                            }

                            if (wasBooksMusicHobbies && !willBeBooksMusicHobbies) {
                              _booksMusicHobbiesAuthorCtrl.text = '';
                              _booksMusicHobbiesInstrumentCtrl.text = '';
                              _booksMusicHobbiesCollectible = false;
                            }

                            if (wasRealEstate && !willBeRealEstate) {
                              _realEstateTransactionType = null;
                              _realEstatePropertyType = null;
                              _realEstateBedrooms = null;
                              _realEstateBathrooms = null;
                              _squareFootageCtrl.text = '';
                              _realEstateFurnished = false;
                              _realEstateAmenities = [];
                            }

                            if (wasVehicle && !willBeVehicle) {
                              _vehicleType = null;
                              _vehicleMakeCtrl.text = '';
                              _vehicleModelCtrl.text = '';
                              _vehicleYearCtrl.text = '';
                              _vehicleMileageCtrl.text = '';
                              _vehicleTransmission = null;
                              _vehicleFuelType = null;
                              _vehicleVinCtrl.text = '';
                              _vehicleHistoryCtrl.text = '';
                            }

                            if (wasElectronics && !willBeElectronics) {
                              _electronicsWarrantyStatus = null;
                            }

                            if (wasHomeFurniture && !willBeHomeFurniture) {
                              _homeFurnitureDimensionsCtrl.text = '';
                              _homeFurniturePickupNotesCtrl.text = '';
                            }

                            if (wasClothingFashion && !willBeClothingFashion) {
                              _clothingFashionSize = null;
                              _clothingFashionColorCtrl.text = '';
                            }

                            if (wasPetsAnimals && !willBePetsAnimals) {
                              _petsAnimalsType = null;
                              _petsAnimalsBreed = null;
                              _petsVaccinationRecordsCtrl.text = '';
                            }
                          });
                        }
                      },
                    ),
                  ),
                  if (!isSpecial && !isPetsAnimals && !isServices) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _pickerField(
                        label: 'Condition',
                        value: _condition,
                        placeholder: 'Tap to select',
                        onTap: () async {
                          final picked = await _showPicker(
                            title: 'Condition',
                            items: _conditions,
                            value: _condition,
                          );
                          if (picked != null && mounted) {
                            setState(() => _condition = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              if (!hideBrand)
                _pickerField(
                  label: 'Brand',
                  value: _brand,
                  placeholder:
                      (_category ?? '').trim().isEmpty ? 'Select category first' : null,
                  onTap: (_category ?? '').trim().isEmpty
                      ? null
                      : () async {
                          final items = _brandsForCategory(_category);
                          final picked = await _showPicker(
                            title: 'Brand',
                            items: items,
                            value: _brand,
                          );
                          if (picked != null && mounted) {
                            setState(() => _brand = picked);
                          }
                        },
                ),
              if (_isElectronics) ...[
                const SizedBox(height: 12),
                _pickerField(
                  label: 'Warranty status',
                  value: _electronicsWarrantyStatus,
                  placeholder: 'Tap to select',
                  onTap: () async {
                    final picked = await _showPicker(
                      title: 'Warranty status',
                      items: _electronicsWarrantyStatusOptions,
                      value: _electronicsWarrantyStatus,
                    );
                    if (picked != null && mounted) {
                      setState(() => _electronicsWarrantyStatus = picked);
                    }
                  },
                ),
              ],
              if (_isHomeFurniture) ...[
                const SizedBox(height: 12),
                _field(
                  label: 'Item dimensions',
                  controller: _homeFurnitureDimensionsCtrl,
                  placeholder: 'e.g. 200 x 80 x 75 cm',
                ),
                const SizedBox(height: 12),
                _multiline(
                  label: 'Pickup/Delivery notes',
                  controller: _homeFurniturePickupNotesCtrl,
                  placeholder: 'Transport instructions...',
                ),
              ],
              if (_isClothingFashion) ...[
                const SizedBox(height: 12),
                _pickerField(
                  label: 'Size',
                  value: _clothingFashionSize,
                  placeholder: 'Tap to select',
                  onTap: () async {
                    final picked = await _showPicker(
                      title: 'Size',
                      items: _clothingFashionSizeOptions,
                      value: _clothingFashionSize,
                    );
                    if (picked != null && mounted) {
                      setState(() => _clothingFashionSize = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _field(
                  label: 'Color',
                  controller: _clothingFashionColorCtrl,
                  placeholder: 'e.g. Black',
                ),
              ],
              if (_isPetsAnimals) ...[
                const SizedBox(height: 12),
                _pickerField(
                  label: 'Animal',
                  value: _petsAnimalsType,
                  placeholder: 'Tap to select',
                  onTap: () async {
                    final picked = await _showPicker(
                      title: 'Animal',
                      items: _petsAnimalsTypes,
                      value: _petsAnimalsType,
                    );
                    if (picked != null && mounted) {
                      setState(() {
                        _petsAnimalsType = picked;
                        final breeds = _petsBreedsForSelectedType;
                        if (_petsAnimalsBreed != null && !breeds.contains(_petsAnimalsBreed)) {
                          _petsAnimalsBreed = null;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                _pickerField(
                  label: 'Breed',
                  value: _petsAnimalsBreed,
                  placeholder: (_petsAnimalsType ?? '').trim().isEmpty
                      ? 'Select animal first'
                      : 'Tap to select',
                  onTap: (_petsAnimalsType ?? '').trim().isEmpty
                      ? null
                      : () async {
                          final picked = await _showPicker(
                            title: 'Breed',
                            items: _petsBreedsForSelectedType,
                            value: _petsAnimalsBreed,
                          );
                          if (picked != null && mounted) {
                            setState(() => _petsAnimalsBreed = picked);
                          }
                        },
                ),
                const SizedBox(height: 12),
                _multiline(
                  label: 'Vaccination records',
                  controller: _petsVaccinationRecordsCtrl,
                  placeholder: 'e.g. Rabies: 2025-01-10',
                ),
              ],
              if (_isServices) ...[
                const SizedBox(height: 12),
                _pickerField(
                  label: 'Service category',
                  value: _servicesCategoryDisplay,
                  placeholder: 'Tap to select',
                  onTap: () async {
                    final picked = await _showPicker(
                      title: 'Service category',
                      items: _servicesCategoryOptions,
                      value: _servicesCategoryDisplay,
                    );
                    if (picked != null && mounted) {
                      setState(() => _servicesCategory = picked.trim().toLowerCase());
                    }
                  },
                ),
              ],
              if (_isBusinessIndustrial) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Bulk order',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      CupertinoSlidingSegmentedControl<bool>(
                        groupValue: _businessIndustrialBulkOrder,
                        onValueChanged: (v) {
                          if (_loading) return;
                          if (v == null) return;
                          setState(() {
                            _businessIndustrialBulkOrder = v;
                            if (!v) _businessIndustrialMinQtyCtrl.text = '';
                          });
                        },
                        children: const {
                          false: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Text('No'),
                          ),
                          true: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Text('Yes'),
                          ),
                        },
                      ),
                    ],
                  ),
                ),
                if (_businessIndustrialBulkOrder) ...[
                  const SizedBox(height: 12),
                  _field(
                    label: 'Min qty',
                    controller: _businessIndustrialMinQtyCtrl,
                    keyboard: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    placeholder: 'e.g. 10',
                  ),
                ],
              ],
              if (_isBooksMusicHobbies) ...[
                const SizedBox(height: 12),
                _field(
                  label: 'Author',
                  controller: _booksMusicHobbiesAuthorCtrl,
                  placeholder: 'e.g. J.K. Rowling',
                ),
                const SizedBox(height: 12),
                _field(
                  label: 'Instrument',
                  controller: _booksMusicHobbiesInstrumentCtrl,
                  placeholder: 'e.g. Guitar',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Collectible',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      CupertinoSlidingSegmentedControl<bool>(
                        groupValue: _booksMusicHobbiesCollectible,
                        onValueChanged: (v) {
                          if (_loading) return;
                          if (v == null) return;
                          setState(() => _booksMusicHobbiesCollectible = v);
                        },
                        children: const {
                          false: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('No'),
                          ),
                          true: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('Yes'),
                          ),
                        },
                      ),
                    ],
                  ),
                ),
              ],
              if (_isSports) ...[
                const SizedBox(height: 12),
                _pickerField(
                  label: 'Outdoor gear tags',
                  value: _sportsOutdoorGearTagsDisplay,
                  placeholder: 'Tap to add',
                  onTap: () async {
                    final picked = await _showPicker(
                      title: 'Outdoor gear tags',
                      items: _sportsOutdoorGearTagOptions,
                      value: null,
                    );
                    if (picked != null && mounted) {
                      setState(() {
                        if (!_sportsOutdoorGearTags.contains(picked)) {
                          _sportsOutdoorGearTags = [..._sportsOutdoorGearTags, picked];
                        }
                      });
                    }
                  },
                ),
                if (_sportsOutdoorGearTags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sportsOutdoorGearTags.map((t) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(t),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: _loading
                                  ? null
                                  : () {
                                      setState(() {
                                        _sportsOutdoorGearTags = _sportsOutdoorGearTags.where((x) => x != t).toList();
                                      });
                                    },
                              child: const Icon(CupertinoIcons.xmark_circle_fill, size: 16, color: CupertinoColors.systemGrey),
                            )
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
              if (isVehicle) ...[
                Row(
                  children: [
                    Expanded(
                      child: _pickerField(
                        label: 'Vehicle type',
                        value: _vehicleType,
                        placeholder: 'Tap to select',
                        onTap: () async {
                          final picked = await _showPicker(
                            title: 'Vehicle type',
                            items: _vehicleTypes,
                            value: _vehicleType,
                          );
                          if (picked != null && mounted) {
                            setState(() => _vehicleType = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _pickerField(
                        label: 'Transmission',
                        value: _vehicleTransmissionDisplay,
                        placeholder: 'Tap to select',
                        onTap: () async {
                          final picked = await _showPicker(
                            title: 'Transmission',
                            items: _vehicleTransmissionOptions,
                            value: _vehicleTransmissionDisplay,
                          );
                          if (picked != null && mounted) {
                            setState(() => _vehicleTransmission = picked.trim().toLowerCase());
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        label: 'Make',
                        controller: _vehicleMakeCtrl,
                        placeholder: 'e.g. Toyota',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        label: 'Model',
                        controller: _vehicleModelCtrl,
                        placeholder: 'e.g. Corolla',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        label: 'Year',
                        controller: _vehicleYearCtrl,
                        keyboard: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        placeholder: 'e.g. 2018',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        label: 'Mileage',
                        controller: _vehicleMileageCtrl,
                        keyboard: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        placeholder: 'e.g. 80000',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _pickerField(
                  label: 'Fuel type',
                  value: _vehicleFuelTypeDisplay,
                  placeholder: 'Tap to select',
                  onTap: () async {
                    final picked = await _showPicker(
                      title: 'Fuel type',
                      items: _vehicleFuelTypeOptions,
                      value: _vehicleFuelTypeDisplay,
                    );
                    if (picked != null && mounted) {
                      setState(() => _vehicleFuelType = picked.trim().toLowerCase());
                    }
                  },
                ),
                const SizedBox(height: 12),
                _field(
                  label: 'VIN / Chassis',
                  controller: _vehicleVinCtrl,
                  placeholder: 'Optional',
                ),
                const SizedBox(height: 12),
                _multiline(
                  label: 'Vehicle history',
                  controller: _vehicleHistoryCtrl,
                  placeholder: 'Accidents, ownership, service history...',
                ),
              ],
              if (isRealEstate) ...[
                Row(
                  children: [
                    Expanded(
                      child: _pickerField(
                        label: 'Transaction',
                        value: _realEstateTransactionTypeDisplay,
                        placeholder: 'Tap to select',
                        onTap: () async {
                          final picked = await _showPicker(
                            title: 'Transaction',
                            items: _realEstateTransactionTypeOptions,
                            value: _realEstateTransactionTypeDisplay,
                          );
                          if (picked != null && mounted) {
                            setState(() => _realEstateTransactionType = picked.trim().toLowerCase());
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _pickerField(
                        label: 'Property type',
                        value: _realEstatePropertyType,
                        placeholder: 'Tap to select',
                        onTap: () async {
                          final picked = await _showPicker(
                            title: 'Property type',
                            items: _realEstatePropertyTypes,
                            value: _realEstatePropertyType,
                          );
                          if (picked != null && mounted) {
                            setState(() => _realEstatePropertyType = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _pickerField(
                        label: 'Bedrooms',
                        value: _realEstateBedrooms?.toString(),
                        placeholder: 'Tap to select',
                        onTap: () async {
                          final items = List<String>.generate(11, (i) => i.toString());
                          final picked = await _showPicker(
                            title: 'Bedrooms',
                            items: items,
                            value: _realEstateBedrooms?.toString(),
                          );
                          if (picked != null && mounted) {
                            setState(() => _realEstateBedrooms = int.tryParse(picked));
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _pickerField(
                        label: 'Bathrooms',
                        value: _realEstateBathrooms?.toString(),
                        placeholder: 'Tap to select',
                        onTap: () async {
                          final items = List<String>.generate(11, (i) => i.toString());
                          final picked = await _showPicker(
                            title: 'Bathrooms',
                            items: items,
                            value: _realEstateBathrooms?.toString(),
                          );
                          if (picked != null && mounted) {
                            setState(() => _realEstateBathrooms = int.tryParse(picked));
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(
                  label: 'Square footage',
                  controller: _squareFootageCtrl,
                  keyboard: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  placeholder: 'e.g. 1200',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Furnished',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      CupertinoSlidingSegmentedControl<bool>(
                        groupValue: _realEstateFurnished,
                        onValueChanged: (v) {
                          if (_loading) return;
                          if (v == null) return;
                          setState(() => _realEstateFurnished = v);
                        },
                        children: const {
                          false: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Text('No'),
                          ),
                          true: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Text('Yes'),
                          ),
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _pickerField(
                  label: 'Amenities',
                  value: _realEstateAmenitiesDisplay,
                  placeholder: 'Tap to add',
                  onTap: () async {
                    final picked = await _showPicker(
                      title: 'Amenities',
                      items: _realEstateAmenitiesOptions,
                      value: null,
                    );
                    if (picked != null && mounted) {
                      setState(() {
                        if (!_realEstateAmenities.contains(picked)) {
                          _realEstateAmenities = [..._realEstateAmenities, picked];
                        }
                      });
                    }
                  },
                ),
                if (_realEstateAmenities.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _realEstateAmenities.map((a) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              a,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 6),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              onPressed: _loading
                                  ? null
                                  : () {
                                      setState(() {
                                        _realEstateAmenities = _realEstateAmenities.where((x) => x != a).toList();
                                      });
                                    },
                              child: const Icon(CupertinoIcons.xmark_circle_fill, size: 16, color: CupertinoColors.systemGrey),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      label: 'Price (KES)',
                      controller: _priceCtrl,
                      keyboard: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      placeholder: 'e.g. 2500',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _pickerField(
                      label: 'Price type',
                      value: _priceTypeDisplay,
                      placeholder: 'Fixed',
                      onTap: () async {
                        final picked = await _showPicker(
                          title: 'Price type',
                          items: _priceTypes.map((e) => e == 'negotiable' ? 'Negotiable' : 'Fixed').toList(),
                          value: _priceTypeDisplay,
                        );
                        if (picked != null && mounted) {
                          setState(() {
                            _priceType = picked.toLowerCase() == 'negotiable' ? 'negotiable' : 'fixed';
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _pickerField(
                label: 'Location',
                value: _locationLabel,
                placeholder: _loadingLocation
                    ? 'Detecting...'
                    : (_locationLabel == null ? 'Current location' : null),
                onTap: _loadingLocation ? null : _pickLocation,
                showChevron: true,
              ),
              const SizedBox(height: 12),
              if (!isSpecial && !isPetsAnimals && !isServices)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Delivery',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      CupertinoSlidingSegmentedControl<bool>(
                        groupValue: _deliveryAvailable,
                        onValueChanged: (v) {
                          if (_loading) return;
                          if (v == null) return;
                          setState(() => _deliveryAvailable = v);
                        },
                        children: const {
                          false: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Text('No'),
                          ),
                          true: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            child: Text('Yes'),
                          ),
                        },
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              _multiline(
                label: 'Description',
                controller: _descCtrl,
                labelTrailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: _loading || _generatingAiText
                      ? null
                      : () => _generateTitleOrDescription(
                            fillTitle: false,
                            fillDescription: true,
                          ),
                  child: Row(
                    children: const [
                      Icon(CupertinoIcons.sparkles, size: 14, color: _accentColor),
                      SizedBox(width: 4),
                      Text(
                        'Generate',
                        style: TextStyle(
                          fontSize: 12,
                          color: _accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Hide after publishing',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    CupertinoSwitch(
                      value: _publishAsHidden,
                      onChanged: _loading ? null : (v) => setState(() => _publishAsHidden = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      color: _accentColor,
                      onPressed: _loading ? null : _openPreview,
                      child: const Text(
                        'Preview',
                        style: TextStyle(color: CupertinoColors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (isEditingDraft)
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        color: CupertinoColors.systemGrey5,
                        onPressed: _loading ? null : _saveDraft,
                        child: Text(
                          'Update',
                          style: TextStyle(
                            color: _loading
                                ? CupertinoColors.systemGrey
                                : _accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CupertinoButton(
                        color: _accentColor,
                        onPressed: _loading ? null : _publish,
                        child: const Text(
                          'Publish',
                          style: TextStyle(
                            color: CupertinoColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        color: CupertinoColors.systemGrey5,
                        onPressed: _loading ? null : _saveDraft,
                        child: Text(
                          'Save draft',
                          style: TextStyle(
                            color: _loading
                                ? CupertinoColors.systemGrey
                                : _accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CupertinoButton(
                        color: _accentColor,
                        onPressed: _loading ? null : _publish,
                        child: Text(
                          editing ? 'Update' : 'Publish',
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontWeight: FontWeight.w600,
                          ),
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
  }

  Widget _sectionTitle(String t) {
    return Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700));
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? placeholder,
    Widget? labelTrailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (labelTrailing != null) labelTrailing,
          ],
        ),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          keyboardType: keyboard,
          inputFormatters: inputFormatters,
          placeholder: placeholder,
        ),
      ],
    );
  }

  Widget _multiline({
    required String label,
    required TextEditingController controller,
    Widget? labelTrailing,
    String? placeholder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (labelTrailing != null) labelTrailing,
          ],
        ),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: controller,
          maxLines: 6,
          placeholder: placeholder,
        ),
      ],
    );
  }

  Widget _pickerField({
    required String label,
    required String? value,
    required VoidCallback? onTap,
    String? placeholder,
    bool showChevron = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value ?? (placeholder ?? 'Tap to select'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showChevron) const Icon(CupertinoIcons.chevron_down),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mediaPickerCard() {
    return GestureDetector(
      onTap: _loading ? null : _showAddMediaSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                CupertinoIcons.add,
                color: _accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add media',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _loading
                          ? CupertinoColors.systemGrey
                          : _accentColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Photos $_imageCount/5, Video $_videoCount/1',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              color: CupertinoColors.systemGrey,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  String? _buildCloudinaryVideoThumbnailUrl(String rawUrl) {
    try {
      if (rawUrl.isEmpty) return null;
      final fullUrl = rawUrl.startsWith('http')
          ? rawUrl
          : '${SConstants.baseMediaUrl}$rawUrl';
      final u = Uri.parse(fullUrl);
      if (!u.host.contains('res.cloudinary.com')) return null;
      final path = u.path;
      final idx = path.indexOf('/upload/');
      if (idx == -1) return null;

      final prefix = '${u.scheme}://${u.host}${path.substring(0, idx + '/upload/'.length)}';
      final tail = path.substring(idx + '/upload/'.length).replaceFirst(RegExp(r'^/+'), '');
      final jpgTail = tail.replaceAll(RegExp(r'\.[^./]+$'), '.jpg');
      const transform = 'so_1,w_640,h_360,c_fill,f_jpg';
      return '$prefix$transform/$jpgTail';
    } catch (_) {
      return null;
    }
  }

  Widget _mediaGrid() {
    if (_media.isEmpty) {
      final isRealEstate = _isRealEstate;
      return Text(
        'Add up to 5 photos and 1 ${isRealEstate ? 'video tour' : 'video'}. At least 1 photo is required to publish.',
        style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 12),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _media.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final m = _media[index];
        final isImage = m.type == 'image';

        Widget child;
        if (isImage) {
          final src = m.localFile ??
              (m.url == null
                  ? null
                  : VPlatformFile.fromUrl(networkUrl: m.url!));
          if (src != null) {
            child = VPlatformCacheImageWidget(
              source: src,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(10),
            );
          } else {
            child = const Icon(CupertinoIcons.photo);
          }
        } else {
          // Video: show thumbnail if uploaded, otherwise play icon
          final videoUrl = m.url;
          final thumbnailUrl = videoUrl != null ? _buildCloudinaryVideoThumbnailUrl(videoUrl) : null;
          
          if (thumbnailUrl != null) {
            child = Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: VPlatformCacheImageWidget(
                    source: VPlatformFile.fromUrl(networkUrl: thumbnailUrl),
                    fit: BoxFit.cover,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.play_circle_fill,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          } else {
            child = Container(
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey5,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(CupertinoIcons.play_circle, size: 34),
              ),
            );
          }
        }

        return Stack(
          children: [
            Positioned.fill(child: child),
            if (isImage)
              Positioned(
                bottom: 6,
                right: 6,
                child: GestureDetector(
                  onTap: (_loading || m.isUpscaling)
                      ? null
                      : () => _upscaleMediaAt(index),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: m.isUpscaling
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CupertinoActivityIndicator(radius: 7),
                          )
                        : Icon(
                            m.isUpscaled
                                ? CupertinoIcons.check_mark_circled_solid
                                : CupertinoIcons.sparkles,
                            size: 14,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: _loading ? null : () => _removeMediaAt(index),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.xmark, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DraftMediaItem {
  VPlatformFile? localFile;
  String? url;
  String type; // image | video
  String? mimeType;
  bool isUpscaling = false;
  bool isUpscaled = false;

  _DraftMediaItem({
    this.localFile,
    this.url,
    required this.type,
    this.mimeType,
  });
}
