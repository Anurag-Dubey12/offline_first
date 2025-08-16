// services/sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';
import '../repositories/note_repository.dart';
import '../models/conflict_resolution.dart';

enum SyncStatus {
  idle,
  syncing,
  success,
  error,
  conflict,
}

class SyncState {
  final SyncStatus status;
  final String? message;
  final int progress;
  final int total;
  final DateTime lastSyncTime;
  final List<ConflictItem> conflicts;

  const SyncState({
    required this.status,
    this.message,
    this.progress = 0,
    this.total = 0,
    required this.lastSyncTime,
    this.conflicts = const [],
  });

  double get progressPercentage {
    if (total == 0) return 0.0;
    return (progress / total).clamp(0.0, 1.0);
  }

  SyncState copyWith({
    SyncStatus? status,
    String? message,
    int? progress,
    int? total,
    DateTime? lastSyncTime,
    List<ConflictItem>? conflicts,
  }) {
    return SyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      progress: progress ?? this.progress,
      total: total ?? this.total,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      conflicts: conflicts ?? this.conflicts,
    );
  }
}

class ConflictItem {
  final Note localVersion;
  final Note sessionVersion;
  final String conflictType;

  const ConflictItem({
    required this.localVersion,
    required this.sessionVersion,
    required this.conflictType,
  });
}

class SyncService extends GetxController {
  final NoteRepository _repository = NoteRepository();
  
  // Observable sync state
  final Rx<SyncState> syncState = SyncState(
    status: SyncStatus.idle,
    lastSyncTime: DateTime.fromMillisecondsSinceEpoch(0),
  ).obs;

  // Reactive variables
  final RxBool dataChanged = false.obs;
  final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(0).obs;

  Timer? _periodicSyncTimer;
  bool _isSyncing = false;

  // Keys for SharedPreferences
  static const String _lastSyncKey = 'last_sync_time';
  static const String _sessionDataKey = 'session_data';
  static const String _syncVersionKey = 'sync_version';

  @override
  void onInit() {
    super.onInit();
    _initializeSync();
  }

  Future<void> _initializeSync() async {
    try {
      // Load last sync time
      final lastSync = await _getLastSyncTime();
      lastSyncTime.value = lastSync;
      
      syncState.value = syncState.value.copyWith(lastSyncTime: lastSync);

      // Check for session conflicts on app start
      await _checkForSessionConflicts();

      // Start periodic sync
      _startPeriodicSync();

      print('SyncService initialized successfully');
    } catch (e) {
      print('Failed to initialize SyncService: $e');
    }
  }

  /// Mark that data has changed and needs sync
  void markDataChanged() {
    dataChanged.value = true;
    _scheduleSync();
  }

