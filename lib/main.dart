import 'package:flutter/material.dart';
import 'screens/image_picker_screen.dart';

void main(List<String> args) {
  // Optional: Accept a directory path as first argument
  final String? initialDirectory = args.isNotEmpty ? args[0] : null;

  runApp(MyApp(initialDirectory: initialDirectory));
}

class MyApp extends StatelessWidget {
  final String? initialDirectory;

  const MyApp({this.initialDirectory, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Picker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.dark,
      home: ImagePickerScreen(initialDirectory: initialDirectory),
    );
  }
}
