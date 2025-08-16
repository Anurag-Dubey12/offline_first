// controllers/note_controller.dart
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/note.dart';
import '../models/data_source.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';

class NoteController extends GetxController {
  final ConnectivityController _connectivityController = Get.find<ConnectivityController>();
  final SyncService _syncService = Get.find<SyncService>();
  
  // Observable variables
  final RxList<Note> notes = <Note>[].obs;
  final RxList<Note> onlineNotes = <Note>[].obs;
  final RxList<Note> offlineNotes = <Note>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool hasError = false.obs;
  final Rx<DataSource> currentDataSource = DataSource.offline.obs;

  // SharedPreferences keys
  static const String _offlineNotesKey = 'offline_notes';
  static const String _onlineNotesKey = 'online_notes';

  @override
  void onInit() {
    super.onInit();
    
    // Listen to connectivity changes
    ever(_connectivityController.connectivityInfo, (_) => _handleConnectivityChange());
    
    // Listen to sync events
    ever(_syncService.syncState, (_) => _handleSyncStateChange());
    
    loadNotes();
  }

  /// Handle connectivity changes
  void _handleConnectivityChange() async {
    final isConnected = _connectivityController.isConnected;
    
    if (isConnected && currentDataSource.value == DataSource.offline) {
      await _syncOfflineToOnlineAndClear();
    } else if (!isConnected && currentDataSource.value == DataSource.online) {
      currentDataSource.value = DataSource.offline;
      await loadNotes();
    }
  }

  /// Handle sync state changes
  void _handleSyncStateChange() {
    final syncStatus = _syncService.syncState.value.status;
    
    if (syncStatus == SyncStatus.syncing) {
      currentDataSource.value = DataSource.syncing;
    } else if (syncStatus == SyncStatus.success && _connectivityController.isConnected) {
      currentDataSource.value = DataSource.online;
    } else if (!_connectivityController.isConnected) {
      currentDataSource.value = DataSource.offline;
    }
  }

  /// Load notes from appropriate data source
  Future<void> loadNotes() async {
    try {
      isLoading.value = true;
      hasError.value = false;
      
      final loadedOfflineNotes = await _loadNotesFromOfflinePrefs();
      final loadedOnlineNotes = await _loadNotesFromOnlinePrefs();
      
      offlineNotes.assignAll(loadedOfflineNotes);
      onlineNotes.assignAll(loadedOnlineNotes);
      
      // Keep the combined notes list for backward compatibility
      if (_connectivityController.isConnected) {
        final mergedNotes = _mergeNotes(loadedOfflineNotes, loadedOnlineNotes);
        notes.assignAll(mergedNotes);
        currentDataSource.value = DataSource.online;
      } else {
        notes.assignAll(loadedOfflineNotes);
        currentDataSource.value = DataSource.offline;
      }
      
    } catch (e) {
      hasError.value = true;
      errorMessage.value = 'Failed to load notes: $e';
      Get.snackbar(
        'Error',
        'Failed to load notes',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Load notes from offline shared preferences
  Future<List<Note>> _loadNotesFromOfflinePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getString(_offlineNotesKey) ?? '[]';
    final List<dynamic> notesList = json.decode(notesJson);
    return notesList.map((json) => Note.fromJson(json)).toList();
  }

  /// Load notes from online shared preferences
  Future<List<Note>> _loadNotesFromOnlinePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getString(_onlineNotesKey) ?? '[]';
    final List<dynamic> notesList = json.decode(notesJson);
    return notesList.map((json) => Note.fromJson(json)).toList();
  }

  /// Save notes to offline shared preferences
  Future<void> _saveNotesToOfflinePrefs(List<Note> notesToSave) async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = json.encode(notesToSave.map((note) => note.toJson()).toList());
    await prefs.setString(_offlineNotesKey, notesJson);
  }

