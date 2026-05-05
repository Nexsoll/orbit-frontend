import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:super_up/app/modules/marketplace/services/marketplace_api_service.dart';
import 'package:super_up_core/super_up_core.dart';
import 'package:v_platform/v_platform.dart';

class MarketplaceListingPreviewView extends StatefulWidget {
  final Map<String, dynamic> payload;
  final Map<String, dynamic> previewData;

  const MarketplaceListingPreviewView({
    super.key,
    required this.payload,
    required this.previewData,
  });

  @override
  State<MarketplaceListingPreviewView> createState() =>
      _MarketplaceListingPreviewViewState();
}

class _MarketplaceListingPreviewViewState
    extends State<MarketplaceListingPreviewView> {
  late final MarketplaceApiService _api;
  bool _loading = false;

  static const _primaryBrown = Color(0xFFB48648);

  @override
  void initState() {
    super.initState();
    _api = GetIt.I.get<MarketplaceApiService>();
  }

  Future<void> _openImage(String url) async {
    if (url.trim().isEmpty) return;
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => VImageViewer(
          platformFileSource: VPlatformFile.fromUrl(networkUrl: url),
          downloadingLabel: 'Downloading...',
          showDownload: false,
          successfullyDownloadedInLabel: 'Downloaded in',
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

  Future<void> _openVideo(String url) async {
    if (url.trim().isEmpty) return;
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => VVideoPlayer(
          platformFileSource: VPlatformFile.fromUrl(networkUrl: url),
          downloadingLabel: 'Downloading...',
          showDownload: false,
          successfullyDownloadedInLabel: 'Downloaded in',
        ),
      ),
    );
  }

  String _formatKes(num? value) {
    if (value == null) return '';
    final f = NumberFormat('#,##0', 'en_KE');
    return 'KES ${f.format(value)}';
  }

  List<Map<String, dynamic>> get _media {
    final m = widget.previewData['media'];
    if (m is List) {
      return List<Map<String, dynamic>>.from(
        m.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
      );
    }
    return const [];
  }

  List<Map<String, dynamic>> get _images =>
      _media.where((m) => (m['type'] ?? '').toString() == 'image').toList();

  Map<String, dynamic>? get _video =>
      _media.where((m) => (m['type'] ?? '').toString() == 'video').firstOrNull;

  Future<void> _publish() async {
    setState(() => _loading = true);
    VAppAlert.showLoading(context: context);
    try {
      await _api.publish(widget.payload);
      if (!mounted) return;
      context.pop();
      VAppAlert.showSuccessSnackBar(context: context, message: 'Listing published');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      context.pop();
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _loading = true);
    VAppAlert.showLoading(context: context);
    try {
      final payload = Map<String, dynamic>.from(widget.payload);
      payload.remove('id');
      await _api.saveDraft(payload);
      if (!mounted) return;
      context.pop();
      VAppAlert.showSuccessSnackBar(context: context, message: 'Draft saved');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      context.pop();
      VAppAlert.showErrorSnackBar(context: context, message: e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.previewData['title'] ?? '').toString();
    final brand = (widget.previewData['brand'] ?? '').toString();
    final condition = (widget.previewData['condition'] ?? '').toString();
    final category = (widget.previewData['category'] ?? '').toString();
    final isRealEstate = category.trim().toLowerCase() == 'real estate';
    final isVehicle = category.trim().toLowerCase() == 'vehicles' ||
        category.trim().toLowerCase() == 'vehicle';
    final isElectronics = category.trim().toLowerCase() == 'electronics';
    final isHomeFurniture = category.trim().toLowerCase() == 'home & furniture' ||
        category.trim().toLowerCase() == 'home and furniture';
    final isClothingFashion = category.trim().toLowerCase() == 'clothing & fashion' ||
        category.trim().toLowerCase() == 'clothing and fashion' ||
        category.trim().toLowerCase() == 'fashion';
    final isPetsAnimals = category.trim().toLowerCase() == 'pets & animals' ||
        category.trim().toLowerCase() == 'pets and animals';
    final isServices = category.trim().toLowerCase() == 'services' ||
        category.trim().toLowerCase() == 'service';
    final isBusinessIndustrial = category.trim().toLowerCase() == 'business & industrial' ||
        category.trim().toLowerCase() == 'business and industrial';
    final isKidsBaby = category.trim().toLowerCase() == 'kids & baby' ||
        category.trim().toLowerCase() == 'kids and baby';
    final isSports = category.trim().toLowerCase() == 'sports' ||
        category.trim().toLowerCase() == 'sports & fitness' ||
        category.trim().toLowerCase() == 'sports and fitness';
    final cLower = category.trim().toLowerCase();
    final isBooksMusicHobbies = cLower.contains('book') ||
        (cLower.contains('music') && cLower.contains('hobb')) ||
        cLower == 'books, music & hobbies' ||
        cLower == 'books, music and hobbies' ||
        cLower == 'books music & hobbies' ||
        cLower == 'books music and hobbies' ||
        cLower == 'music & hobbies' ||
        cLower == 'music and hobbies' ||
        cLower == 'books' ||
        cLower == 'book';
    final isSpecial = isRealEstate || isVehicle;
    final desc = (widget.previewData['description'] ?? '').toString();
    final loc = (widget.previewData['locationLabel'] ?? '').toString();
    final price = (widget.previewData['price'] as num?);
    final ptRaw = (widget.previewData['priceType'] ?? '').toString();
    final priceType = ptRaw.trim().isEmpty
        ? ''
        : (ptRaw == 'negotiable' ? 'Negotiable' : 'Fixed');

    final delRaw = widget.previewData['deliveryAvailable'];
    final deliveryAvailable = (delRaw == true) ||
        (delRaw?.toString().trim().toLowerCase() == 'true');

    final tx = (widget.previewData['realEstateTransactionType'] ?? '').toString().trim();
    final txLower = tx.toLowerCase();
    final txDisplay = txLower == 'buy'
        ? 'Buy'
        : txLower == 'rent'
            ? 'Rent'
            : txLower == 'lease'
                ? 'Lease'
                : tx;
    final propertyType = (widget.previewData['realEstatePropertyType'] ?? '').toString().trim();
    final beds = widget.previewData['realEstateBedrooms'];
    final baths = widget.previewData['realEstateBathrooms'];
    final sqft = widget.previewData['realEstateSquareFootage'];
    final furnRaw = widget.previewData['realEstateFurnished'];
    final furnished = (furnRaw == true) || (furnRaw?.toString().trim().toLowerCase() == 'true');
    final amenitiesRaw = widget.previewData['realEstateAmenities'];
    final amenities = (amenitiesRaw is List)
        ? amenitiesRaw.map((e) => (e ?? '').toString().trim()).where((e) => e.isNotEmpty).toList()
        : const <String>[];
    final hasVideoTour = _video != null;

    final vehicleType = (widget.previewData['vehicleType'] ?? '').toString().trim();
    final vehicleMake = (widget.previewData['vehicleMake'] ?? '').toString().trim();
    final vehicleModel = (widget.previewData['vehicleModel'] ?? '').toString().trim();
    final vYear = widget.previewData['vehicleYear'];
    final vMileage = widget.previewData['vehicleMileage'];

    final transRaw = (widget.previewData['vehicleTransmission'] ?? '').toString().trim();
    final transLower = transRaw.toLowerCase();
    final transmission = transLower == 'automatic'
        ? 'Automatic'
        : transLower == 'manual'
            ? 'Manual'
            : transRaw;

    final fuelRaw = (widget.previewData['vehicleFuelType'] ?? '').toString().trim();
    final fuelLower = fuelRaw.toLowerCase();
    final fuel = fuelLower.isEmpty
        ? ''
        : fuelLower == 'gasoline'
            ? 'Gasoline'
            : fuelLower == 'diesel'
                ? 'Diesel'
                : fuelLower == 'hybrid'
                    ? 'Hybrid'
                    : fuelLower == 'electric'
                        ? 'Electric'
                        : fuelLower == 'lpg'
                            ? 'LPG'
                            : fuelRaw;

    final warrantyStatus =
        (widget.previewData['electronicsWarrantyStatus'] ?? '').toString().trim();

    final homeFurnitureItemDimensions =
        (widget.previewData['homeFurnitureItemDimensions'] ?? '').toString().trim();
    final homeFurniturePickupDeliveryNotes =
        (widget.previewData['homeFurniturePickupDeliveryNotes'] ?? '').toString().trim();

    final clothingFashionSize =
        (widget.previewData['clothingFashionSize'] ?? '').toString().trim();
    final clothingFashionColor =
        (widget.previewData['clothingFashionColor'] ?? '').toString().trim();

    final servicesCategoryRaw =
        (widget.previewData['servicesCategory'] ?? '').toString().trim();
    final servicesCategoryLower = servicesCategoryRaw.toLowerCase();
    final servicesCategory = servicesCategoryLower == 'home'
        ? 'Home'
        : servicesCategoryLower == 'professional'
            ? 'Professional'
            : servicesCategoryLower == 'personal'
                ? 'Personal'
                : servicesCategoryRaw;

    final reqBulkOrder = widget.previewData['businessIndustrialBulkOrder'];
    final businessIndustrialBulkOrder = (reqBulkOrder == true) ||
        (reqBulkOrder?.toString().trim().toLowerCase() == 'true');
    final minQtyRaw = widget.previewData['businessIndustrialMinQty'];
    final businessIndustrialMinQty = minQtyRaw is num
        ? minQtyRaw.toInt()
        : int.tryParse((minQtyRaw ?? '').toString().trim());

    final sportsTagsRaw = widget.previewData['sportsOutdoorGearTags'];
    final sportsOutdoorGearTags = (sportsTagsRaw is List)
        ? sportsTagsRaw
            .map((e) => (e ?? '').toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : const <String>[];

    final booksMusicHobbiesAuthor =
        (widget.previewData['booksMusicHobbiesAuthor'] ?? '').toString().trim();
    final booksMusicHobbiesInstrument =
        (widget.previewData['booksMusicHobbiesInstrument'] ?? '').toString().trim();
    final collectibleRaw = widget.previewData['booksMusicHobbiesCollectible'];
    final booksMusicHobbiesCollectible = (collectibleRaw == true) ||
        (collectibleRaw?.toString().trim().toLowerCase() == 'true');

    final petsAnimalsType =
        (widget.previewData['petsAnimalsType'] ?? '').toString().trim();
    final petsAnimalsBreed =
        (widget.previewData['petsAnimalsBreed'] ?? '').toString().trim();
    final petsAnimalsVaccinationRecords =
        (widget.previewData['petsAnimalsVaccinationRecords'] ?? '').toString().trim();

    final vin = (widget.previewData['vehicleVin'] ?? '').toString().trim();
    final history = (widget.previewData['vehicleHistoryNotes'] ?? '').toString().trim();

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Preview')),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _gallery(),
                    const SizedBox(height: 14),
                    if (price != null)
                      Text(
                        _formatKes(price),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                    if (price == null)
                      const Text(
                        'No price',
                        style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey),
                      ),
                    const SizedBox(height: 6),
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    if (category.isNotEmpty) _field('Category', category),
                    if (!isSpecial && !isHomeFurniture && !isPetsAnimals && !isServices && !isBusinessIndustrial && !isKidsBaby && !isSports && !isBooksMusicHobbies && brand.isNotEmpty)
                      _field('Brand', brand),
                    if (!isSpecial && !isPetsAnimals && !isServices && condition.isNotEmpty)
                      _field('Condition', condition),
                    if (isElectronics && warrantyStatus.isNotEmpty)
                      _field('Warranty status', warrantyStatus),
                    if (isHomeFurniture && homeFurnitureItemDimensions.isNotEmpty)
                      _field('Item dimensions', homeFurnitureItemDimensions),
                    if (isHomeFurniture && homeFurniturePickupDeliveryNotes.isNotEmpty)
                      _field('Pickup/Delivery notes', homeFurniturePickupDeliveryNotes),
                    if (isClothingFashion && clothingFashionSize.isNotEmpty)
                      _field('Size', clothingFashionSize),
                    if (isClothingFashion && clothingFashionColor.isNotEmpty)
                      _field('Color', clothingFashionColor),
                    if (isServices && servicesCategory.isNotEmpty)
                      _field('Service category', servicesCategory),
                    if (isBusinessIndustrial)
                      _field('Bulk order', businessIndustrialBulkOrder ? 'Yes' : 'No'),
                    if (isBusinessIndustrial && businessIndustrialBulkOrder && businessIndustrialMinQty != null)
                      _field('Min qty', businessIndustrialMinQty.toString()),
                    if (isSports && sportsOutdoorGearTags.isNotEmpty)
                      _field('Outdoor gear tags', sportsOutdoorGearTags.join(', ')),
                    if (isBooksMusicHobbies && booksMusicHobbiesAuthor.isNotEmpty)
                      _field('Author', booksMusicHobbiesAuthor),
                    if (isBooksMusicHobbies && booksMusicHobbiesInstrument.isNotEmpty)
                      _field('Instrument', booksMusicHobbiesInstrument),
                    if (isBooksMusicHobbies && booksMusicHobbiesCollectible)
                      _field('Collectible', 'Yes'),
                    if (isPetsAnimals && petsAnimalsType.isNotEmpty)
                      _field('Animal', petsAnimalsType),
                    if (isPetsAnimals && petsAnimalsBreed.isNotEmpty)
                      _field('Breed', petsAnimalsBreed),
                    if (isPetsAnimals && petsAnimalsVaccinationRecords.isNotEmpty)
                      _field('Vaccination records', petsAnimalsVaccinationRecords),
                    if (isRealEstate && txDisplay.isNotEmpty) _field('Transaction', txDisplay),
                    if (isRealEstate && propertyType.isNotEmpty) _field('Property type', propertyType),
                    if (isRealEstate && beds != null) _field('Bedrooms', beds.toString()),
                    if (isRealEstate && baths != null) _field('Bathrooms', baths.toString()),
                    if (isRealEstate && sqft != null) _field('Square footage', sqft.toString()),
                    if (isRealEstate) _field('Furnished', furnished ? 'Yes' : 'No'),
                    if (isRealEstate && amenities.isNotEmpty) _field('Amenities', amenities.join(', ')),
                    if (isRealEstate) _field('Video tour', hasVideoTour ? 'Yes' : 'No'),

                    if (isVehicle && vehicleType.isNotEmpty) _field('Vehicle type', vehicleType),
                    if (isVehicle && vehicleMake.isNotEmpty) _field('Make', vehicleMake),
                    if (isVehicle && vehicleModel.isNotEmpty) _field('Model', vehicleModel),
                    if (isVehicle && vYear != null) _field('Year', vYear.toString()),
                    if (isVehicle && vMileage != null) _field('Mileage', vMileage.toString()),
                    if (isVehicle && transmission.isNotEmpty) _field('Transmission', transmission),
                    if (isVehicle && fuel.isNotEmpty) _field('Fuel', fuel),
                    if (isVehicle && vin.isNotEmpty) _field('VIN / Chassis', vin),
                    if (isVehicle && history.isNotEmpty) _field('History', history),
                    if (priceType.isNotEmpty) _field('Price type', priceType),
                    if (loc.isNotEmpty) _field('Location', loc),
                    if (!isSpecial && !isPetsAnimals && !isServices)
                      _field('Delivery', deliveryAvailable ? 'Yes' : 'No'),
                    const SizedBox(height: 14),
                    if (desc.isNotEmpty) ...[
                      const Text('Description', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(desc),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      color: _primaryBrown,
                      onPressed: _loading ? null : _saveDraft,
                      child: const Text(
                        'Draft',
                        style: TextStyle(color: CupertinoColors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CupertinoButton(
                      color: _primaryBrown,
                      onPressed: _loading ? null : _publish,
                      child: const Text(
                        'Publish',
                        style: TextStyle(color: CupertinoColors.white),
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gallery() {
    final images = _images;
    final video = _video;

    if (images.isEmpty && video == null) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey5,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(child: Icon(CupertinoIcons.photo, size: 44)),
      );
    }

    final items = <Widget>[];
    for (final img in images) {
      final url = (img['url'] ?? '').toString();
      if (url.isEmpty) continue;
      items.add(
        GestureDetector(
          onTap: _loading ? null : () => _openImage(url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: VPlatformCacheImageWidget(
              source: VPlatformFile.fromUrl(networkUrl: url),
              fit: BoxFit.cover,
              size: const Size(double.infinity, 220),
            ),
          ),
        ),
      );
    }

    if (video != null) {
      final url = (video['url'] ?? '').toString();
      final thumbnailUrl = _buildCloudinaryVideoThumbnailUrl(url);
      
      Widget videoWidget;
      if (thumbnailUrl != null) {
        videoWidget = Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: VPlatformCacheImageWidget(
                source: VPlatformFile.fromUrl(networkUrl: thumbnailUrl),
                fit: BoxFit.cover,
                size: const Size(double.infinity, 220),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: CupertinoColors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Icon(
                  CupertinoIcons.play_circle_fill,
                  size: 54,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          ],
        );
      } else {
        videoWidget = Container(
          height: 220,
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey5,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Icon(CupertinoIcons.play_circle, size: 54),
          ),
        );
      }
      
      items.add(
        GestureDetector(
          onTap: _loading ? null : () => _openVideo(url),
          child: SizedBox(
            height: 220,
            child: videoWidget,
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: PageView(children: items),
    );
  }
}
