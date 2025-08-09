import 'package:flutter/material.dart';
import 'screens/note_list_screen.dart';

void main() {
  runApp(const OfflineNotesApp());
}

class OfflineNotesApp extends StatelessWidget {
  const OfflineNotesApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Offline Notes',
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.white,
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.black,
        ),
      ),
      home: const NoteListScreen(),
    );
  }
}
