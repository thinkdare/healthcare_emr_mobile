import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/platform.dart';
import '../../../data/providers/device_integrity_provider.dart';
import '../../../config/app_colors.dart';

/// Non-blocking warning shown when the device appears to be rooted/jailbroken.
/// Advisory only — see DeviceIntegrityProvider's doc for why this doesn't
/// hard-block the app.
class DeviceIntegrityBanner extends StatelessWidget {
  const DeviceIntegrityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceIntegrityProvider>(
      builder: (context, integrity, _) {
        if (!integrity.shouldWarn) return const SizedBox.shrink();

        final tokens = AppColors.of(context);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: tokens.warning,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: tokens.onWarning, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This device appears to be rooted or jailbroken. '
                    'Patient data protections may be weaker than intended.',
                    style: TextStyle(
                      color: tokens.onWarning,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: integrity.dismiss,
                  child: Icon(
                    kIsIOS ? CupertinoIcons.xmark : Icons.close,
                    color: tokens.onWarning,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
