import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/appointment_model.dart';

class DatabaseService {
  static Database? _database;
  static const String _appointmentsKey = 'cached_appointments';

  Future<Database?> get database async {
    if (kIsWeb) return null; // Don't use SQLite on web
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database?> _initDatabase() async {
    if (kIsWeb) return null;

    // For mobile/desktop platforms
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);
    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE appointments (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        region TEXT,
        building TEXT,
        privacy TEXT NOT NULL,
        status TEXT NOT NULL,
        appointment_date TEXT NOT NULL,
        date_type TEXT,
        host_id TEXT NOT NULL,
        stream_link TEXT,
        note_shared TEXT,
        created TEXT NOT NULL,
        updated TEXT NOT NULL
      )
    ''');
  }

  // Save appointments to local database
  Future<void> saveAppointments(List<AppointmentModel> appointments) async {
    if (kIsWeb) {
      // Use SharedPreferences for web
      final prefs = await SharedPreferences.getInstance();
      final jsonList = appointments.map((a) => a.toJson()).toList();
      await prefs.setString(_appointmentsKey, jsonEncode(jsonList));
    } else {
      // Use SQLite for mobile/desktop
      final db = await database;
      if (db == null) return;

      final batch = db.batch();
      batch.delete('appointments');
      for (var appointment in appointments) {
        batch.insert('appointments', appointment.toMap());
      }
      await batch.commit(noResult: true);
    }
  }

  // Get appointments from local database
  Future<List<AppointmentModel>> getAppointments() async {
    if (kIsWeb) {
      // Use SharedPreferences for web
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_appointmentsKey);
      if (jsonString == null) return [];

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => AppointmentModel.fromJson(json)).toList();
    } else {
      // Use SQLite for mobile/desktop
      final db = await database;
      if (db == null) return [];

      final List<Map<String, dynamic>> maps = await db.query(
        'appointments',
        orderBy: 'appointment_date DESC',
      );
      return List.generate(maps.length, (i) {
        return AppointmentModel.fromMap(maps[i]);
      });
    }
  }

  // Clear all appointments
  Future<void> clearAppointments() async {
    if (kIsWeb) {
      // Use SharedPreferences for web
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_appointmentsKey);
    } else {
      // Use SQLite for mobile/desktop
      final db = await database;
      if (db == null) return;
      await db.delete('appointments');
    }
  }

  // Close database
  Future<void> close() async {
    if (kIsWeb) return;

    final db = await database;
    if (db == null) return;
    await db.close();
    _database = null;
  }
}
