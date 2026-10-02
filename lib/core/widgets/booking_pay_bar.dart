import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Cash / card checkout actions on the customer booking screen.
class BookingPayBar extends StatelessWidget {
  const BookingPayBar({
    super.key,
    required this.totalPrice,
    required this.isProcessing,
    required this.onPayCard,
    required this.onPayCash,
  });

  final double totalPrice;
  final bool isProcessing;
  final VoidCallback? onPayCard;
  final VoidCallback? onPayCash;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.credit_card, size: 26),
                label: Text(
                  'Pay in Full Now \$${totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  backgroundColor: AppColors.cyan,
                  foregroundColor: AppColors.onCyan,
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: isProcessing ? null : onPayCard,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.money, size: 26),
                label: const Text(
                  'Pay Cash When Detailer Arrives',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: isProcessing ? null : onPayCash,
              ),
            ),
            if (isProcessing)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: CircularProgressIndicator(color: AppColors.cyan),
              ),
          ],
        ),
      ),
    );
  }
}
