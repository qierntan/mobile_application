import 'package:flutter/material.dart';

class CustomerChatHistory extends StatelessWidget {
  final String customerId;
  final String customerName;

  const CustomerChatHistory({Key? key, required this.customerId, required this.customerName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$customerName'),
        backgroundColor: Color(0xFFF5F3EF),
      ),
      body: Center(
        child: Text(
          'Chat history for customer: $customerId',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}