// repositories/database_helper.dart
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/note.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;
  static const String _databaseName = 'offline_notes.db';
  static const int _databaseVersion = 1;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _databaseName);

      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onConfigure: _onConfigure,
      );
    } catch (e) {
      throw Exception('Failed to initialize database: $e');
    }
  }

  // Enable foreign keys and other constraints
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_synced_at TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        version INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Create index for better query performance
    await db.execute('''
      CREATE INDEX idx_notes_updated_at ON notes(updated_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_notes_is_deleted ON notes(is_deleted)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
    // For now, we only have version 1
    if (oldVersion < newVersion) {
      // Add migration logic for future versions
      print('Upgrading database from version $oldVersion to $newVersion');
    }
  }

  // Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // Reset database (useful for testing)
  Future<void> deleteDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
