// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HugoApp());
}

class HugoApp extends StatelessWidget {
  const HugoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hugo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const WelcomePage(),
    );
  }
}

// ============================================================================
// BOT SERVICE - Llama Flutter Android Integration
// ============================================================================
class BotService {
  static LlamaController? _controller;
  
  static Future<void> initModel(String modelPath) async {
    if (_controller != null) return;
    
    try {
      _controller = LlamaController();
      await _controller!.loadModel(
        modelPath: modelPath,
        contextSize: 2048,
      );
    } catch (e) {
      print('Error initializing model: $e');
      rethrow;
    }
  }
  
  Future<String> getBotReply(String userMessage, String modelPath) async {
    await initModel(modelPath);
    
    try {
      final responseBuffer = StringBuffer();
      final completer = Completer<String>();
      
      _controller!.generate(
        prompt: userMessage,
        maxTokens: 256,
        temperature: 0.75,
        topP: 0.9,
        topK: 40,
        repeatPenalty: 1.1,
      ).listen(
        (token) {
          responseBuffer.write(token);
        },
        onDone: () {
          completer.complete(responseBuffer.toString().trim());
        },
        onError: (error) {
          completer.completeError(error);
        },
      );
      
      return await completer.future;
    } catch (e) {
      print('Error generating response: $e');
      return "Sorry, I encountered an error: $e";
    }
  }
  
  static Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
// ============================================================================

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hugo')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome to Hugo\n\nRecord three short voice clips to unlock the next step.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RecordingPage()),
                  );
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});
  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  final AudioRecorder _recorder = AudioRecorder();
  late Directory _appDir;
  final Map<int, String?> _clipPaths = {1: null, 2: null, 3: null};
  final Map<int, bool> _isRecording = {1: false, 2: false, 3: false};

  @override
  void initState() {
    super.initState();
    _initPaths();
  }

@override
  void dispose() {
    _recorder.dispose(); // Dispose of the recorder
    super.dispose();    // Always call super.dispose()
  }
  Future<void> _initPaths() async {
    _appDir = await getApplicationDocumentsDirectory();
    for (var i = 1; i <= 3; i++) {
      final f = File(_filePathFor(i));
      if (await f.exists()) _clipPaths[i] = f.path;
    }
    if (mounted) setState(() {});
  }

  String _filePathFor(int i) =>
      '${_appDir.path}${Platform.pathSeparator}hugo_clip_$i.m4a';

  Future<bool> _ensureMicPermission() async {
    if (!await _recorder.hasPermission()) {
      final status = await Permission.microphone.request();
      return status == PermissionStatus.granted;
    }
    return true;
  }
Future<void> _startRecording(int slot) async {
  try {
    final hasPermission = await _ensureMicPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required.')),
      );
      return;
    }

    print('Starting recording for slot $slot...');
    if (mounted) setState(() => _isRecording[slot] = true);

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 16000, // Lower sample rate for compatibility
      ),
      path: _filePathFor(slot),
    );

    print('Recording started for slot $slot.');

    // Auto-stop after 5 seconds
    Timer(const Duration(seconds: 5), () async {
      if (_isRecording[slot] == true) {
        print('Auto-stopping recording for slot $slot...');
        await _stopRecording(slot);
      }
    });
  } catch (e, stackTrace) {
    print('Error starting recording: $e');
    print('Stack trace: $stackTrace');
    if (mounted) {
      setState(() => _isRecording[slot] = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start recording: $e')),
      );
    }
  }
}
Future<void> _stopRecording(int slot) async {
  try {
    print('Stopping recording for slot $slot...');
    final path = await _recorder.stop();
    if (mounted) setState(() => _isRecording[slot] = false);

    final actualPath = path ?? _filePathFor(slot);
    final recorded = File(actualPath);

    print('Recorded file path: $actualPath');
    print('File exists: ${await recorded.exists()}');
    print('File size: ${await recorded.length()} bytes');

    if (await recorded.exists() && await recorded.length() > 0) {
      final expected = File(_filePathFor(slot));
      if (recorded.path != expected.path) {
        await recorded.copy(expected.path);
        await recorded.delete();
      }
      _clipPaths[slot] = expected.path;
      print('Clip path updated: ${_clipPaths[slot]}');
    } else {
      print('Recording failed: file is empty or does not exist');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording failed. Please try again.')),
        );
        _clipPaths[slot] = null; // Reset to null if empty
      }
    }
    if (mounted) setState(() {});
  } catch (e, stackTrace) {
    print('Error stopping recording: $e');
    print('Stack trace: $stackTrace');
    if (mounted) {
      setState(() => _isRecording[slot] = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stop failed: $e')),
      );
      _clipPaths[slot] = null; // Reset to null on error
    }
  }
}


  bool get _allClipsRecorded {
  print('Clip paths: $_clipPaths');
  return _clipPaths.values.every((p) => p != null);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Clips — Hugo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
                'Record three short clips (3–5 seconds each). Tap a button to start; recording auto-stops after 5s.'),
            const SizedBox(height: 16),
            for (var i = 1; i <= 3; i++) ...[
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  leading: _isRecording[i]!
                      ? const Icon(Icons.mic, color: Colors.red)
                      : (_clipPaths[i] != null
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.mic_none)),
                  title: Text('Clip $i'),
                  subtitle: Text(_clipPaths[i] ?? 'Not recorded'),
                  trailing: ElevatedButton(
                    onPressed: _isRecording[i]!
                        ? null
                        : () async => await _startRecording(i),
                    child: Text(
                        _clipPaths[i] != null ? 'Re-record' : 'Record'),
                  ),
                ),
              ),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: _allClipsRecorded
                  ? () {
                      if (!mounted) return;
                      
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ChatPage(
                              clipPaths:
                                  List<String>.from(_clipPaths.values.cast<String>()))));
                    }
                  : null,
              child: const Text('Proceed (unlocked when all 3 recorded)'),
            ),
            const SizedBox(height: 12),
            Text(
                'Status: ${_allClipsRecorded ? 'Unlocked' : 'Locked — record all 3 clips'}'),
          ],
        ),
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final List<String> clipPaths;
  const ChatPage({super.key, required this.clipPaths});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final BotService _botService = BotService();
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _modelPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeBot();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.paused) {
      BotService.dispose();
    }
  }
