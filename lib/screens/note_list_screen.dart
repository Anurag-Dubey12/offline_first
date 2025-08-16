// screens/note_list_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/note_controller.dart';
import '../models/data_source.dart';
import '../services/connectivity_service.dart';
import '../widgets/data_source_indicator.dart';
import 'note_detail_screen.dart';

class NoteListScreen extends StatelessWidget {
  const NoteListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final noteController = Get.find<NoteController>();
    final connectivityController = Get.find<ConnectivityController>();
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Notes'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.cloud),
                text: 'Online',
              ),
              Tab(
                icon: Icon(Icons.offline_pin),
                text: 'Offline',
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _showSearchDialog(context, noteController),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => noteController.refresh(),
            ),
            Obx(() => IconButton(
              icon: const Icon(Icons.sync),
              onPressed: connectivityController.isConnected 
                ? () => noteController.forceSyncOfflineToOnline()
                : null,
              tooltip: 'Sync offline notes to online',
            )),
          ],
        ),
        body: Column(
          children: [
            const DataSourceIndicator(),
            Expanded(
              child: TabBarView(
                children: [
                  _buildOnlineNotesTab(noteController),
                  _buildOfflineNotesTab(noteController),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _createNewNote(context, noteController),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildOnlineNotesTab(NoteController noteController) {
    return Obx(() {
      final onlineNotes = noteController.onlineNotes;
      
      if (noteController.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (noteController.hasError.value) {
        return _buildErrorWidget(noteController);
      }

      if (onlineNotes.isEmpty) {
        return _buildEmptyState('No online notes yet.\nNotes will appear here when synced!');
      }

      return _buildNotesList(onlineNotes, DataSource.online);
    });
  }

  Widget _buildOfflineNotesTab(NoteController noteController) {
    return Obx(() {
      final offlineNotes = noteController.offlineNotes;
      
      if (noteController.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (noteController.hasError.value) {
        return _buildErrorWidget(noteController);
      }

      if (offlineNotes.isEmpty) {
        return _buildEmptyState('No offline notes yet.\nCreate notes while offline to see them here!');
      }

      return _buildNotesList(offlineNotes, DataSource.offline);
    });
  }

  Widget _buildErrorWidget(NoteController noteController) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            noteController.errorMessage.value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => noteController.loadNotes(),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_add_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList(List notes, DataSource dataSource) {
    return RefreshIndicator(
      onRefresh: () => Get.find<NoteController>().refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                note.title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    note.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Modified: ${_formatDate(note.updatedAt)}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getDataSourceColor(dataSource),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getDataSourceText(dataSource),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: PopupMenuButton(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _editNote(context, note, Get.find<NoteController>());
                      break;
                    case 'delete':
                      _showDeleteConfirmation(context, note, Get.find<NoteController>());
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: () => _viewNote(context, note),
            ),
          );
        },
      ),
    );
  }

  Color _getDataSourceColor(DataSource dataSource) {
    switch (dataSource) {
      case DataSource.offline:
        return Colors.orange;
      case DataSource.online:
        return Colors.green;
      case DataSource.syncing:
        return Colors.blue;
    }
  }

  String _getDataSourceText(DataSource dataSource) {
    switch (dataSource) {
      case DataSource.offline:
        return 'OFFLINE';
      case DataSource.online:
        return 'ONLINE';
      case DataSource.syncing:
        return 'SYNC';
    }
  }

  void _createNewNote(BuildContext context, NoteController controller) {
    Get.to(() => const NoteDetailScreen(isCreating: true));
  }

  void _editNote(BuildContext context, note, NoteController controller) {
    Get.to(() => NoteDetailScreen(note: note, isEditing: true));
  }

  void _viewNote(BuildContext context, note) {
    Get.to(() => NoteDetailScreen(note: note));
  }

  void _showDeleteConfirmation(BuildContext context, note, NoteController controller) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              controller.deleteNote(note.id);
              Get.back();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context, NoteController controller) {
    String searchQuery = '';
    
    Get.dialog(
      AlertDialog(
        title: const Text('Search Notes'),
        content: TextField(
          onChanged: (value) => searchQuery = value,
          decoration: const InputDecoration(
            hintText: 'Enter search term...',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.loadNotes();
              Get.back();
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              controller.searchNotes(searchQuery);
              Get.back();
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
