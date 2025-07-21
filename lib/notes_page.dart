import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Note {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  _NotesPageState createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  List<Note> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    String? currentUserJson = prefs.getString('currentUser');

    if (currentUserJson != null) {
      Map<String, dynamic> currentUser = jsonDecode(currentUserJson);
      String userId = currentUser['username'];

      List<String>? notesJson = prefs.getStringList('notes_$userId');

      if (notesJson != null) {
        setState(() {
          _notes = notesJson
              .map((noteStr) => Note.fromJson(jsonDecode(noteStr)))
              .toList();
          _notes.sort(
            (a, b) => b.createdAt.compareTo(a.createdAt),
          ); // Sort by newest first
          _isLoading = false;
        });
      } else {
        setState(() {
          _notes = [];
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    String? currentUserJson = prefs.getString('currentUser');

    if (currentUserJson != null) {
      Map<String, dynamic> currentUser = jsonDecode(currentUserJson);
      String userId = currentUser['username'];

      List<String> notesJson = _notes
          .map((note) => jsonEncode(note.toJson()))
          .toList();

      await prefs.setStringList('notes_$userId', notesJson);
    }
  }

  void _addNote() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorPage(
          isNewNote: true,
          note: Note(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: '',
            content: '',
            createdAt: DateTime.now(),
          ),
        ),
      ),
    );

    if (result != null && result is Note) {
      setState(() {
        _notes.insert(0, result); // Add to the beginning of the list
      });
      _saveNotes();
    }
  }

  void _editNote(int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            NoteEditorPage(isNewNote: false, note: _notes[index]),
      ),
    );

    if (result != null && result is Note) {
      setState(() {
        _notes[index] = result;
        _notes.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Re-sort
      });
      _saveNotes();
    }
  }

  void _deleteNote(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Note'),
        content: Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _notes.removeAt(index);
              });
              _saveNotes();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notes')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _notes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.note_alt_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No notes yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap the + button to create a note',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(
                      note.title.isEmpty ? 'Untitled Note' : note.title,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (note.content.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 4, bottom: 8),
                            child: Text(
                              note.content.length > 100
                                  ? '${note.content.substring(0, 100)}...'
                                  : note.content,
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        Text(
                          _formatDateTime(note.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _editNote(index),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteNote(index),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        tooltip: 'Add Note',
        child: Icon(Icons.add),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    String year = dateTime.year.toString();
    String month = dateTime.month.toString().padLeft(2, '0');
    String day = dateTime.day.toString().padLeft(2, '0');

    String hour =
        (dateTime.hour > 12
                ? dateTime.hour - 12
                : dateTime.hour == 0
                ? 12
                : dateTime.hour)
            .toString()
            .padLeft(2, '0');
    String minute = dateTime.minute.toString().padLeft(2, '0');
    String period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return "$year-$month-$day $hour:$minute $period";
  }
}

class NoteEditorPage extends StatefulWidget {
  final bool isNewNote;
  final Note note;

  const NoteEditorPage({
    super.key,
    required this.isNewNote,
    required this.note,
  });

  @override
  _NoteEditorPageState createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);

    // Listen for changes to detect if user has modified the note
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!_hasChanges &&
        (_titleController.text != widget.note.title ||
            _contentController.text != widget.note.content)) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    // If there are changes, show a confirmation dialog
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Discard changes?'),
            content: Text(
              'You have unsaved changes. Are you sure you want to discard them?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isNewNote ? 'New Note' : 'Edit Note'),
          actions: [
            IconButton(
              icon: Icon(Icons.check),
              onPressed: () {
                // Create updated note
                final updatedNote = Note(
                  id: widget.note.id,
                  title: _titleController.text.trim(),
                  content: _contentController.text.trim(),
                  createdAt: widget.isNewNote
                      ? DateTime.now()
                      : widget.note.createdAt,
                );

                // Return the updated note to the previous screen
                Navigator.pop(context, updatedNote);
              },
            ),
          ],
        ),
        body: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Title',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Divider(),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    hintText: 'Write your note here...',
                    border: InputBorder.none,
                  ),
                  style: TextStyle(fontSize: 16),
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
