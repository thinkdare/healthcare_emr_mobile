import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/security/root_detection_provider.dart';

/// Persistent red banner shown when the device is rooted or jailbroken.
/// Warning only — clinical functionality is not blocked.
class RootWarningBanner extends StatelessWidget {
  const RootWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final root = context.watch<RootDetectionProvider>();
    if (!root.isCompromised) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: const Color(0xFFB71C1C),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.gpp_bad_outlined, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Security warning: this device appears to be rooted or jailbroken. '
              'Patient data may be at risk.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