  /// Schedule sync with debouncing
  void _scheduleSync() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = Timer(const Duration(seconds: 2), () {
      performSync();
    });
  }

  /// Perform synchronization
  Future<void> performSync() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _updateSyncState(status: SyncStatus.syncing, message: 'Starting sync...');

    try {
      await _performLocalSync();
      
      _updateSyncState(
        status: SyncStatus.success,
        message: 'Sync completed successfully',
        lastSyncTime: DateTime.now(),
      );
      
      // Update last sync time
      lastSyncTime.value = DateTime.now();
      await _setLastSyncTime(DateTime.now());
      dataChanged.value = false;

    } catch (e) {
      print('Sync failed: $e');
      _updateSyncState(
        status: SyncStatus.error,
        message: 'Sync failed: ${e.toString()}',
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Perform local synchronization between sessions
  Future<void> _performLocalSync() async {
    _updateSyncState(message: 'Checking for local changes...');
    
    // Get current data from database
    final currentNotes = await _repository.getAllNotes(includeDeleted: true);
    
    // Get session data (what we think the data should be)
    final sessionData = await _getSessionData();
    
    if (sessionData.isEmpty) {
      // First sync, save current state as session data
      await _saveSessionData(currentNotes);
      return;
    }

    // Compare current data with session data
    final conflicts = <ConflictItem>[];
    final sessionNotes = sessionData.map((data) => Note.fromMap(data)).toList();
    
    _updateSyncState(
      message: 'Checking for conflicts...',
      progress: 0,
      total: currentNotes.length,
    );

    for (int i = 0; i < currentNotes.length; i++) {
      final currentNote = currentNotes[i];
      final sessionNote = sessionNotes.cast<Note?>().firstWhere(
        (note) => note?.id == currentNote.id,
        orElse: () => null,
      );

      if (sessionNote != null && _hasConflict(currentNote, sessionNote)) {
        conflicts.add(ConflictItem(
          localVersion: currentNote,
          sessionVersion: sessionNote,
          conflictType: 'session_conflict',
        ));
      }

      _updateSyncState(progress: i + 1);
    }

    if (conflicts.isNotEmpty) {
      await _handleConflicts(conflicts);
    }

    // Update session data with current state
    await _saveSessionData(currentNotes);
  }

  /// Check for conflicts when app starts
  Future<void> _checkForSessionConflicts() async {
    final lastAppClose = await _getLastAppCloseTime();
    final sessionData = await _getSessionData();
    
    if (sessionData.isNotEmpty && lastAppClose != null) {
      final timeDiff = DateTime.now().difference(lastAppClose);
      
      // If app was closed for more than 1 minute, check for conflicts
      if (timeDiff.inMinutes > 1) {
        await _performLocalSync();
      }
    }
  }

  /// Handle conflicts by applying resolution strategies
  Future<void> _handleConflicts(List<ConflictItem> conflicts) async {
    _updateSyncState(
      status: SyncStatus.conflict,
      message: 'Resolving ${conflicts.length} conflicts...',
      conflicts: conflicts,
    );

    for (final conflict in conflicts) {
      final resolvedNote = await _resolveConflict(conflict);
      await _repository.updateNote(resolvedNote);
    }
  }

  /// Resolve individual conflicts
  Future<Note> _resolveConflict(ConflictItem conflict) async {
    // Simple Last-Write-Wins strategy
    final local = conflict.localVersion;
    final session = conflict.sessionVersion;

    if (local.updatedAt.isAfter(session.updatedAt)) {
      return local.copyWith(
        version: local.version + 1,
        lastSyncedAt: DateTime.now(),
      );
    } else {
      return session.copyWith(
        version: session.version + 1,
        lastSyncedAt: DateTime.now(),
      );
    }
  }

  /// Check if two notes are in conflict
  bool _hasConflict(Note current, Note session) {
    // Simple conflict detection based on timestamps and content
    return current.updatedAt != session.updatedAt ||
           current.title != session.title ||
           current.content != session.content ||
           current.isDeleted != session.isDeleted;
  }

  void _updateSyncState({
    SyncStatus? status,
    String? message,
    int? progress,
    int? total,
    DateTime? lastSyncTime,
    List<ConflictItem>? conflicts,
  }) {
    syncState.value = syncState.value.copyWith(
      status: status,
      message: message,
      progress: progress,
      total: total,
      lastSyncTime: lastSyncTime,
      conflicts: conflicts,
    );
  }

  void _startPeriodicSync() {
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (dataChanged.value) {
        performSync();
      }
    });
  }

  // SharedPreferences helper methods
  Future<DateTime> _getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastSyncKey) ?? 0;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<void> _setLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncKey, time.millisecondsSinceEpoch);
  }

  Future<List<Map<String, dynamic>>> _getSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_sessionDataKey) ?? '[]';
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.cast<Map<String, dynamic>>();
  }

  Future<void> _saveSessionData(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = notes.map((note) => note.toMap()).toList();
    final jsonString = json.encode(jsonList);
    await prefs.setString(_sessionDataKey, jsonString);
  }

  Future<DateTime?> _getLastAppCloseTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('last_app_close_time');
    return timestamp != null ? DateTime.fromMillisecondsSinceEpoch(timestamp) : null;
  }

  Future<void> _saveAppCloseTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_app_close_time', DateTime.now().millisecondsSinceEpoch);
  }

  @override
  void onClose() {
    _periodicSyncTimer?.cancel();
    _saveAppCloseTime();
    super.onClose();
  }
}
