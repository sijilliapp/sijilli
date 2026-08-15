import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pb_tag_service.dart';
import '../../../models/tag.dart';

class TagProvider extends ChangeNotifier {
  final PbTagService _tagService = PbTagService();
  
  List<Tag> _tags = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Tag> get tags => _tags;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String? _currentUserId;

  void updateAuth(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      _tags = [];
      _errorMessage = null;
      if (userId != null) {
        _loadCachedTags(userId);
        fetchTags();
      } else {
        notifyListeners();
      }
    }
  }

  Future<void> _loadCachedTags(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('cached_user_tags_$userId');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _tags = list.map((e) => Tag.fromJson(Map<String, dynamic>.from(e))).toList();
        notifyListeners();
      }
    } catch (e) {
      print('⚠️ Failed to load cached tags: $e');
    }
  }

  Future<void> _saveCachedTags() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_tags.map((t) => t.toJson()).toList());
      await prefs.setString('cached_user_tags_$_currentUserId', jsonStr);
    } catch (e) {
      print('⚠️ Failed to save cached tags: $e');
    }
  }

  /// Get tags for the user
  Future<void> fetchTags() async {
    if (_tags.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    _errorMessage = null;

    try {
      _tags = await _tagService.getUserTags();
      await _saveCachedTags();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new tag
  Future<Tag?> addTag(String name, String colorHex) async {
    try {
      final newTag = await _tagService.createTag(name: name, colorHex: colorHex);
      _tags.add(newTag);
      _tags.sort((a, b) => a.name.compareTo(b.name));
      await _saveCachedTags();
      notifyListeners();
      return newTag;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Update a tag
  Future<Tag?> updateTag(String id, String name, String colorHex) async {
    try {
      final updatedTag = await _tagService.updateTag(tagId: id, name: name, colorHex: colorHex);
      final index = _tags.indexWhere((t) => t.id == id);
      if (index != -1) {
        _tags[index] = updatedTag;
      }
      _tags.sort((a, b) => a.name.compareTo(b.name));
      await _saveCachedTags();
      notifyListeners();
      return updatedTag;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Delete a tag
  Future<void> deleteTag(String id) async {
    try {
      await _tagService.deleteTag(id);
      _tags.removeWhere((t) => t.id == id);
      await _saveCachedTags();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
