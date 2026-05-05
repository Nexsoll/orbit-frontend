// Stubbed web Places helpers for non-web platforms
// These functions are conditionally imported. On mobile/desktop they return empty results.

Future<List<dynamic>> placesAutocompleteRaw(String q) async => const [];

Future<List<dynamic>> placesTextSearchRaw(String q) async => const [];

Future<Map<String, dynamic>?> placesDetailsRaw(String placeId) async => null;
