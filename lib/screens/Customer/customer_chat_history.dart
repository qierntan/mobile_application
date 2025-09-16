import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_details_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';

class CustomerChatHistory extends StatefulWidget {
  final String customerId;
  final String customerName;

  const CustomerChatHistory({super.key, required this.customerId, required this.customerName});

  @override
  State<CustomerChatHistory> createState() => _CustomerChatHistoryState();
}

class _CustomerChatHistoryState extends State<CustomerChatHistory> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;

  Query<Map<String, dynamic>> _chatHistoryQuery(String customerId) {
    // Structure in screenshot: ChatHistory (top-level), one doc per message with fields
    // Filter by customerId. We'll sort by timestamp client-side to avoid needing an index.
    return FirebaseFirestore.instance
        .collection('ChatHistory')
        .where('customerId', isEqualTo: customerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomerDetailsScreen(customerId: widget.customerId),
                  ),
                );
              },
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('Customer').doc(widget.customerId).get(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final customerData = snapshot.data!.data() as Map<String, dynamic>;
                    final logoUrl = customerData['logoUrl']?.toString() ?? '';
                    
                    if (logoUrl.isNotEmpty) {
                      return CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(logoUrl),
                        backgroundColor: Colors.grey.shade300,
                      );
                    }
                  }
                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey.shade300,
                    child: const Icon(Icons.person, color: Colors.white, size: 18),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.customerName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFFF5F3EF),
        actions: [
          IconButton(
            tooltip: 'Clean unreachable audio',
            icon: const Icon(Icons.cleaning_services_outlined),
            onPressed: () async {
              await _cleanupUnreachableAudioMessages();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _chatHistoryQuery(widget.customerId).snapshots(),
        builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No messages yet.'));
              }

              // Sort client-side by timestamp ASC so list starts from the top (oldest first)
              final sortedDocs = [...docs]..sort((a, b) {
                final ta = a.data()['timestamp'];
                final tb = b.data()['timestamp'];
                final da = (ta is Timestamp) ? ta.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                final db = (tb is Timestamp) ? tb.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                return da.compareTo(db);
              });

              return ListView.builder(
                // not reversed; messages start from the top like a normal chat transcript
                itemCount: sortedDocs.length,
                itemBuilder: (context, index) {
                  final data = sortedDocs[index].data();
                  final messageType = (data['messageType'] ?? '').toString();
                  final text = (data['messageText'] ?? '').toString();
                  final audioUrl = (data['audioUrl'] ?? '').toString();
                  final ts = data['timestamp'];
                  final sentAt = (ts is Timestamp)
                      ? DateTime.fromMicrosecondsSinceEpoch(
                          ts.toDate().microsecondsSinceEpoch,
                          isUtc: true,
                        ).toLocal()
                      : null;
                  String? timeLabel;
                  if (sentAt != null) {
                    final hour12 = sentAt.hour % 12 == 0 ? 12 : sentAt.hour % 12;
                    final ampm = sentAt.hour >= 12 ? 'PM' : 'AM';
                    final mm = sentAt.minute.toString().padLeft(2, '0');
                    timeLabel = '$hour12:$mm $ampm';
                  }

                  // Date header (Today/Yesterday/Date)
                  String? dateHeader;
                  if (sentAt != null) {
                    final prevTs = index > 0 ? sortedDocs[index - 1].data()['timestamp'] : null;
                    DateTime? prevAt;
                    if (prevTs is Timestamp) {
                      prevAt = DateTime.fromMicrosecondsSinceEpoch(
                        prevTs.toDate().microsecondsSinceEpoch,
                        isUtc: true,
                      ).toLocal();
                    }
                    bool isNewDay = prevAt == null ||
                        prevAt.year != sentAt.year ||
                        prevAt.month != sentAt.month ||
                        prevAt.day != sentAt.day;
                    if (isNewDay) {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final msgDay = DateTime(sentAt.year, sentAt.month, sentAt.day);
                      final yesterday = today.subtract(const Duration(days: 1));
                      if (msgDay == today) {
                        dateHeader = 'Today';
                      } else if (msgDay == yesterday) {
                        dateHeader = 'Yesterday';
                      } else {
                        dateHeader = '${sentAt.day.toString().padLeft(2, '0')}/${sentAt.month.toString().padLeft(2, '0')}/${sentAt.year}';
                      }
                    }
                  }

                  // Determine message origin using multiple possible fields for flexibility
                  final senderId = (data['senderId'] ?? '').toString();
                  final senderRole = (data['senderRole'] ?? '').toString();
                  final isFromCustomerFlag = (data['isFromCustomer'] is bool)
                      ? (data['isFromCustomer'] as bool)
                      : null;
                  final isFromCustomer = isFromCustomerFlag == true ||
                      senderRole.toLowerCase() == 'customer' ||
                      (senderId.isNotEmpty && senderId == widget.customerId);

                  final screenWidth = MediaQuery.of(context).size.width;
                  final maxBubbleWidth = (isFromCustomer
                      ? screenWidth - 24 // take (almost) the entire row for customer, keep margins
                      : screenWidth * 0.78); // typical chat width for sender on right

                  // Build UI differently for audio vs text
                  final bubble = Row(
                    mainAxisAlignment:
                        isFromCustomer ? MainAxisAlignment.start : MainAxisAlignment.end,
                    children: [
                      if (messageType == 'audio' && audioUrl.isNotEmpty)
                        // For audio: no colored bubble. If audio fails to load, inner widget returns SizedBox.shrink.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: _AudioBubble(audioUrl: audioUrl, timeLabel: timeLabel),
                        )
                      else
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isFromCustomer ? const Color(0xFFF0F0F0) : const Color(0xFFE1F5FE),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(text, style: const TextStyle(fontSize: 16)),
                                if (timeLabel != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      timeLabel,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );

                  if (dateHeader != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDEDED),
                                borderRadius: BorderRadius.circular(12),
                              ),
        child: Text(
                                dateHeader,
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                            ),
                          ),
                        ),
                        bubble,
                      ],
                    );
                  }

                  return bubble;
                },
              );
            },
          ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Type a message... ',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _isSending
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    color: const Color(0xFF2196F3),
                    onPressed: _isSending ? null : _sendMessage,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(_isRecording ? Icons.stop_circle : Icons.mic),
                    color: _isRecording ? Colors.red : Colors.black87,
                    onPressed: _isSending ? null : _toggleRecord,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      await FirebaseFirestore.instance.collection('ChatHistory').add({
        'messageText': text,
        'messageType': 'text',
        'timestamp': FieldValue.serverTimestamp(),
        'senderRole': 'manager',
        'customerId': widget.customerId.isEmpty ? null : widget.customerId,
        'cusName': widget.customerName.isEmpty ? null : widget.customerName,
        'isRead': false,
      });
      _messageController.clear();
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _toggleRecord() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        await _uploadAndSendAudio(path);
      }
      return;
    }

    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) return;
    final dir = await getTemporaryDirectory();
    final outPath = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: outPath,
    );
    setState(() => _isRecording = true);
  }

  Future<void> _uploadAndSendAudio(String localPath) async {
    setState(() => _isSending = true);
    try {
      final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref = FirebaseStorage.instance.ref().child('chat_audio').child(fileName);
      final uploadTask = await ref.putFile(File(localPath));
      final url = await uploadTask.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('ChatHistory').add({
        'messageType': 'audio',
        'audioUrl': url,
        'timestamp': FieldValue.serverTimestamp(),
        'senderRole': 'manager',
        'customerId': widget.customerId.isEmpty ? null : widget.customerId,
        'cusName': widget.customerName.isEmpty ? null : widget.customerName,
        'isRead': false,
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _cleanupUnreachableAudioMessages() async {
    final q = await FirebaseFirestore.instance
        .collection('ChatHistory')
        .where('customerId', isEqualTo: widget.customerId)
        .where('messageType', isEqualTo: 'audio')
        .get();

    int deleted = 0;
    for (final doc in q.docs) {
      final url = (doc.data()['audioUrl'] ?? '').toString();
      if (url.isEmpty) {
        await doc.reference.delete();
        deleted++;
        continue;
      }
      try {
        // Try to fetch metadata; if it throws, the file likely doesn't exist
        await FirebaseStorage.instance.refFromURL(url).getMetadata();
      } catch (_) {
        await doc.reference.delete();
        deleted++;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Cleaned $deleted unreachable audio message(s).')),
    );
  }

  @override
  void dispose() {
    _recorder.dispose();
    _messageController.dispose();
    super.dispose();
  }
}

class _AudioBubble extends StatefulWidget {
  final String audioUrl;
  final String? timeLabel;
  const _AudioBubble({required this.audioUrl, this.timeLabel});

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  late final AudioPlayer _player;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _init();
  }

  Future<void> _init() async {
    try {
      // Guard: do not try to load if url is clearly invalid
      if (widget.audioUrl.isEmpty ||
          !(widget.audioUrl.startsWith('http://') || widget.audioUrl.startsWith('https://'))) {
        _failed = true;
        return;
      }
      await _player.setUrl(widget.audioUrl);
    } catch (e) {
      _failed = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      // If audio can't be loaded, don't show anything as requested
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    return Icon(playing ? Icons.pause : Icons.play_arrow);
                  },
                ),
          onPressed: _loading
              ? null
              : () async {
                  final playing = _player.playing;
                  if (playing) {
                    await _player.pause();
                  } else {
                    await _player.play();
                  }
                },
        ),
        StreamBuilder<Duration?>(
          stream: _player.durationStream,
          builder: (context, snapDur) {
            final total = snapDur.data ?? Duration.zero;
            return StreamBuilder<Duration>(
              stream: _player.positionStream,
              initialData: Duration.zero,
              builder: (context, snapPos) {
                final pos = snapPos.data ?? Duration.zero;
                String fmt(Duration d) {
                  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
                  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
                  return '$m:$s';
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 160,
                      child: Slider(
                        value: pos.inMilliseconds.clamp(0, total.inMilliseconds == 0 ? 1 : total.inMilliseconds).toDouble(),
                        min: 0,
                        max: (total.inMilliseconds == 0 ? 1 : total.inMilliseconds).toDouble(),
                        onChanged: (v) async {
                          await _player.seek(Duration(milliseconds: v.toInt()));
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Text('${fmt(pos)} / ${fmt(total)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        if (widget.timeLabel != null) ...[
                          const SizedBox(width: 8),
                          Text(widget.timeLabel!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ]
                      ],
                    )
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}