import 'package:flutter/material.dart';

class PaymentMethodDialog extends StatefulWidget {
  final Function(String method, String note) onPaid;
  const PaymentMethodDialog({required this.onPaid, super.key});

  @override
  State<PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<PaymentMethodDialog> {
  String selectedMethod = 'Cash';
  TextEditingController noteController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Select Payment Method',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF22211F),
            ),
          ),
          ListTile(
            title: Text('Cash'),
            leading: Radio<String>(
              value: 'Cash',
              groupValue: selectedMethod,
              onChanged: (val) => setState(() => selectedMethod = val!),
            ),
          ),
          ListTile(
            title: Text('Others'),
            leading: Radio<String>(
              value: 'Others',
              groupValue: selectedMethod,
              onChanged: (val) => setState(() => selectedMethod = val!),
            ),
          ),
          TextField(
            controller: noteController,
            decoration: InputDecoration(
              labelText: 'Note',
              fillColor: Colors.white,
              filled: true,
              labelStyle: TextStyle(color: Color(0xFF22211F)),
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              widget.onPaid(selectedMethod, noteController.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFFC700),
              foregroundColor: Color(0xFF22211F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: Size.fromHeight(48),
              textStyle: TextStyle(fontWeight: FontWeight.bold),
            ),
            child: Text('Confirm', style: TextStyle(color: Color(0xFF22211F))),
          ),
        ],
      ),
    );
  }
}
