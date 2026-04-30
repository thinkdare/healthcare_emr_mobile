// lib/core/platform.dart
//
// Single source of truth for platform detection and adaptive UI helpers.
//
// Import this wherever you need kIsIOS, adaptive dialogs, or toasts.
// Do NOT import dart:io Platform directly in any other file.
import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart'
    show
        AlertDialog,
        Colors,
        ElevatedButton,
        Icon,
        Icons,
        ListTile,
        Material,
        Navigator,
        OverlayEntry,
        Positioned,
        SafeArea,
        ScaffoldMessenger,
        SnackBar,
        StatelessWidget,
        TextButton,
        showDialog,
        showModalBottomSheet;

import '../config/app_colors.dart';

/// True when running on a physical or simulated iOS device.
/// Always false on web — Platform.isIOS throws on web.
bool get kIsIOS => !kIsWeb && Platform.isIOS;

// ── Adaptive dialog ───────────────────────────────────────────────────────────

class AdaptiveDialogAction {
  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;

  const AdaptiveDialogAction({
    required this.label,
    this.onPressed,
    this.isDestructive = false,
  });
}

/// Shows a [CupertinoAlertDialog] on iOS, [AlertDialog] on Android.
Future<void> showAdaptiveDialog({
  required BuildContext context,
  required String title,
  required String content,
  required List<AdaptiveDialogAction> actions,
}) {
  if (kIsIOS) {
    return showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: actions
            .map((a) => CupertinoDialogAction(
                  isDestructiveAction: a.isDestructive,
                  onPressed:
                      a.onPressed ?? () => Navigator.of(context).pop(),
                  child: Text(a.label),
                ))
            .toList(),
      ),
    );
  }
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: actions
          .map((a) => TextButton(
                onPressed:
                    a.onPressed ?? () => Navigator.of(context).pop(),
                child: Text(
                  a.label,
                  style: TextStyle(
                      color: a.isDestructive ? AppColors.error : null),
                ),
              ))
          .toList(),
    ),
  );
}

// ── Adaptive action sheet (destructive confirmations) ─────────────────────────

/// Shows a [CupertinoActionSheet] on iOS, a modal bottom sheet on Android.
/// [destructiveLabel] is shown in red. Calls [onConfirm] when tapped.
Future<void> showAdaptiveActionSheet({
  required BuildContext context,
  required String title,
  required String message,
  required String destructiveLabel,
  required VoidCallback onConfirm,
  String cancelLabel = 'Cancel',
}) {
  if (kIsIOS) {
    return showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(title),
        message: Text(message),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm();
            },
            child: Text(destructiveLabel),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(cancelLabel),
        ),
      ),
    );
  }
  return showModalBottomSheet(
    context: context,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(message),
          ),
          ListTile(
            leading:
                const Icon(Icons.delete_outline, color: AppColors.error),
            title: Text(destructiveLabel,
                style: const TextStyle(color: AppColors.error)),
            onTap: () {
              Navigator.of(context).pop();
              onConfirm();
            },
          ),
          ListTile(
            title: Text(cancelLabel),
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  );
}

// ── Adaptive toast ────────────────────────────────────────────────────────────

enum ToastType { success, error, info }

/// Shows a [SnackBar] on Android, a top-anchored overlay banner on iOS.
/// The iOS banner auto-dismisses after 2 seconds.
void showAdaptiveToast(
  BuildContext context,
  String message, {
  ToastType type = ToastType.info,
}) {
  if (!kIsIOS) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    return;
  }

  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  final borderColor = switch (type) {
    ToastType.success => AppColors.success,
    ToastType.error   => AppColors.error,
    ToastType.info    => AppColors.primary,
  };

  entry = OverlayEntry(
    builder: (_) => Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
            border: Border(
                left: BorderSide(color: borderColor, width: 4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            message,
            style: const TextStyle(
                fontSize: 14, color: CupertinoColors.label),
          ),
        ),
      ),
    ),
  );

  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 2), entry.remove);
}

// ── Adaptive buttons ──────────────────────────────────────────────────────────

/// Primary button: [CupertinoButton.filled] on iOS, [ElevatedButton] on Android.
/// Pass [icon] for icon+label variants (replaces [ElevatedButton.icon]).
class AdaptiveFilledButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;

  const AdaptiveFilledButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsIOS) {
      return CupertinoButton.filled(
        onPressed: onPressed,
        child: icon == null
            ? child
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconTheme.merge(
                    data: const IconThemeData(color: CupertinoColors.white),
                    child: icon!,
                  ),
                  const SizedBox(width: 6),
                  child,
                ],
              ),
      );
    }
    return icon != null
        ? ElevatedButton.icon(onPressed: onPressed, icon: icon!, label: child)
        : ElevatedButton(onPressed: onPressed, child: child);
  }
}

/// Secondary/text button: [CupertinoButton] on iOS, [TextButton] on Android.
/// Pass [icon] for icon+label variants (replaces [TextButton.icon]).
class AdaptiveTextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;

  const AdaptiveTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsIOS) {
      return CupertinoButton(
        onPressed: onPressed,
        child: icon == null
            ? child
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [icon!, const SizedBox(width: 6), child],
              ),
      );
    }
    return icon != null
        ? TextButton.icon(onPressed: onPressed, icon: icon!, label: child)
        : TextButton(onPressed: onPressed, child: child);
  }
}
