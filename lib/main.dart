// lib/main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controllers/note_controller.dart';
import 'services/sync_service.dart';
import 'services/connectivity_service.dart';
import 'services/conflict_resolution_service.dart';
import 'screens/note_list_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize GetX controllers
  _initializeServices();
  
  runApp(const OfflineNotesApp());
}

void _initializeServices() {
  // Register services in dependency injection
  Get.put(ConnectivityController(), permanent: true);
  Get.put(SyncService(), permanent: true);
  Get.put(ConflictResolutionService(), permanent: true);
  Get.put(NoteController(), permanent: true);
}

class OfflineNotesApp extends StatelessWidget {
  const OfflineNotesApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Offline Notes',
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey.shade50,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      home: const NoteListScreen(),
    );
  }
}