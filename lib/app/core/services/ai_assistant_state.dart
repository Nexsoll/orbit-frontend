import 'package:flutter/foundation.dart';
import 'openai_service.dart';

class AiAssistantState extends ChangeNotifier {
  static final AiAssistantState _instance = AiAssistantState._internal();
  factory AiAssistantState() => _instance;
  AiAssistantState._internal() {
    // Enable web search by default on initialization
    _isWebSearchEnabled = true;
    _openAIService.enableWebSearch();
    if (kDebugMode) {
      print('AiAssistantState initialized: Web search enabled by default');
    }
  }

  final OpenAIService _openAIService = OpenAIService();
  bool _isWebSearchEnabled = true;

  bool get isWebSearchEnabled => _isWebSearchEnabled;

  void toggleWebSearch() {
    _isWebSearchEnabled = !_isWebSearchEnabled;
    
    if (_isWebSearchEnabled) {
      _openAIService.enableWebSearch();
    } else {
      _openAIService.disableWebSearch();
    }
    
    notifyListeners();
    
    if (kDebugMode) {
      print('Web search toggled: $_isWebSearchEnabled');
    }
  }

  void enableWebSearch() {
    if (!_isWebSearchEnabled) {
      _isWebSearchEnabled = true;
      _openAIService.enableWebSearch();
      notifyListeners();
    }
  }

  void disableWebSearch() {
    if (_isWebSearchEnabled) {
      _isWebSearchEnabled = false;
      _openAIService.disableWebSearch();
      notifyListeners();
    }
  }
}
