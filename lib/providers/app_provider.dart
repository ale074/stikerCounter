import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/sticker_button.dart';
import '../models/button_press.dart';
import '../services/database_service.dart';
import '../services/image_service.dart';

class AppProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final ImageService _imageService = ImageService();
  static const _uuid = Uuid();

  List<StickerButton> _buttons = [];
  Map<String, int> _todayCounts = {};
  Map<String, int> _totalCounts = {};
  int _buttonLimit = 10;
  bool _isLoading = false;

  /// Resolved absolute image paths for the UI.
  /// Key = button ID, Value = absolute path that works on this launch.
  /// This is separate from the model so the DB always keeps the relative path.
  final Map<String, String> _resolvedImagePaths = {};

  List<StickerButton> get buttons => _buttons;
  Map<String, int> get todayCounts => _todayCounts;
  Map<String, int> get totalCounts => _totalCounts;
  int get buttonLimit => _buttonLimit;
  bool get isLoading => _isLoading;

  /// Returns the resolved absolute path for a button's image.
  /// Use this in the UI instead of button.imagePath.
  String getImagePath(String buttonId) {
    return _resolvedImagePaths[buttonId] ?? '';
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    _buttonLimit = prefs.getInt('button_limit') ?? 10;

    await _loadButtons();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadButtons() async {
    _buttons = await _db.getAllButtons();

    // Resolve image paths for display — the model keeps the DB value untouched.
    _resolvedImagePaths.clear();
    for (final button in _buttons) {
      _resolvedImagePaths[button.id] =
          await _imageService.resolveImagePath(button.imagePath);
    }

    _todayCounts = {};
    _totalCounts = {};
    for (final button in _buttons) {
      _todayCounts[button.id] = await _db.getTodayPressesForButton(button.id);
      _totalCounts[button.id] = await _db.getTotalPressesForButton(button.id);
    }
  }

  Future<bool> addButton({
    required String name,
    required String imagePath,
    required bool removeBackground,
  }) async {
    final currentCount = await _db.getButtonCount();
    if (currentCount >= _buttonLimit) {
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      String processedPath;
      if (removeBackground) {
        processedPath = await _imageService.processImage(imagePath);
      } else {
        processedPath = await _imageService.saveOriginal(imagePath);
      }

      final button = StickerButton(
        id: _uuid.v4(),
        name: name,
        imagePath: processedPath, // relative path stored in DB
        createdAt: DateTime.now(),
      );

      await _db.insertButton(button);
      await _loadButtons();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> pressButton(String buttonId) async {
    final press = ButtonPress(
      id: _uuid.v4(),
      buttonId: buttonId,
      pressedAt: DateTime.now(),
    );

    await _db.recordPress(press);
    _todayCounts[buttonId] = (_todayCounts[buttonId] ?? 0) + 1;
    _totalCounts[buttonId] = (_totalCounts[buttonId] ?? 0) + 1;
    notifyListeners();
  }

  Future<void> deleteButton(String buttonId) async {
    // Use the resolved path to delete the actual file
    final resolvedPath = _resolvedImagePaths[buttonId];
    if (resolvedPath != null && resolvedPath.isNotEmpty) {
      await _imageService.deleteImage(resolvedPath);
    }
    await _db.deleteButton(buttonId);
    _resolvedImagePaths.remove(buttonId);
    await _loadButtons();
    notifyListeners();
  }

  Future<void> updateButtonSize(String buttonId, double size) async {
    final idx = _buttons.indexWhere((b) => b.id == buttonId);
    if (idx != -1) {
      // copyWith keeps the original relative imagePath from the DB
      final updated = _buttons[idx].copyWith(size: size);
      await _db.updateButton(updated);
      _buttons[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> updateButtonPosition(String buttonId, double x, double y) async {
    final idx = _buttons.indexWhere((b) => b.id == buttonId);
    if (idx != -1) {
      final updated = _buttons[idx].copyWith(posX: x, posY: y);
      await _db.updateButton(updated);
      _buttons[idx] = updated;
      notifyListeners();
    }
  }

  /// Update position in memory only (for live dragging) — no DB write.
  void updateButtonPositionLocal(String buttonId, double x, double y) {
    final idx = _buttons.indexWhere((b) => b.id == buttonId);
    if (idx != -1) {
      _buttons[idx] = _buttons[idx].copyWith(posX: x, posY: y);
      notifyListeners();
    }
  }

  Future<void> setButtonLimit(int limit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('button_limit', limit);
    _buttonLimit = limit;
    notifyListeners();
  }

  Future<Map<String, int>> getMonthlyPresses(String buttonId, int year) async {
    return await _db.getMonthlyPresses(buttonId, year);
  }

  Future<Map<String, Map<String, int>>> getAllButtonsMonthlyPresses(
      int year) async {
    return await _db.getAllButtonsMonthlyPresses(year);
  }
}
