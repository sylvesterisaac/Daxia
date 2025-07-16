// main.dart
import 'package:daxia/splashScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qxridweumtgftynfmwvq.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF4cmlkd2V1bXRnZnR5bmZtd3ZxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxNDI1MTEsImV4cCI6MjA2NzcxODUxMX0.uvpLY0rkGJ-zDPQOeqEjLqHLTRq3ZANx3qTODdQbUlM',
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatsApp Clone',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const SplashScreen(),
    );
  }
}
