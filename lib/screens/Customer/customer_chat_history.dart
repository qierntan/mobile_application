import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerChatHistory extends StatefulWidget {
  final String customerId;
  final String customerName;

  const CustomerChatHistory({Key? key, required this.customerId, required this.customerName}) : super(key: key);

  @override
  State<CustomerChatHistory> createState() => _CustomerChatHistoryState();
}

class _CustomerChatHistoryState extends State<CustomerChatHistory> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

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
        title: Text('${widget.customerName}'),
        backgroundColor: Color(0xFFF5F3EF),
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
                  if (messageType.isNotEmpty && messageType != 'text') {
                    return const SizedBox.shrink();
                  }
                  final text = (data['messageText'] ?? '').toString();
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

                  final bubble = Row(
                    mainAxisAlignment:
                        isFromCustomer ? MainAxisAlignment.start : MainAxisAlignment.end,
                    children: [
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

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}