Future<void> _initializeBot() async {
  setState(() => _isInitializing = true);

  try {
    final appDir = await getApplicationDocumentsDirectory();
    _modelPath = '${appDir.path}/phi-3.5-mini-q4.gguf';
    print('DEBUG: Model path: $_modelPath'); // <-- Add this

    final modelFile = File(_modelPath!);
    print('DEBUG: Model file exists: ${await modelFile.exists()}'); // <-- Add this

    if (!await modelFile.exists()) {
      print('DEBUG: Model file not found. Copying from assets...'); // <-- Add this
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: "Model not found. Copying from assets... This will take 1-2 minutes.",
            isUser: false,
          ));
        });
      }
try {
  print('DEBUG: Attempting to load model from assets...');
  final assetData = await rootBundle.load('assets/models/phi-3.5-mini-q4.gguf');
  print('DEBUG: Asset loaded successfully. Writing to file...');
  final bytes = assetData.buffer.asUint8List();
  print('DEBUG: Asset size: ${bytes.length} bytes');
  await modelFile.writeAsBytes(bytes);
  print('DEBUG: Model file written to: ${modelFile.path}');
  print('DEBUG: File size after write: ${await modelFile.length()} bytes');

  if (mounted) {
    setState(() {
      _messages.add(ChatMessage(
        text: "Model copied successfully! Loading...",
        isUser: false,
      ));
    });
  }
}
catch (e) {
  print('DEBUG: ERROR copying model file: $e');
  if (mounted) {
    setState(() {
      _messages.add(ChatMessage(
        text: "Model file not found in assets.\n\nError: $e",
        isUser: false,
      ));
      _isInitializing = false;
    });
  }
  return;
}
    }

    print('DEBUG: Loading model...'); // <-- Add this
    await BotService.initModel(_modelPath!);
    print('DEBUG: Model loaded successfully!'); // <-- Add this

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Hello! I'm Hugo. Your voice clips have been recorded. How can I help you?",
          isUser: false,
        ));
        _isInitializing = false;
      });
    }
  } catch (e) {
    print('DEBUG: Error in _initializeBot: $e'); // <-- Add this
    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(
          text: "Sorry, I encountered an error loading the AI model: $e",
          isUser: false,
        ));
        _isInitializing = false;
      });
    }
  }
}

  Future<void> _sendMessage() async {
    if (_modelPath == null) return;
    
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _controller.clear();

    try {
      final reply = await _botService.getBotReply(text, _modelPath!);

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: reply, isUser: false));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: "Sorry, I encountered an error: $e",
            isUser: false,
          ));
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat with Hugo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Voice Clips'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Recorded clips:'),
                      const SizedBox(height: 8),
                      for (var p in widget.clipPaths) Text(p, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 16),
                      if (_modelPath != null) ...[
                        const Text('Model path:'),
                        const SizedBox(height: 4),
                        Text(_modelPath!, style: const TextStyle(fontSize: 12)),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isInitializing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading AI model...'),
                  SizedBox(height: 8),
                  Text(
                    'This may take 10-20 seconds on first run',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return ChatBubble(message: message);
                    },
                  ),
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        SizedBox(width: 16),
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Hugo is typing...'),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _sendMessage,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    BotService.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: message.isUser ? Colors.blue : Colors.grey[300],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}