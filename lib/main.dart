import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const NotesApp());
}

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Заметки',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const NotesPage(),
    );
  }
}

class Note {
  Note({required this.id, required this.text, required this.createdAt});

  final String id;
  String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'] as String,
    text: json['text'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  static const String _storageKey = 'notes';

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<Note> _notes = <Note>[];
  Note? _editingNote;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_storageKey) ?? const <String>[];
    final loaded = raw
        .map(
          (String value) => Note.fromJson(
            Map<String, dynamic>.from(jsonDecode(value) as Map),
          ),
        )
        .toList();
    if (!mounted) return;
    setState(() {
      _notes
        ..clear()
        ..addAll(loaded);
    });
  }

  Future<void> _persistNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      _notes.map((Note note) => jsonEncode(note.toJson())).toList(),
    );
  }

  void _saveNote() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _focusNode.requestFocus();
      return;
    }

    final Note? editing = _editingNote;
    if (editing != null) {
      // Меняем текст того же объекта: позиция заметки в списке сохраняется.
      editing.text = text;
    } else {
      _notes.insert(
        0,
        Note(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          text: text,
          createdAt: DateTime.now(),
        ),
      );
    }

    setState(() => _editingNote = null);
    _controller.clear();
    _focusNode.requestFocus();
    _persistNotes();
  }

  void _startEditing(Note note) {
    setState(() {
      _editingNote = note;
      _controller.value = TextEditingValue(
        text: note.text,
        selection: TextSelection.collapsed(offset: note.text.length),
      );
    });
    _focusNode.requestFocus();
  }

  void _cancelEditing() {
    if (_editingNote == null) return;
    setState(() => _editingNote = null);
    _controller.clear();
  }

  void _deleteNote(Note note) {
    setState(() {
      _notes.removeWhere((Note element) => element.id == note.id);
      if (_editingNote?.id == note.id) {
        _editingNote = null;
        _controller.clear();
      }
    });
    _persistNotes();
  }

  Future<void> _askDelete(Note note) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Удалить заметку?'),
        content: Text(_ellipsis(note.text)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) _deleteNote(note);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = _editingNote != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заметки'),
        actions: <Widget>[
          if (isEditing)
            TextButton.icon(
              key: const Key('cancelEdit'),
              onPressed: _cancelEditing,
              icon: const Icon(Icons.close),
              label: const Text('Отмена'),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('noteInput'),
                    controller: _controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: isEditing
                          ? 'Измените текст и нажмите «Обновить»'
                          : 'Введите текст заметки…',
                      filled: true,
                      fillColor: isEditing ? Colors.amber.shade50 : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _saveNote(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    key: const Key('saveButton'),
                    onPressed: _saveNote,
                    icon: Icon(isEditing ? Icons.check : Icons.save),
                    label: Text(isEditing ? 'Обновить' : 'Сохранить'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _notes.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.sticky_note_2_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Заметок пока нет',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: _notes.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Note note = _notes[index];
                      return _NoteCard(
                        key: Key(note.id),
                        note: note,
                        isSelected: _editingNote?.id == note.id,
                        onTap: () => _startEditing(note),
                        onDelete: () => _askDelete(note),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _ellipsis(String text, {int limit = 80}) {
    if (text.length <= limit) return text;
    return '${text.substring(0, limit)}…';
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    super.key,
    required this.note,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  final Note note;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Dismissible(
      key: ValueKey<String>('dismiss_${note.id}'),
      direction: DismissDirection.endToStart,
      // Удаление всегда подтверждается диалогом, поэтому свайп сам по себе
      // не убирает элемент из списка.
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: isSelected ? Colors.amber.shade50 : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? BorderSide(color: Colors.amber.shade700, width: 1.5)
              : BorderSide.none,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          leading: Icon(
            isSelected ? Icons.edit_note : Icons.notes_outlined,
            color: isSelected ? Colors.amber.shade800 : Colors.grey,
          ),
          title: Text(note.text, style: theme.textTheme.bodyLarge),
          subtitle: Text(
            _formatDate(note.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Удалить',
            onPressed: onDelete,
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const List<String> months = <String>[
      'янв', 'фев', 'мар', 'апр', 'май', 'июн', //
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    final String hh = date.hour.toString().padLeft(2, '0');
    final String mm = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year}, $hh:$mm';
  }
}
