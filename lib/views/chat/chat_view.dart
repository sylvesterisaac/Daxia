import 'dart:io';

import 'package:daxia/viewmodels/chat_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

final chatViewModelProvider = ChangeNotifierProvider((ref) => ChatViewModel());

class ChatView extends ConsumerStatefulWidget {
  final Map<String, dynamic> partner;
  const ChatView({super.key, required this.partner});

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  Set<int> selectedMessageIds = {};
  bool isSelecting = false;
  bool isAllSelected = false;

  @override
  void initState() {
    super.initState();
    ref.read(chatViewModelProvider).initialize(widget.partner);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      try {
        await ref.read(chatViewModelProvider).sendImage(File(pickedFile.path));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('📤 Image sent')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Failed to send image: $e')));
      }
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (selectedMessageIds.contains(id)) {
        selectedMessageIds.remove(id);
      } else {
        selectedMessageIds.add(id);
      }
      isSelecting = selectedMessageIds.isNotEmpty;
      isAllSelected = false;
    });
  }

  void _selectAll(List<Map<String, dynamic>> allMessages) {
    final userMessages = allMessages
        .where(
          (msg) =>
              msg['sender_id'] == ref.read(chatViewModelProvider).currentUserId,
        )
        .map<int>((msg) => msg['id'] as int)
        .toList();
    setState(() {
      selectedMessageIds = Set.from(userMessages);
      isSelecting = true;
      isAllSelected = true;
    });
  }

  void _deselectAll() {
    setState(() {
      selectedMessageIds.clear();
      isSelecting = false;
      isAllSelected = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(chatViewModelProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: isSelecting
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: _deselectAll,
              )
            : BackButton(color: Colors.black),
        title: isSelecting
            ? Text(
                '${selectedMessageIds.length} selected',
                style: const TextStyle(color: Colors.black),
              )
            : Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(widget.partner['avatar_url']),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.partner['username'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
        actions: isSelecting
            ? [
                IconButton(
                  icon: Icon(
                    isAllSelected ? Icons.clear_all : Icons.select_all,
                    color: Colors.black,
                  ),
                  tooltip: isAllSelected ? 'Deselect All' : 'Select All',
                  onPressed: () => isAllSelected
                      ? _deselectAll()
                      : _selectAll(viewModel.messages),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete messages?'),
                        content: const Text('This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await viewModel.deleteMessages(
                        selectedMessageIds.toList(),
                      );
                      _deselectAll();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🗑 Messages deleted')),
                      );
                    }
                  },
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: viewModel.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: viewModel.groupedMessages.length,
                    itemBuilder: (context, index) {
                      final group = viewModel.groupedMessages[index];
                      final dateLabel = group['date'] as String;
                      final messages =
                          group['messages'] as List<Map<String, dynamic>>;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                dateLabel,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.teal,
                                ),
                              ),
                            ),
                          ),
                          ...messages.map((msg) {
                            final id = msg['id'] as int;
                            final isMe =
                                msg['sender_id'] == viewModel.currentUserId;
                            final seen = msg['seen'] ?? false;
                            final content = msg['content'] ?? '';
                            final isImage = msg['type'] == 'image';
                            final isSelected = selectedMessageIds.contains(id);

                            return GestureDetector(
                              onLongPress: isMe
                                  ? () => _toggleSelection(id)
                                  : null,
                              onTap: isSelecting && isMe
                                  ? () => _toggleSelection(id)
                                  : null,
                              child: Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  padding: const EdgeInsets.all(10),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.red.withOpacity(0.5)
                                        : isMe
                                        ? Colors.teal
                                        : Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      isImage
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.network(
                                                content,
                                                width: 200,
                                              ),
                                            )
                                          : Text(
                                              content,
                                              style: TextStyle(
                                                color: isMe
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                            ),
                                      const SizedBox(height: 4),
                                      Text(
                                        viewModel.formatTimestamp(
                                          msg['created_at'],
                                        ),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isMe
                                              ? Colors.white70
                                              : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Typing...', style: TextStyle(color: Colors.grey)),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: _pickImage,
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
                      ),
                      child: TextField(
                        controller: _controller,
                        onChanged: (text) =>
                            setState(() => _isTyping = text.isNotEmpty),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Type a message...',
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.teal),
                    onPressed: () async {
                      final text = _controller.text.trim();
                      if (text.isNotEmpty) {
                        await viewModel.sendMessage(text);
                        _controller.clear();
                        setState(() => _isTyping = false);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
