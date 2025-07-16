import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../chat/chat_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final SupabaseClient _client = Supabase.instance.client;
  List<dynamic> contacts = [];
  List<dynamic> filteredContacts = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchContacts();
  }

  Future<void> fetchContacts() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      print("❌ No current user found.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await _client
          .from('users')
          .select()
          .neq('id', user.id); // Exclude current user

      print("✅ Contacts fetched: ${result.length}");

      setState(() {
        contacts = result;
        filteredContacts = result;
        isLoading = false;
      });
    } catch (e) {
      print("❌ Error fetching contacts: $e");
      setState(() => isLoading = false);
    }
  }

  void _filterContacts(String query) {
    final lower = query.toLowerCase();
    final results = contacts.where((user) {
      final name = user['username']?.toLowerCase() ?? '';
      final phone = user['phone_number']?.toLowerCase() ?? '';
      return name.contains(lower) || phone.contains(lower);
    }).toList();

    setState(() {
      searchQuery = query;
      filteredContacts = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff9f9f9),
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: const Text(
          'Daxia Chats',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh contacts",
            onPressed: fetchContacts,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _filterContacts,
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: fetchContacts,
                    child: filteredContacts.isEmpty
                        ? const Center(child: Text('No contacts found.'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemCount: filteredContacts.length,
                            itemBuilder: (context, index) {
                              final user = filteredContacts[index];
                              final avatar = user['avatar_url'] ?? '';
                              final name = user['username'] ?? 'Unknown';
                              final phone = user['phone_number'] ?? '';

                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: avatar.isNotEmpty
                                        ? NetworkImage(avatar)
                                        : null,
                                    child: avatar.isEmpty
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  title: Text(name),
                                  subtitle: Text(phone),
                                  trailing: const Icon(Icons.chat),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatView(partner: user),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
