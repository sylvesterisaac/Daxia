import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatViewModel extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  late String currentUserId;
  late String chatId;
  late String partnerId;

  List<Map<String, dynamic>> messages = [];
  List<Map<String, dynamic>> groupedMessages = [];
  bool isLoading = true;

  void initialize(Map<String, dynamic> partner) {
    currentUserId = _client.auth.currentUser!.id;
    partnerId = partner['id'];
    chatId = _generateChatId(currentUserId, partnerId);
    fetchMessages();
    setupRealtime();
  }

  String _generateChatId(String id1, String id2) {
    return (id1.compareTo(id2) < 0) ? '${id1}_$id2' : '${id2}_$id1';
  }

  String formatTimestamp(String isoString) {
    final dt = DateTime.tryParse(isoString)?.toLocal();
    if (dt == null) return '';
    return DateFormat('hh:mm a').format(dt);
  }

  String _groupLabel(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      return 'Yesterday';
    } else {
      return DateFormat('d MMM, yyyy').format(date);
    }
  }

  void setupRealtime() {
    _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at')
        .listen((event) {
          messages = List<Map<String, dynamic>>.from(event);
          _groupMessages();
          markMessagesAsSeen();
          notifyListeners();
        });
  }

  Future<void> fetchMessages() async {
    final res = await _client
        .from('messages')
        .select()
        .eq('chat_id', chatId)
        .order('created_at');

    messages = List<Map<String, dynamic>>.from(res);
    isLoading = false;
    _groupMessages();
    markMessagesAsSeen();
    notifyListeners();
  }

  void _groupMessages() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final msg in messages) {
      final date = DateTime.tryParse(msg['created_at'])?.toLocal();
      if (date == null) continue;
      final label = _groupLabel(date);
      grouped.putIfAbsent(label, () => []).add(msg);
    }
    groupedMessages = grouped.entries
        .map((e) => {'date': e.key, 'messages': e.value})
        .toList();
  }

  Future<void> sendMessage(String content) async {
    try {
      await _client.from('messages').insert({
        'chat_id': chatId,
        'sender_id': currentUserId,
        'receiver_id': partnerId,
        'content': content,
        'type': 'text',
        'seen': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Failed to send message: $e');
    }
  }

  Future<void> sendImage(File image) async {
    final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      final imageBytes = await image.readAsBytes();

      final uploadResponse = await _client.storage
          .from('chat-images')
          .uploadBinary(
            'public/$filename',
            imageBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = _client.storage
          .from('chat-images')
          .getPublicUrl('public/$filename');

      await _client.from('messages').insert({
        'chat_id': chatId,
        'sender_id': currentUserId,
        'receiver_id': partnerId,
        'content': imageUrl,
        'type': 'image',
        'seen': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ sendImage failed: $e');
    }
  }

  Future<void> deleteMessages(List<int> messageIds) async {
    try {
      await _client.from('messages').delete().inFilter('id', messageIds);
      // ⬇️ Refresh from backend to sync fresh state
      await fetchMessages();
    } catch (e) {
      print('❌ Failed to delete messages: $e');
    }
  }

  Future<void> markMessagesAsSeen() async {
    final unseen = messages
        .where(
          (msg) => msg['receiver_id'] == currentUserId && msg['seen'] == false,
        )
        .map((msg) => msg['id'])
        .toList();

    if (unseen.isNotEmpty) {
      await _client
          .from('messages')
          .update({'seen': true, 'seen_at': DateTime.now().toIso8601String()})
          .inFilter('id', unseen.map((id) => id.toString()).toList());
    }
  }
}
