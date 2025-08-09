// models/conflict_resolution.dart
import 'dart:math' as math;

import 'package:offline_first/models/note.dart';

enum ConflictResolutionStrategy {
  lastWriteWins,
  keepBoth,
  userChoice,
  merge,
}

class ConflictResolution {
  final Note localVersion;
  final Note remoteVersion;
  final ConflictResolutionStrategy strategy;

  const ConflictResolution({
    required this.localVersion,
    required this.remoteVersion,
    required this.strategy,
  });

  // Detect if two notes are in conflict
  static bool hasConflict(Note local, Note remote) {
    // No conflict if they're the same version
    if (local.version == remote.version && 
        local.updatedAt == remote.updatedAt) {
      return false;
    }

    // Conflict exists if both were modified after last sync
    final localSyncTime = local.lastSyncedAt;
    final remoteSyncTime = remote.lastSyncedAt;

    if (localSyncTime == null || remoteSyncTime == null) {
      return true; // Assume conflict if sync time is unknown
    }

    return local.updatedAt.isAfter(localSyncTime) && 
           remote.updatedAt.isAfter(remoteSyncTime);
  }

  // Resolve conflict based on strategy
  Note resolve() {
    switch (strategy) {
      case ConflictResolutionStrategy.lastWriteWins:
        return _resolveLastWriteWins();
      case ConflictResolutionStrategy.keepBoth:
        return _resolveKeepBoth();
      case ConflictResolutionStrategy.merge:
        return _resolveMerge();
      case ConflictResolutionStrategy.userChoice:
        // This would typically show a UI dialog
        // For now, fall back to LWW
        return _resolveLastWriteWins();
    }
  }

  Note _resolveLastWriteWins() {
    if (localVersion.updatedAt.isAfter(remoteVersion.updatedAt)) {
      return localVersion.copyWith(
        version: remoteVersion.version + 1,
        lastSyncedAt: DateTime.now(),
      );
    } else {
      return remoteVersion.copyWith(
        version: localVersion.version + 1,
        lastSyncedAt: DateTime.now(),
      );
    }
  }

  Note _resolveKeepBoth() {
    // Create a new note with combined content
    return localVersion.copyWith(
      title: '${localVersion.title} (Conflicted)',
      content: '''
Local Version:
${localVersion.content}

---

Remote Version:
${remoteVersion.content}
      ''',
      version: math.max(localVersion.version, remoteVersion.version) + 1,
      lastSyncedAt: DateTime.now(),
    );
  }

  Note _resolveMerge() {
    // Simple merge strategy: combine titles and content
    final mergedTitle = _mergeText(localVersion.title, remoteVersion.title);
    final mergedContent = _mergeText(localVersion.content, remoteVersion.content);

    return Note(
      id: localVersion.id,
      title: mergedTitle,
      content: mergedContent,
      createdAt: localVersion.createdAt,
      updatedAt: DateTime.now(),
      lastSyncedAt: DateTime.now(),
      version: math.max(localVersion.version, remoteVersion.version) + 1,
    );
  }

  String _mergeText(String local, String remote) {
    if (local == remote) return local;
    
    // Simple merge: if one is a subset of the other, use the longer one
    if (local.contains(remote)) return local;
    if (remote.contains(local)) return remote;
    
    // Otherwise, combine both with a separator
    return '$local\n\n---\n\n$remote';
  }
}