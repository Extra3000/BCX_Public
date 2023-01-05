import 'package:flutter/material.dart';

class DeviceDetailPage extends StatelessWidget {
  const DeviceDetailPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Page'),
      ),
      body: Center(
        child: Text('Detail Page'),
      ),
    );
  }
}
