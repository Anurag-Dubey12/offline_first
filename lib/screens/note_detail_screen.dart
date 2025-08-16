// screens/note_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/note_controller.dart';
import '../models/note.dart';

class NoteDetailScreen extends StatefulWidget {
  final Note? note;
  final bool isCreating;
  final bool isEditing;

  const NoteDetailScreen({
    Key? key,
    this.note,
    this.isCreating = false,
    this.isEditing = false,
  }) : super(key: key);

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final NoteController _noteController = Get.find<NoteController>();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCreating 
          ? 'New Note' 
          : widget.isEditing 
            ? 'Edit Note' 
            : 'View Note'),
        actions: [
          if (widget.isCreating || widget.isEditing)
            TextButton(
              onPressed: _saveNote,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              readOnly: !widget.isCreating && !widget.isEditing,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                readOnly: !widget.isCreating && !widget.isEditing,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      Get.snackbar('Error', 'Please enter a title');
      return;
    }

    if (widget.isCreating) {
      await _noteController.createNote(title: title, content: content);
    } else if (widget.isEditing && widget.note != null) {
      final updatedNote = widget.note!.copyWith(
        title: title,
        content: content,
      );
      await _noteController.updateNote(updatedNote);
    }

    Get.back();
  }
}
