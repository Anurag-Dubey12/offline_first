import 'package:flutter/material.dart';
import '../models/note.dart';
import '../repositories/note_repository.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({Key? key}) : super(key: key);

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  final NoteRepository _repository = NoteRepository();
  List<Note> _notes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final notes = await _repository.getAllNotes();
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load notes: $e');
    }
  }

  Future<void> _addNote() async {
    final note = Note.create(
      title: 'New Note',
      content: 'Start writing your thoughts...',
    );
    try {
      await _repository.createNote(note);
      _loadNotes();
    } catch (e) {
      _showError('Failed to create note: $e');
    }
  }

  Future<void> _deleteNote(Note note) async {
    try {
      await _repository.deleteNote(note.id);
      _loadNotes();
    } catch (e) {
      _showError('Failed to delete note: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.black),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Notes',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadNotes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : _notes.isEmpty
              ? const Center(
                  child: Text(
                    'No notes yet.\nTap + to create your first one!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 16),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notes.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.black12),
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        note.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        note.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.black54),
                        onPressed: () => _deleteNote(note),
                      ),
                      onTap: () {
                        
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        onPressed: _addNote,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
