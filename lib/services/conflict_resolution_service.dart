// services/conflict_resolution_service.dart
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../models/note.dart';

enum ConflictResolutionChoice {
  keepLocal,
  keepSession,
  merge,
  keepBoth,
}

class ConflictResolutionResult {
  final Note resolvedNote;
  final ConflictResolutionChoice choice;

  const ConflictResolutionResult({
    required this.resolvedNote,
    required this.choice,
  });
}

class ConflictResolutionService extends GetxController {
  /// Show conflict resolution dialog
  Future<ConflictResolutionResult?> showConflictDialog({
    required Note localNote,
    required Note sessionNote,
  }) async {
    return Get.dialog<ConflictResolutionResult>(
      ConflictResolutionDialog(
        localNote: localNote,
        sessionNote: sessionNote,
      ),
      barrierDismissible: false,
    );
  }

  /// Apply resolution choice to notes
  Note applyResolution(
    Note localNote,
    Note sessionNote,
    ConflictResolutionChoice choice,
  ) {
    switch (choice) {
      case ConflictResolutionChoice.keepLocal:
        return localNote.copyWith(
          version: localNote.version + 1,
          lastSyncedAt: DateTime.now(),
        );
      
      case ConflictResolutionChoice.keepSession:
        return sessionNote.copyWith(
          version: sessionNote.version + 1,
          lastSyncedAt: DateTime.now(),
        );
      
      case ConflictResolutionChoice.merge:
        return _mergeNotes(localNote, sessionNote);
      
      case ConflictResolutionChoice.keepBoth:
        return _createMergedNote(localNote, sessionNote);
    }
  }

  Note _mergeNotes(Note local, Note session) {
    // Simple merge strategy
    final mergedTitle = local.title != session.title 
        ? '${local.title} / ${session.title}' 
        : local.title;
    
    final mergedContent = local.content != session.content
        ? '${local.content}\n\n---\n\n${session.content}'
        : local.content;

    return Note(
      id: local.id,
      title: mergedTitle,
      content: mergedContent,
      createdAt: local.createdAt,
      updatedAt: DateTime.now(),
      lastSyncedAt: DateTime.now(),
      version: local.version + 1,
    );
  }

  Note _createMergedNote(Note local, Note session) {
    return local.copyWith(
      title: '${local.title} (Merged)',
      content: '''
Current Version:
${local.content}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Previous Session:
${session.content}
      ''',
      version: local.version + 1,
      lastSyncedAt: DateTime.now(),
    );
  }
}

// Conflict Resolution Dialog Widget
class ConflictResolutionDialog extends StatefulWidget {
  final Note localNote;
  final Note sessionNote;

  const ConflictResolutionDialog({
    Key? key,
    required this.localNote,
    required this.sessionNote,
  }) : super(key: key);

  @override
  State<ConflictResolutionDialog> createState() => _ConflictResolutionDialogState();
}

class _ConflictResolutionDialogState extends State<ConflictResolutionDialog> {
  ConflictResolutionChoice? _selectedChoice;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 8),
          Text('Data Conflict Detected'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 450,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The note "${widget.localNote.title}" has conflicting changes. Please choose how to resolve this:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            
            // Version comparison
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Current Version'),
                        Tab(text: 'Previous Session'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildVersionPreview(widget.localNote, 'Current'),
                          _buildVersionPreview(widget.sessionNote, 'Previous'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Resolution options
            Text(
              'Resolution Options:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            
            ...ConflictResolutionChoice.values.map((choice) {
              return RadioListTile<ConflictResolutionChoice>(
                title: Text(_getChoiceTitle(choice)),
                subtitle: Text(
                  _getChoiceDescription(choice),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: choice,
                groupValue: _selectedChoice,
                onChanged: (value) => setState(() => _selectedChoice = value),
                dense: true,
              );
            }).toList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedChoice != null ? _resolveConflict : null,
          child: const Text('Resolve'),
        ),
      ],
    );
  }

  Widget _buildVersionPreview(Note note, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                label == 'Current' ? Icons.phone_android : Icons.history,
                size: 16,
                color: label == 'Current' ? Colors.blue : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                '$label Version',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: label == 'Current' ? Colors.blue : Colors.orange,
                ),
              ),
              const Spacer(),
              Text(
                'Modified: ${_formatDate(note.updatedAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Title: ${note.title}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                note.content,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getChoiceTitle(ConflictResolutionChoice choice) {
    switch (choice) {
      case ConflictResolutionChoice.keepLocal:
        return 'Keep Current Version';
      case ConflictResolutionChoice.keepSession:
        return 'Keep Previous Version';
      case ConflictResolutionChoice.merge:
        return 'Merge Both Versions';
      case ConflictResolutionChoice.keepBoth:
        return 'Keep Both with Clear Separation';
    }
  }

  String _getChoiceDescription(ConflictResolutionChoice choice) {
    switch (choice) {
      case ConflictResolutionChoice.keepLocal:
        return 'Use the current version and discard previous changes';
      case ConflictResolutionChoice.keepSession:
        return 'Restore the previous version and discard current changes';
      case ConflictResolutionChoice.merge:
        return 'Automatically combine both versions';
      case ConflictResolutionChoice.keepBoth:
        return 'Combine both versions with clear separation';
    }
  }

  void _resolveConflict() {
    if (_selectedChoice == null) return;

    final service = Get.find<ConflictResolutionService>();
    final resolvedNote = service.applyResolution(
      widget.localNote,
      widget.sessionNote,
      _selectedChoice!,
    );

    Get.back(result: ConflictResolutionResult(
      resolvedNote: resolvedNote,
      choice: _selectedChoice!,
    ));
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}