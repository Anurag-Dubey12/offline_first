// repositories/note_repository.dart
import 'package:sqflite/sqflite.dart';
import '../models/note.dart';
import 'database_helper.dart';

class NoteRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  static const String _tableName = 'notes';

  // Create a new note
  Future<Note> createNote(Note note) async {
    try {
      final db = await _databaseHelper.database;
      await db.insert(
        _tableName,
        note.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return note;
    } catch (e) {
      throw RepositoryException('Failed to create note: $e');
    }
  }

  // Get all notes (excluding deleted ones by default)
  Future<List<Note>> getAllNotes({bool includeDeleted = false}) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: includeDeleted ? null : 'is_deleted = ?',
        whereArgs: includeDeleted ? null : [0],
        orderBy: 'updated_at DESC',
      );

      return maps.map((map) => Note.fromMap(map)).toList();
    } catch (e) {
      throw RepositoryException('Failed to get notes: $e');
    }
  }

  // Get a specific note by ID
  Future<Note?> getNoteById(String id) async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'id = ? AND is_deleted = ?',
        whereArgs: [id, 0],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return Note.fromMap(maps.first);
    } catch (e) {
      throw RepositoryException('Failed to get note: $e');
    }
  }

  // Update an existing note
  Future<Note> updateNote(Note note) async {
    try {
      final db = await _databaseHelper.database;
      final updatedNote = note.copyWith(updatedAt: DateTime.now());
      
      final rowsAffected = await db.update(
        _tableName,
        updatedNote.toMap(),
        where: 'id = ?',
        whereArgs: [note.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      if (rowsAffected == 0) {
        throw RepositoryException('Note not found for update');
      }

      return updatedNote;
    } catch (e) {
      throw RepositoryException('Failed to update note: $e');
    }
  }

  // Soft delete a note (mark as deleted instead of removing)
  Future<void> deleteNote(String id) async {
    try {
      final db = await _databaseHelper.database;
      final rowsAffected = await db.update(
        _tableName,
        {
          'is_deleted': 1,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsAffected == 0) {
        throw RepositoryException('Note not found for deletion');
      }
    } catch (e) {
      throw RepositoryException('Failed to delete note: $e');
    }
  }

  // Get notes that need to be synced (modified after last sync)
  Future<List<Note>> getUnsyncedNotes() async {
    try {
      final db = await _databaseHelper.database;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'last_synced_at IS NULL OR updated_at > last_synced_at',
      );

      return maps.map((map) => Note.fromMap(map)).toList();
    } catch (e) {
      throw RepositoryException('Failed to get unsynced notes: $e');
    }
  }

  // Update sync status for a note
  Future<void> markAsSynced(String id) async {
    try {
      final db = await _databaseHelper.database;
      await db.update(
        _tableName,
        {'last_synced_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw RepositoryException('Failed to mark note as synced: $e');
    }
  }
}

// Custom exception for repository operations
class RepositoryException implements Exception {
  final String message;
  RepositoryException(this.message);

  @override
  String toString() => 'RepositoryException: $message';
}