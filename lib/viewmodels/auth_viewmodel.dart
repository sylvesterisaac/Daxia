// lib/viewmodels/auth_viewmodel.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Provider;

final authViewModelProvider = Provider<AuthViewModel>((ref) {
  return AuthViewModel();
});

class AuthViewModel {
  final SupabaseClient _client = Supabase.instance.client;

  /// Sign up with email, then store username + phone number
  Future<void> signUpWithUsernamePhoneEmail({
    required String email,
    required String username,
    required String phoneNumber,
  }) async {
    const defaultPassword = 'default123';

    final response = await _client.auth.signUp(
      email: email,
      password: defaultPassword,
    );

    final userId = response.user?.id;
    if (userId == null) throw Exception("Failed to sign up");

    await _client.from('users').insert({
      'id': userId,
      'email': email,
      'username': username,
      'phone_number': phoneNumber,
      'avatar_url': 'https://i.pravatar.cc/150',
      'is_online': true,
      'last_seen': DateTime.now().toIso8601String(),
    });
  }

  Future<void> loginWithUsernameAndPhone({
    required String username,
    required String phoneNumber,
  }) async {
    try {
      final result = await _client
          .from('users')
          .select('email')
          .eq('username', username)
          .eq('phone_number', phoneNumber)
          .maybeSingle();

      if (result == null) {
        throw Exception("Invalid username or phone number.");
      }

      final email = result['email'];
      const defaultPassword = 'default123';

      final response = await _client.auth.signInWithPassword(
        email: email,
        password: defaultPassword,
      );

      if (response.user == null) {
        throw Exception("Login failed. Supabase didn't return user.");
      }

      print('✅ Login success for $email');
    } catch (e) {
      print('❌ Login error: $e');
      rethrow;
    }
  }

  /// Check if user profile exists
  Future<bool> userProfileExists(String userId) async {
    final res = await _client
        .from('users')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    return res != null;
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;
}
