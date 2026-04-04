import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const ChatApp());

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Chat Assistant',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = []; // Now includes timestamp
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isLoadingHistory = true;

  // Base URL
  final String _baseUrl = 'http://localhost:8000'; // Chrome / iOS
  // final String _baseUrl = 'http://192.168.101.7:8000'; // Android device

  String get _chatUrl => '$_baseUrl/chat';
  String get _historyUrl => '$_baseUrl/history';

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final response = await http.get(Uri.parse(_historyUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> messagesJson = data['messages'];
        setState(() {
          _messages.clear();
          for (var msg in messagesJson) {
            _messages.add({
              'role': msg['role'],
              'content': msg['content'],
              'timestamp': msg['timestamp'], // keep original timestamp string
            });
          }
        });
      }
    } catch (e) {
      print('Error loading history: $e');
    } finally {
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _sendMessage() async {
    final userMessage = _controller.text.trim();
    if (userMessage.isEmpty) return;

    // Temporary timestamp for UI (will be replaced after reload, but fine)
    final now = DateTime.now().toIso8601String();
    setState(() {
      _messages.add({"role": "user", "content": userMessage, "timestamp": now});
      _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse(_chatUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": userMessage}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data["reply"];
        setState(() {
          _messages.add({
            "role": "assistant",
            "content": reply,
            "timestamp": now,
          });
        });
        _scrollToBottom();
        // Optionally reload full history from backend to get exact timestamps
        _loadChatHistory();
      } else {
        setState(() {
          _messages.add({
            "role": "assistant",
            "content": "Error: ${response.statusCode}",
            "timestamp": now,
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          "role": "assistant",
          "content": "Network error: $e",
          "timestamp": now,
        });
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
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

  void _scrollToMessage(int index) {
    // Reverse index because ListView.builder uses reverse: true
    final reversedIndex = _messages.length - 1 - index;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        reversedIndex * 80.0, // approximate height per item, adjust as needed
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _clearHistory() async {
    try {
      final response = await http.delete(Uri.parse(_historyUrl));
      if (response.statusCode == 200) {
        setState(() => _messages.clear());
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Chat history cleared')));
      }
    } catch (e) {
      print('Error clearing history: $e');
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.day}/${date.month}';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'AI Chat Service',
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
      ),
      // Sidebar (Drawer)
      drawer: Drawer(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15.0,
                  vertical: 10.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Chat History',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Colors.white,
                            title: const Text('Clear History'),
                            content: const Text(
                              'Are you sure you want to delete all messages?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _clearHistory();
                                },
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      tooltip: 'Clear',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoadingHistory
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isUser = msg['role'] == 'user';
                          final timestamp = _formatTimestamp(msg['timestamp']);
                          return ListTile(
                            leading: Icon(
                              isUser ? Icons.person : Icons.smart_toy,
                              color: isUser ? Colors.blue : Colors.green,
                            ),
                            title: Text(
                              msg['content'].length > 50
                                  ? '${msg['content'].substring(0, 50)}...'
                                  : msg['content'],
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              timestamp,
                              style: const TextStyle(fontSize: 10),
                            ),
                            onTap: () {
                              Navigator.pop(context); // close drawer
                              _scrollToMessage(index);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[_messages.length - 1 - index];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.blue[300] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(msg['content']!),
                        ),
                      );
                    },
                  ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask something...',
                      hintStyle: const TextStyle(fontSize: 15),
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: Colors.blue,
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
