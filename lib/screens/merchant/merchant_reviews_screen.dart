import 'package:flutter/material.dart';

class MerchantReviewsScreen extends StatelessWidget {
  final String shopId;
  const MerchantReviewsScreen({super.key, required this.shopId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('آراء العملاء')),
      body: const Center(child: Text('هنا ستظهر آراء العملاء')),
    );
  }
}