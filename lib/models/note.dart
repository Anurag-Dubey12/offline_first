import 'package:json_annotation/json_annotation.dart';

part 'note.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Note {
  final String id;
  final String title;
  final String content;

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  @JsonKey(name: 'last_synced_at')
  final DateTime? lastSyncedAt;

  @JsonKey(name: 'is_deleted', fromJson: _boolFromInt, toJson: _boolToInt)
  final bool isDeleted;

  final int version;

  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.lastSyncedAt,
    this.isDeleted = false,
    this.version = 1,
  });

  factory Note.create({
    required String title,
    required String content,
    String? id,
  }) {
    final now = DateTime.now();
    return Note(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
  }

  Note copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    DateTime? lastSyncedAt,
    bool? isDeleted,
    int? version,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      version: version ?? (this.version + 1),
    );
  }

  // JSON serialization
  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);
  Map<String, dynamic> toJson() => _$NoteToJson(this);

  // SQLite convenience
  Map<String, dynamic> toMap() => toJson();
  factory Note.fromMap(Map<String, dynamic> map) => _$NoteFromJson(map);

  static bool _boolFromInt(int value) => value == 1;
  static int _boolToInt(bool value) => value ? 1 : 0;
}