  /// Save notes to online shared preferences
  Future<void> _saveNotesToOnlinePrefs(List<Note> notesToSave) async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = json.encode(notesToSave.map((note) => note.toJson()).toList());
    await prefs.setString(_onlineNotesKey, notesJson);
  }

  /// Sync offline notes to online when connectivity is restored
  Future<void> _syncOfflineToOnline() async {
    try {
      currentDataSource.value = DataSource.syncing;
      
      // Load offline notes
      final offlineNotes = await _loadNotesFromOfflinePrefs();
      final onlineNotes = await _loadNotesFromOnlinePrefs();
      
      final mergedNotes = _mergeNotes(offlineNotes, onlineNotes);
      
      // Save merged notes to online preferences
      await _saveNotesToOnlinePrefs(mergedNotes);
      
      // Update current notes list
      notes.assignAll(mergedNotes);
      
      currentDataSource.value = DataSource.online;
      
      Get.snackbar(
        'Sync Complete',
        'Offline notes synced successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
      
    } catch (e) {
      currentDataSource.value = DataSource.offline;
      Get.snackbar(
        'Sync Failed',
        'Failed to sync offline notes: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Sync offline notes to online and clear offline storage
  Future<void> _syncOfflineToOnlineAndClear() async {
    try {
      currentDataSource.value = DataSource.syncing;
      
      // Load current offline and online notes
      final currentOfflineNotes = await _loadNotesFromOfflinePrefs();
      final currentOnlineNotes = await _loadNotesFromOnlinePrefs();
      
      if (currentOfflineNotes.isNotEmpty) {
        // Merge offline notes into online notes
        final mergedNotes = _mergeNotes(currentOfflineNotes, currentOnlineNotes);
        
        // Save merged notes to online storage
        await _saveNotesToOnlinePrefs(mergedNotes);
        
        // Clear offline storage after successful sync
        await _clearOfflineNotes();
        
        // Update observable lists
        onlineNotes.assignAll(mergedNotes);
        offlineNotes.clear();
        notes.assignAll(mergedNotes);
        
        Get.snackbar(
          'Sync Complete',
          '${currentOfflineNotes.length} offline notes synced and moved to online storage',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
      
      currentDataSource.value = DataSource.online;
      
    } catch (e) {
      currentDataSource.value = DataSource.offline;
      Get.snackbar(
        'Sync Failed',
        'Failed to sync offline notes: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Clear offline notes after successful sync
  Future<void> _clearOfflineNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_offlineNotesKey, '[]');
  }

  /// Simple merge strategy for notes
  List<Note> _mergeNotes(List<Note> offlineNotes, List<Note> onlineNotes) {
    final Map<String, Note> mergedMap = {};
    
    // Add online notes first
    for (final note in onlineNotes) {
      mergedMap[note.id] = note;
    }
    
    // Add or update with offline notes (offline takes precedence for conflicts)
    for (final note in offlineNotes) {
      final existingNote = mergedMap[note.id];
      if (existingNote == null || note.updatedAt.isAfter(existingNote.updatedAt)) {
        mergedMap[note.id] = note;
      }
    }
    
    return mergedMap.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Create a new note
  Future<void> createNote({
    required String title,
    required String content,
  }) async {
    try {
      final note = Note.create(title: title, content: content);
      
      if (_connectivityController.isConnected) {
        onlineNotes.insert(0, note);
        await _saveNotesToOnlinePrefs(onlineNotes);
        notes.insert(0, note);
      } else {
        offlineNotes.insert(0, note);
        await _saveNotesToOfflinePrefs(offlineNotes);
        notes.insert(0, note);
      }
      
      Get.snackbar(
        'Success',
        'Note created successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to create note: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Update an existing note
  Future<void> updateNote(Note note) async {
    try {
      final updatedNote = note.copyWith(updatedAt: DateTime.now());
      
      if (_connectivityController.isConnected) {
        final onlineIndex = onlineNotes.indexWhere((n) => n.id == note.id);
        if (onlineIndex != -1) {
          onlineNotes[onlineIndex] = updatedNote;
          await _saveNotesToOnlinePrefs(onlineNotes);
        }
      } else {
        final offlineIndex = offlineNotes.indexWhere((n) => n.id == note.id);
        if (offlineIndex != -1) {
          offlineNotes[offlineIndex] = updatedNote;
          await _saveNotesToOfflinePrefs(offlineNotes);
        }
      }
      
      // Update in combined notes list
      final index = notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        notes[index] = updatedNote;
      }
      
      Get.snackbar(
        'Success',
        'Note updated successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update note: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Delete a note
  Future<void> deleteNote(String noteId) async {
    try {
      if (_connectivityController.isConnected) {
        onlineNotes.removeWhere((note) => note.id == noteId);
        await _saveNotesToOnlinePrefs(onlineNotes);
      } else {
        offlineNotes.removeWhere((note) => note.id == noteId);
        await _saveNotesToOfflinePrefs(offlineNotes);
      }
      
      // Remove from combined notes list
      notes.removeWhere((note) => note.id == noteId);
      
      Get.snackbar(
        'Success',
        'Note deleted successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete note: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Search notes by title or content
  void searchNotes(String query) {
    if (query.isEmpty) {
      loadNotes();
      return;
    }

    final filteredNotes = notes.where((note) {
      return note.title.toLowerCase().contains(query.toLowerCase()) ||
             note.content.toLowerCase().contains(query.toLowerCase());
    }).toList();

    notes.assignAll(filteredNotes);
  }

  /// Refresh data and trigger sync if online
  Future<void> refresh() async {
    await loadNotes();
    if (_connectivityController.isConnected) {
      await _syncService.performSync();
    }
  }

  /// Force sync offline notes to online (manual trigger)
  Future<void> forceSyncOfflineToOnline() async {
    if (_connectivityController.isConnected) {
      await _syncOfflineToOnlineAndClear();
    } else {
      Get.snackbar(
        'No Connection',
        'Cannot sync without internet connection',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
