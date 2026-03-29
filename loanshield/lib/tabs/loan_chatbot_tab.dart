import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoanChatbotTab extends StatefulWidget {
  const LoanChatbotTab({super.key});

  @override
  State<LoanChatbotTab> createState() => _LoanChatbotTabState();
}

class _LoanChatbotTabState extends State<LoanChatbotTab>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isLoading = false;
  bool _isSending = false;  // New: Track if currently sending
  String? _sessionId;

  // Voice Recognition
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _voiceText = '';

  final String baseUrl =
      "https://b667-2409-40f4-145-274a-dc3b-a949-2be8-896e.ngrok-free.app";

  // Storage keys
  static const String _messagesKey = 'loan_chat_messages';
  static const String _sessionKey = 'loan_chat_session';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    
    // Add listener to text controller to update send button state
    _messageController.addListener(() {
      setState(() {
        // This will rebuild the UI when text changes
      });
    });
    
    _loadChatHistory();
  }

  // ================= PERSISTENCE =================

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load session ID
      _sessionId = prefs.getString(_sessionKey);
      
      // Load messages
      final messagesJson = prefs.getString(_messagesKey);
      if (messagesJson != null) {
        final List<dynamic> decoded = jsonDecode(messagesJson);
        setState(() {
          _messages.clear();
          _messages.addAll(
            decoded.map((json) => ChatMessage.fromJson(json)).toList(),
          );
        });
      }

      // If no messages exist, add welcome message
      if (_messages.isEmpty) {
        _addWelcomeMessage();
      }

      // Create new session if none exists
      if (_sessionId == null) {
        await _createSession();
      } else {
        print("Restored Session: $_sessionId");
      }

      _scrollToBottom();
    } catch (e) {
      print("Error loading chat history: $e");
      _addWelcomeMessage();
      await _createSession();
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save session ID
      if (_sessionId != null) {
        await prefs.setString(_sessionKey, _sessionId!);
      }
      
      // Save messages
      final messagesJson = jsonEncode(
        _messages.map((msg) => msg.toJson()).toList(),
      );
      await prefs.setString(_messagesKey, messagesJson);
      
      print("Chat history saved");
    } catch (e) {
      print("Error saving chat history: $e");
    }
  }

  Future<void> _clearChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_messagesKey);
      await prefs.remove(_sessionKey);
      
      setState(() {
        _messages.clear();
        _sessionId = null;
      });
      
      _addWelcomeMessage();
      await _createSession();
      
      _showSnackBar('Chat history cleared');
    } catch (e) {
      print("Error clearing chat history: $e");
    }
  }

  // ================= SESSION CREATION =================

  Future<void> _createSession() async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/create-session"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _sessionId = data["sessionId"];
        print("Session Created: $_sessionId");
        await _saveChatHistory(); // Save session ID
      } else {
        print("Session creation failed");
      }
    } catch (e) {
      print("Error creating session: $e");
    }
  }

  void _addWelcomeMessage() {
    _messages.add(
      ChatMessage(
        text:
            "👋 Hello! I'm your Loan Assistant.\n\n📄 Upload a loan document to analyze\n💬 Ask me anything about loan terms\n🔍 I'll detect hidden charges and risky clauses",
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
    _saveChatHistory();
  }

  // ================= VOICE INPUT =================

  Future<void> _toggleListening() async {
    if (_isListening) {
      // Stop listening
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      // Request microphone permission
      final status = await Permission.microphone.request();
      
      if (status.isGranted) {
        // Initialize speech recognition
        bool available = await _speech.initialize(
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') {
              setState(() => _isListening = false);
            }
          },
          onError: (error) {
            setState(() => _isListening = false);
            _showSnackBar('Error: ${error.errorMsg}');
          },
        );

        if (available) {
          setState(() => _isListening = true);
          
          // Start listening
          _speech.listen(
            onResult: (result) {
              setState(() {
                _voiceText = result.recognizedWords;
                _messageController.text = _voiceText;
              });
            },
            listenFor: const Duration(seconds: 30),
            pauseFor: const Duration(seconds: 3),
            partialResults: true,
            cancelOnError: true,
          );
        } else {
          _showSnackBar('Speech recognition not available');
        }
      } else {
        _showSnackBar('Microphone permission denied');
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ================= PDF UPLOAD =================

  Future<void> _uploadDocument() async {
    if (_sessionId == null) {
      _addBotMessage("⏳ Session not ready. Please wait a moment...");
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null) return;

      Uint8List? bytes = result.files.first.bytes;
      if (bytes == null) return;

      // Add user message showing upload
      setState(() {
        _messages.add(
          ChatMessage(
            text: "📎 Uploaded: ${result.files.first.name}",
            isUser: true,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = true;
      });
      _saveChatHistory();
      _scrollToBottom();

      String extractedText = _extractTextFromPdf(bytes);

      if (extractedText.trim().isEmpty) {
        _addBotMessage(
            "⚠️ This PDF appears to be image-based. Please upload a text-based PDF for analysis.");
        setState(() => _isLoading = false);
        return;
      }

      extractedText =
          extractedText.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');

      final response = await http.post(
        Uri.parse("$baseUrl/analyze-document"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "sessionId": _sessionId,
          "documentText": extractedText,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _addBotMessage(data["analysis"]);
      } else {
        _addBotMessage("❌ Server error: ${response.statusCode}");
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _addBotMessage("❌ Error processing document.");
    }
  }

  String _extractTextFromPdf(Uint8List bytes) {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfTextExtractor extractor = PdfTextExtractor(document);
    String text = extractor.extractText();
    document.dispose();
    return text;
  }

  // ================= CHAT =================

  void _sendMessage() async {
    // Prevent multiple sends
    if (_isSending) {
      print("Already sending a message");
      return;
    }
    
    final trimmedText = _messageController.text.trim();
    
    if (trimmedText.isEmpty) {
      _showSnackBar('Please enter a message');
      return;
    }
    
    if (_sessionId == null) {
      _addBotMessage("⏳ Session not ready. Please wait...");
      return;
    }

    String userMessage = trimmedText;

    setState(() {
      _isSending = true;
      _messages.add(
        ChatMessage(
          text: userMessage,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isLoading = true;
    });

    _messageController.clear();
    _saveChatHistory();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "sessionId": _sessionId,
          "message": userMessage,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _addBotMessage(data["reply"]);
      } else {
        _addBotMessage("❌ Server error.");
      }
    } catch (e) {
      _addBotMessage("❌ Connection error. Please check your internet.");
    }

    setState(() {
      _isLoading = false;
      _isSending = false;
    });
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE74C3C)),
            SizedBox(width: 12),
            Text('Clear Chat History'),
          ],
        ),
        content: const Text(
          'Are you sure you want to clear all messages? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearChatHistory();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0B3C5D),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance, size: 24),
            ),
            const SizedBox(width: 12),
            const Text(
              'Loan Assistant',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          // Clear chat button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _messages.length > 1 ? _showClearConfirmation : null,
            tooltip: 'Clear Chat',
          ),
          // Upload button
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _uploadDocument,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: const [
                      Icon(Icons.upload_file, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Upload PDF',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            Container(
              height: 3,
              child: const LinearProgressIndicator(
                backgroundColor: Color(0xFFE0E0E0),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1ABC9C)),
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _buildMessageBubble(_messages[index]),
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0B3C5D).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance,
              size: 64,
              color: Color(0xFF0B3C5D),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Welcome to Loan Assistant',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0B3C5D),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Upload a document or start chatting',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final hasText = _messageController.text.trim().isNotEmpty;
    final canSend = hasText && !_isSending && !_isLoading;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SafeArea(
        child: Row(
          children: [
            // Voice Input Button
            Container(
              decoration: BoxDecoration(
                color: _isListening
                    ? const Color(0xFFE74C3C)
                    : const Color(0xFF0B3C5D),
                borderRadius: BorderRadius.circular(12),
                boxShadow: _isListening
                    ? [
                        BoxShadow(
                          color: const Color(0xFFE74C3C).withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggleListening,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Text Input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isListening
                        ? const Color(0xFFE74C3C)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: _isListening
                        ? "Listening..."
                        : "Ask about loans or terms...",
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(fontSize: 15),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) {
                    if (canSend) {
                      _sendMessage();
                    }
                  },
                  enabled: !_isSending,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Send Button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: canSend
                    ? const LinearGradient(
                        colors: [Color(0xFF1ABC9C), Color(0xFF16A085)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: !canSend ? Colors.grey[300] : null,
                borderRadius: BorderRadius.circular(12),
                boxShadow: canSend
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1ABC9C).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canSend ? _sendMessage : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _isSending
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.grey[500]!,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: canSend ? Colors.white : Colors.grey[500],
                            size: 24,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0B3C5D),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: message.isUser
                        ? const LinearGradient(
                            colors: [Color(0xFF0B3C5D), Color(0xFF1B4F72)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: message.isUser ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(message.isUser ? 20 : 4),
                      bottomRight: Radius.circular(message.isUser ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : Colors.black87,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1ABC9C),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.person_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  // Convert ChatMessage to JSON
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Create ChatMessage from JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}















// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:syncfusion_flutter_pdf/pdf.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:permission_handler/permission_handler.dart';

// class LoanChatbotTab extends StatefulWidget {
//   const LoanChatbotTab({super.key});

//   @override
//   State<LoanChatbotTab> createState() => _LoanChatbotTabState();
// }

// class _LoanChatbotTabState extends State<LoanChatbotTab>
//     with AutomaticKeepAliveClientMixin {
//   final TextEditingController _messageController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();
//   final List<ChatMessage> _messages = [];

//   bool _isLoading = false;
//   String? _sessionId;

//   // Voice Recognition
//   late stt.SpeechToText _speech;
//   bool _isListening = false;
//   String _voiceText = '';

//   final String baseUrl =
//       "https://9480-2409-40f4-308a-da12-148d-2936-193d-4e51.ngrok-free.app";

//   @override
//   bool get wantKeepAlive => true;

//   @override
//   void initState() {
//     super.initState();
//     _speech = stt.SpeechToText();
//     _createSession();
//     _addWelcomeMessage();
//   }

//   // ================= SESSION CREATION =================

//   Future<void> _createSession() async {
//     try {
//       final response = await http.post(
//         Uri.parse("$baseUrl/create-session"),
//         headers: {"Content-Type": "application/json"},
//       );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         _sessionId = data["sessionId"];
//         print("Session Created: $_sessionId");
//       } else {
//         print("Session creation failed");
//       }
//     } catch (e) {
//       print("Error creating session: $e");
//     }
//   }

//   void _addWelcomeMessage() {
//     _messages.add(
//       ChatMessage(
//         text:
//             "👋 Hello! I'm your Loan Assistant.\n\n📄 Upload a loan document to analyze\n💬 Ask me anything about loan terms\n🔍 I'll detect hidden charges and risky clauses",
//         isUser: false,
//         timestamp: DateTime.now(),
//       ),
//     );
//   }

//   // ================= VOICE INPUT =================

//   Future<void> _toggleListening() async {
//     if (_isListening) {
//       // Stop listening
//       await _speech.stop();
//       setState(() => _isListening = false);
//     } else {
//       // Request microphone permission
//       final status = await Permission.microphone.request();
      
//       if (status.isGranted) {
//         // Initialize speech recognition
//         bool available = await _speech.initialize(
//           onStatus: (status) {
//             if (status == 'done' || status == 'notListening') {
//               setState(() => _isListening = false);
//             }
//           },
//           onError: (error) {
//             setState(() => _isListening = false);
//             _showSnackBar('Error: ${error.errorMsg}');
//           },
//         );

//         if (available) {
//           setState(() => _isListening = true);
          
//           // Start listening
//           _speech.listen(
//             onResult: (result) {
//               setState(() {
//                 _voiceText = result.recognizedWords;
//                 _messageController.text = _voiceText;
//               });
//             },
//             listenFor: const Duration(seconds: 30),
//             pauseFor: const Duration(seconds: 3),
//             partialResults: true,
//             cancelOnError: true,
//           );
//         } else {
//           _showSnackBar('Speech recognition not available');
//         }
//       } else {
//         _showSnackBar('Microphone permission denied');
//       }
//     }
//   }

//   void _showSnackBar(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       ),
//     );
//   }

//   // ================= PDF UPLOAD =================

//   Future<void> _uploadDocument() async {
//     if (_sessionId == null) {
//       _addBotMessage("⏳ Session not ready. Please wait a moment...");
//       return;
//     }

//     try {
//       FilePickerResult? result = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: ['pdf'],
//         withData: true,
//       );

//       if (result == null) return;

//       Uint8List? bytes = result.files.first.bytes;
//       if (bytes == null) return;

//       // Add user message showing upload
//       setState(() {
//         _messages.add(
//           ChatMessage(
//             text: "📎 Uploaded: ${result.files.first.name}",
//             isUser: true,
//             timestamp: DateTime.now(),
//           ),
//         );
//         _isLoading = true;
//       });
//       _scrollToBottom();

//       String extractedText = _extractTextFromPdf(bytes);

//       if (extractedText.trim().isEmpty) {
//         _addBotMessage(
//             "⚠️ This PDF appears to be image-based. Please upload a text-based PDF for analysis.");
//         setState(() => _isLoading = false);
//         return;
//       }

//       extractedText =
//           extractedText.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');

//       final response = await http.post(
//         Uri.parse("$baseUrl/analyze-document"),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({
//           "sessionId": _sessionId,
//           "documentText": extractedText,
//         }),
//       );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         _addBotMessage(data["analysis"]);
//       } else {
//         _addBotMessage("❌ Server error: ${response.statusCode}");
//       }

//       setState(() => _isLoading = false);
//     } catch (e) {
//       setState(() => _isLoading = false);
//       _addBotMessage("❌ Error processing document.");
//     }
//   }

//   String _extractTextFromPdf(Uint8List bytes) {
//     final PdfDocument document = PdfDocument(inputBytes: bytes);
//     final PdfTextExtractor extractor = PdfTextExtractor(document);
//     String text = extractor.extractText();
//     document.dispose();
//     return text;
//   }

//   // ================= CHAT =================

//   void _sendMessage() async {
//     if (_messageController.text.trim().isEmpty) return;
//     if (_sessionId == null) {
//       _addBotMessage("⏳ Session not ready. Please wait...");
//       return;
//     }

//     String userMessage = _messageController.text;

//     setState(() {
//       _messages.add(
//         ChatMessage(
//           text: userMessage,
//           isUser: true,
//           timestamp: DateTime.now(),
//         ),
//       );
//       _isLoading = true;
//     });

//     _messageController.clear();
//     _scrollToBottom();

//     try {
//       final response = await http.post(
//         Uri.parse("$baseUrl/chat"),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({
//           "sessionId": _sessionId,
//           "message": userMessage,
//         }),
//       );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         _addBotMessage(data["reply"]);
//       } else {
//         _addBotMessage("❌ Server error.");
//       }
//     } catch (e) {
//       _addBotMessage("❌ Connection error. Please check your internet.");
//     }

//     setState(() => _isLoading = false);
//   }

//   void _addBotMessage(String text) {
//     setState(() {
//       _messages.add(
//         ChatMessage(
//           text: text,
//           isUser: false,
//           timestamp: DateTime.now(),
//         ),
//       );
//     });
//     _scrollToBottom();
//   }

//   void _scrollToBottom() {
//     Future.delayed(const Duration(milliseconds: 100), () {
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           _scrollController.position.maxScrollExtent,
//           duration: const Duration(milliseconds: 300),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }

//   // ================= UI =================

//   @override
//   Widget build(BuildContext context) {
//     super.build(context);

//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F7FA),
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: const Color(0xFF0B3C5D),
//         title: Row(
//           children: [
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.2),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: const Icon(Icons.account_balance, size: 24),
//             ),
//             const SizedBox(width: 12),
//             const Text(
//               'Loan Assistant',
//               style: TextStyle(
//                 fontWeight: FontWeight.w600,
//                 fontSize: 20,
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           Container(
//             margin: const EdgeInsets.only(right: 8),
//             child: Material(
//               color: Colors.white.withOpacity(0.2),
//               borderRadius: BorderRadius.circular(12),
//               child: InkWell(
//                 onTap: _uploadDocument,
//                 borderRadius: BorderRadius.circular(12),
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                   child: Row(
//                     children: const [
//                       Icon(Icons.upload_file, size: 20),
//                       SizedBox(width: 6),
//                       Text(
//                         'Upload PDF',
//                         style: TextStyle(
//                           fontWeight: FontWeight.w500,
//                           fontSize: 14,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           if (_isLoading)
//             Container(
//               height: 3,
//               child: const LinearProgressIndicator(
//                 backgroundColor: Color(0xFFE0E0E0),
//                 valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1ABC9C)),
//               ),
//             ),
//           Expanded(
//             child: _messages.isEmpty
//                 ? _buildEmptyState()
//                 : ListView.builder(
//                     controller: _scrollController,
//                     padding: const EdgeInsets.all(16),
//                     itemCount: _messages.length,
//                     itemBuilder: (context, index) =>
//                         _buildMessageBubble(_messages[index]),
//                   ),
//           ),
//           _buildInputArea(),
//         ],
//       ),
//     );
//   }

//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Container(
//             padding: const EdgeInsets.all(24),
//             decoration: BoxDecoration(
//               color: const Color(0xFF0B3C5D).withOpacity(0.1),
//               shape: BoxShape.circle,
//             ),
//             child: const Icon(
//               Icons.account_balance,
//               size: 64,
//               color: Color(0xFF0B3C5D),
//             ),
//           ),
//           const SizedBox(height: 24),
//           const Text(
//             'Welcome to Loan Assistant',
//             style: TextStyle(
//               fontSize: 24,
//               fontWeight: FontWeight.bold,
//               color: Color(0xFF0B3C5D),
//             ),
//           ),
//           const SizedBox(height: 12),
//           Text(
//             'Upload a document or start chatting',
//             style: TextStyle(
//               fontSize: 16,
//               color: Colors.grey[600],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildInputArea() {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 10,
//             offset: const Offset(0, -2),
//           ),
//         ],
//       ),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       child: SafeArea(
//         child: Row(
//           children: [
//             // Voice Input Button
//             Container(
//               decoration: BoxDecoration(
//                 color: _isListening
//                     ? const Color(0xFFE74C3C)
//                     : const Color(0xFF0B3C5D),
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: _isListening
//                     ? [
//                         BoxShadow(
//                           color: const Color(0xFFE74C3C).withOpacity(0.3),
//                           blurRadius: 8,
//                           spreadRadius: 2,
//                         ),
//                       ]
//                     : [],
//               ),
//               child: Material(
//                 color: Colors.transparent,
//                 child: InkWell(
//                   onTap: _toggleListening,
//                   borderRadius: BorderRadius.circular(12),
//                   child: Padding(
//                     padding: const EdgeInsets.all(12),
//                     child: Icon(
//                       _isListening ? Icons.mic : Icons.mic_none,
//                       color: Colors.white,
//                       size: 24,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(width: 12),
//             // Text Input
//             Expanded(
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFF5F7FA),
//                   borderRadius: BorderRadius.circular(24),
//                   border: Border.all(
//                     color: _isListening
//                         ? const Color(0xFFE74C3C)
//                         : Colors.transparent,
//                     width: 2,
//                   ),
//                 ),
//                 child: TextField(
//                   controller: _messageController,
//                   decoration: InputDecoration(
//                     hintText: _isListening
//                         ? "Listening..."
//                         : "Ask about loans or terms...",
//                     hintStyle: TextStyle(
//                       color: Colors.grey[400],
//                       fontSize: 15,
//                     ),
//                     border: InputBorder.none,
//                     contentPadding: const EdgeInsets.symmetric(
//                       horizontal: 20,
//                       vertical: 12,
//                     ),
//                   ),
//                   style: const TextStyle(fontSize: 15),
//                   maxLines: null,
//                   textCapitalization: TextCapitalization.sentences,
//                   onSubmitted: (_) => _sendMessage(),
//                 ),
//               ),
//             ),
//             const SizedBox(width: 12),
//             // Send Button
//             Container(
//               decoration: BoxDecoration(
//                 gradient: const LinearGradient(
//                   colors: [Color(0xFF1ABC9C), Color(0xFF16A085)],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: const Color(0xFF1ABC9C).withOpacity(0.3),
//                     blurRadius: 8,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Material(
//                 color: Colors.transparent,
//                 child: InkWell(
//                   onTap: _messageController.text.trim().isEmpty
//                       ? null
//                       : _sendMessage,
//                   borderRadius: BorderRadius.circular(12),
//                   child: Padding(
//                     padding: const EdgeInsets.all(12),
//                     child: Icon(
//                       Icons.send_rounded,
//                       color: Colors.white,
//                       size: 24,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildMessageBubble(ChatMessage message) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 16),
//       child: Row(
//         mainAxisAlignment:
//             message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           if (!message.isUser) ...[
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: const Color(0xFF0B3C5D),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: const Icon(
//                 Icons.smart_toy_outlined,
//                 color: Colors.white,
//                 size: 20,
//               ),
//             ),
//             const SizedBox(width: 8),
//           ],
//           Flexible(
//             child: Column(
//               crossAxisAlignment: message.isUser
//                   ? CrossAxisAlignment.end
//                   : CrossAxisAlignment.start,
//               children: [
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 12,
//                   ),
//                   decoration: BoxDecoration(
//                     gradient: message.isUser
//                         ? const LinearGradient(
//                             colors: [Color(0xFF0B3C5D), Color(0xFF1B4F72)],
//                             begin: Alignment.topLeft,
//                             end: Alignment.bottomRight,
//                           )
//                         : null,
//                     color: message.isUser ? null : Colors.white,
//                     borderRadius: BorderRadius.only(
//                       topLeft: const Radius.circular(20),
//                       topRight: const Radius.circular(20),
//                       bottomLeft: Radius.circular(message.isUser ? 20 : 4),
//                       bottomRight: Radius.circular(message.isUser ? 4 : 20),
//                     ),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Colors.black.withOpacity(0.08),
//                         blurRadius: 8,
//                         offset: const Offset(0, 2),
//                       ),
//                     ],
//                   ),
//                   child: Text(
//                     message.text,
//                     style: TextStyle(
//                       color: message.isUser ? Colors.white : Colors.black87,
//                       fontSize: 15,
//                       height: 1.4,
//                     ),
//                   ),
//                 ),
//                 Padding(
//                   padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
//                   child: Text(
//                     _formatTime(message.timestamp),
//                     style: TextStyle(
//                       fontSize: 11,
//                       color: Colors.grey[500],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           if (message.isUser) ...[
//             const SizedBox(width: 8),
//             Container(
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: const Color(0xFF1ABC9C),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: const Icon(
//                 Icons.person_outline,
//                 color: Colors.white,
//                 size: 20,
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   String _formatTime(DateTime time) {
//     final hour = time.hour.toString().padLeft(2, '0');
//     final minute = time.minute.toString().padLeft(2, '0');
//     return '$hour:$minute';
//   }

//   @override
//   void dispose() {
//     _messageController.dispose();
//     _scrollController.dispose();
//     _speech.stop();
//     super.dispose();
//   }
// }

// class ChatMessage {
//   final String text;
//   final bool isUser;
//   final DateTime timestamp;

//   ChatMessage({
//     required this.text,
//     required this.isUser,
//     required this.timestamp,
//   });
// }



































// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:syncfusion_flutter_pdf/pdf.dart';

// class LoanChatbotTab extends StatefulWidget {
//   const LoanChatbotTab({super.key});

//   @override
//   State<LoanChatbotTab> createState() => _LoanChatbotTabState();
// }

// class _LoanChatbotTabState extends State<LoanChatbotTab>
//     with AutomaticKeepAliveClientMixin {
//   final TextEditingController _messageController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();
//   final List<ChatMessage> _messages = [];

//   bool _isLoading = false;
//   String? _sessionId;

//   final String baseUrl = "https://9480-2409-40f4-308a-da12-148d-2936-193d-4e51.ngrok-free.app"; 

//   @override
//   bool get wantKeepAlive => true;

//   @override
//   void initState() {
//     super.initState();
//     _createSession();
//     _addWelcomeMessage();
//   }

//   // ================= SESSION CREATION =================

//   Future<void> _createSession() async {
//     try {
//       final response = await http.post(
//         Uri.parse("$baseUrl/create-session"),
//         headers: {"Content-Type": "application/json"},
//       );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         _sessionId = data["sessionId"];
//         print("Session Created: $_sessionId");
//       } else {
//         print("Session creation failed");
//       }
//     } catch (e) {
//       print("Error creating session: $e");
//     }
//   }

//   void _addWelcomeMessage() {
//     _messages.add(
//       ChatMessage(
//         text:
//             "Hello! Upload a loan document or ask me about loan terms.\n\nI will detect hidden charges and risky clauses.",
//         isUser: false,
//         timestamp: DateTime.now(),
//       ),
//     );
//   }

//   // ================= PDF UPLOAD =================

//   Future<void> _uploadDocument() async {
//     if (_sessionId == null) {
//       _addBotMessage("Session not ready. Please wait.");
//       return;
//     }

//     try {
//       FilePickerResult? result = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: ['pdf'],
//         withData: true,
//       );

//       if (result == null) return;

//       Uint8List? bytes = result.files.first.bytes;
//       if (bytes == null) return;

//       setState(() => _isLoading = true);

//       String extractedText = _extractTextFromPdf(bytes);

//       if (extractedText.trim().isEmpty) {
//         _addBotMessage(
//             "This PDF appears image-based. Please upload a text-based PDF.");
//         setState(() => _isLoading = false);
//         return;
//       }

//       extractedText =
//           extractedText.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ');

//       final response = await http.post(
//         Uri.parse("$baseUrl/analyze-document"),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({
//           "sessionId": _sessionId,
//           "documentText": extractedText,
//         }),
//       );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         _addBotMessage(data["analysis"]);
//       } else {
//         _addBotMessage("Server error: ${response.statusCode}");
//       }

//       setState(() => _isLoading = false);
//     } catch (e) {
//       setState(() => _isLoading = false);
//       _addBotMessage("Error processing document.");
//     }
//   }

//   String _extractTextFromPdf(Uint8List bytes) {
//     final PdfDocument document = PdfDocument(inputBytes: bytes);
//     final PdfTextExtractor extractor = PdfTextExtractor(document);
//     String text = extractor.extractText();
//     document.dispose();
//     return text;
//   }

//   // ================= CHAT =================

//   void _sendMessage() async {
//     if (_messageController.text.trim().isEmpty) return;
//     if (_sessionId == null) {
//       _addBotMessage("Session not ready. Please wait.");
//       return;
//     }

//     String userMessage = _messageController.text;

//     setState(() {
//       _messages.add(
//         ChatMessage(
//           text: userMessage,
//           isUser: true,
//           timestamp: DateTime.now(),
//         ),
//       );
//       _isLoading = true;
//     });

//     _messageController.clear();
//     _scrollToBottom();

//     try {
//       final response = await http.post(
//         Uri.parse("$baseUrl/chat"),
//         headers: {"Content-Type": "application/json"},
//         body: jsonEncode({
//           "sessionId": _sessionId,
//           "message": userMessage,
//         }),
//       );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         _addBotMessage(data["reply"]);
//       } else {
//         _addBotMessage("Server error.");
//       }
//     } catch (e) {
//       _addBotMessage("Connection error.");
//     }

//     setState(() => _isLoading = false);
//   }

//   void _addBotMessage(String text) {
//     setState(() {
//       _messages.add(
//         ChatMessage(
//           text: text,
//           isUser: false,
//           timestamp: DateTime.now(),
//         ),
//       );
//     });
//     _scrollToBottom();
//   }

//   void _scrollToBottom() {
//     Future.delayed(const Duration(milliseconds: 100), () {
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           _scrollController.position.maxScrollExtent,
//           duration: const Duration(milliseconds: 300),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }

//   // ================= UI =================

//   @override
//   Widget build(BuildContext context) {
//     super.build(context);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Loan Chatbot'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.upload_file),
//             onPressed: _uploadDocument,
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           if (_isLoading)
//             const LinearProgressIndicator(color: Color(0xFF1ABC9C)),

//           Expanded(
//             child: ListView.builder(
//               controller: _scrollController,
//               padding: const EdgeInsets.all(16),
//               itemCount: _messages.length,
//               itemBuilder: (context, index) =>
//                   _buildMessageBubble(_messages[index]),
//             ),
//           ),

//           _buildInputArea(),
//         ],
//       ),
//     );
//   }

//   Widget _buildInputArea() {
//     return Padding(
//       padding: const EdgeInsets.all(16),
//       child: Row(
//         children: [
//           Expanded(
//             child: TextField(
//               controller: _messageController,
//               decoration: const InputDecoration(
//                 hintText: "Ask about loans...",
//                 border: OutlineInputBorder(),
//               ),
//               onSubmitted: (_) => _sendMessage(),
//             ),
//           ),
//           const SizedBox(width: 8),
//           IconButton(
//             icon: const Icon(Icons.send),
//             onPressed: _sendMessage,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildMessageBubble(ChatMessage message) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 12),
//       child: Align(
//         alignment:
//             message.isUser ? Alignment.centerRight : Alignment.centerLeft,
//         child: Container(
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color:
//                 message.isUser ? const Color(0xFF0B3C5D) : Colors.grey.shade200,
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Text(
//             message.text,
//             style: TextStyle(
//               color: message.isUser ? Colors.white : Colors.black,
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _messageController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }
// }

// class ChatMessage {
//   final String text;
//   final bool isUser;
//   final DateTime timestamp;

//   ChatMessage({
//     required this.text,
//     required this.isUser,
//     required this.timestamp,
//   });
// }



































// import 'package:flutter/material.dart';

// class LoanChatbotTab extends StatefulWidget {
//   const LoanChatbotTab({super.key});

//   @override
//   State<LoanChatbotTab> createState() => _LoanChatbotTabState();
// }

// class _LoanChatbotTabState extends State<LoanChatbotTab> with AutomaticKeepAliveClientMixin {
//   final TextEditingController _messageController = TextEditingController();
//   final ScrollController _scrollController = ScrollController();
//   final List<ChatMessage> _messages = [];

//   @override
//   bool get wantKeepAlive => true;

//   @override
//   void initState() {
//     super.initState();
//     _addWelcomeMessage();
//   }

//   void _addWelcomeMessage() {
//     setState(() {
//       _messages.add(
//         ChatMessage(
//           text: "Hello! I'm your Loan Shield assistant. I can help you with:\n\n• Analyzing loan documents for hidden charges\n• Answering general loan questions\n• Understanding loan terms\n\nHow can I assist you today?",
//           isUser: false,
//           timestamp: DateTime.now(),
//         ),
//       );
//     });
//   }

//   void _sendMessage() {
//     if (_messageController.text.trim().isEmpty) return;

//     setState(() {
//       _messages.add(
//         ChatMessage(
//           text: _messageController.text,
//           isUser: true,
//           timestamp: DateTime.now(),
//         ),
//       );
//     });

//     // Simulate bot response
//     Future.delayed(const Duration(seconds: 1), () {
//       setState(() {
//         _messages.add(
//           ChatMessage(
//             text: "I understand your question. This is a demo response. In the full version, I would analyze your query and provide detailed loan information.",
//             isUser: false,
//             timestamp: DateTime.now(),
//           ),
//         );
//       });
//       _scrollToBottom();
//     });

//     _messageController.clear();
//     _scrollToBottom();
//   }

//   void _scrollToBottom() {
//     Future.delayed(const Duration(milliseconds: 100), () {
//       if (_scrollController.hasClients) {
//         _scrollController.animateTo(
//           _scrollController.position.maxScrollExtent,
//           duration: const Duration(milliseconds: 300),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }

//   void _uploadDocument() {
//     // Placeholder for document upload
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(
//         content: Text('Document upload feature coming soon!'),
//         backgroundColor: Color(0xFF1ABC9C),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     super.build(context);
    
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Loan Chatbot'),
//         centerTitle: true,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.upload_file),
//             onPressed: _uploadDocument,
//             tooltip: 'Upload Document',
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Info Banner
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(16),
//             color: const Color(0xFF1ABC9C).withOpacity(0.1),
//             child: Row(
//               children: [
//                 const Icon(
//                   Icons.info_outline,
//                   color: Color(0xFF1ABC9C),
//                   size: 20,
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: Text(
//                     'Upload documents to detect hidden charges',
//                     style: TextStyle(
//                       color: Colors.grey.shade800,
//                       fontSize: 14,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // Messages List
//           Expanded(
//             child: _messages.isEmpty
//                 ? Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(
//                           Icons.chat_bubble_outline,
//                           size: 80,
//                           color: Colors.grey.shade300,
//                         ),
//                         const SizedBox(height: 16),
//                         Text(
//                           'Start a conversation',
//                           style: TextStyle(
//                             fontSize: 18,
//                             color: Colors.grey.shade600,
//                           ),
//                         ),
//                       ],
//                     ),
//                   )
//                 : ListView.builder(
//                     controller: _scrollController,
//                     padding: const EdgeInsets.all(16),
//                     itemCount: _messages.length,
//                     itemBuilder: (context, index) {
//                       return _buildMessageBubble(_messages[index]);
//                     },
//                   ),
//           ),

//           // Input Field
//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.black.withOpacity(0.05),
//                   blurRadius: 10,
//                   offset: const Offset(0, -5),
//                 ),
//               ],
//             ),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     controller: _messageController,
//                     decoration: InputDecoration(
//                       hintText: 'Ask about loans...',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(24),
//                         borderSide: BorderSide(color: Colors.grey.shade300),
//                       ),
//                       enabledBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(24),
//                         borderSide: BorderSide(color: Colors.grey.shade300),
//                       ),
//                       focusedBorder: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(24),
//                         borderSide: const BorderSide(color: Color(0xFF1ABC9C), width: 2),
//                       ),
//                       contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 20,
//                         vertical: 12,
//                       ),
//                       filled: true,
//                       fillColor: Colors.grey.shade50,
//                     ),
//                     onSubmitted: (_) => _sendMessage(),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Container(
//                   decoration: const BoxDecoration(
//                     color: Color(0xFF0B3C5D),
//                     shape: BoxShape.circle,
//                   ),
//                   child: IconButton(
//                     icon: const Icon(Icons.send, color: Colors.white),
//                     onPressed: _sendMessage,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildMessageBubble(ChatMessage message) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 12),
//       child: Row(
//         mainAxisAlignment:
//             message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           if (!message.isUser) ...[
//             CircleAvatar(
//               backgroundColor: const Color(0xFF1ABC9C),
//               radius: 16,
//               child: const Icon(Icons.smart_toy, size: 18, color: Colors.white),
//             ),
//             const SizedBox(width: 8),
//           ],
//           Flexible(
//             child: Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: message.isUser
//                     ? const Color(0xFF0B3C5D)
//                     : Colors.white,
//                 borderRadius: BorderRadius.circular(16),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.05),
//                     blurRadius: 5,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Text(
//                 message.text,
//                 style: TextStyle(
//                   color: message.isUser ? Colors.white : const Color(0xFF2C2C2C),
//                   fontSize: 15,
//                 ),
//               ),
//             ),
//           ),
//           if (message.isUser) ...[
//             const SizedBox(width: 8),
//             CircleAvatar(
//               backgroundColor: const Color(0xFF0B3C5D),
//               radius: 16,
//               child: const Icon(Icons.person, size: 18, color: Colors.white),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _messageController.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }
// }

// class ChatMessage {
//   final String text;
//   final bool isUser;
//   final DateTime timestamp;

//   ChatMessage({
//     required this.text,
//     required this.isUser,
//     required this.timestamp,
//   });
// }