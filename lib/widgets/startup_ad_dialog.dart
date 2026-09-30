// lib/widgets/startup_ad_dialog.dart
import 'package:flutter/material.dart';
import 'package:sanhour_online/models/ad_model.dart';
import 'package:sanhour_online/widgets/ad_carousel.dart';

class StartupAdDialog extends StatelessWidget {
  final AdModel ad;

  const StartupAdDialog({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AdCarousel(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
