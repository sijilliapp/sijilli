// 📍 lib/features/appointments/providers/category_provider.dart
import 'package:flutter/material.dart';
import '../services/pb_category_service.dart';
import '../../../models/appointment.dart';

class CategoryProvider extends ChangeNotifier {
  final PbCategoryService _categoryService = PbCategoryService();
  
  List<AppointmentCategory> _categories = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AppointmentCategory> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String? _currentUserId;

  void updateAuth(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      _categories = [];
      _errorMessage = null;
      if (userId != null) {
        fetchCategories();
      } else {
        notifyListeners();
      }
    }
  }

  /// جلب التصنيفات المتاحة للمستخدم
  Future<void> fetchCategories() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _categories = await _categoryService.getCategories();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// إضافة تصنيف جديد
  Future<AppointmentCategory?> addCategory(String name, {String? color, String? icon}) async {
    try {
      final newCat = await _categoryService.createCategory(name, color: color, icon: icon);
      _categories.add(newCat);
      notifyListeners();
      return newCat;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// تحديث تصنيف
  Future<AppointmentCategory?> updateCategory(String id, String name, {String? color, String? icon}) async {
    try {
      final updatedCat = await _categoryService.updateCategory(id, name, color: color, icon: icon);
      final index = _categories.indexWhere((c) => c.id == id);
      if (index != -1) {
        _categories[index] = updatedCat;
      }
      notifyListeners();
      return updatedCat;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// حذف تصنيف
  Future<void> deleteCategory(String id) async {
    try {
      await _categoryService.deleteCategory(id);
      _categories.removeWhere((c) => c.id == id);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
