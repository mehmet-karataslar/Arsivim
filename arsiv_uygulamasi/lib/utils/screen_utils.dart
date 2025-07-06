import 'package:flutter/material.dart';

/// Tüm screen'lerde kullanılacak ortak utility fonksiyonları
class ScreenUtils {
  ScreenUtils._(); // Private constructor - static class

  /// Standart hata mesajı göster
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        elevation: 8,
      ),
    );
  }

  /// Standart başarı mesajı göster
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        elevation: 8,
      ),
    );
  }

  /// Standart info mesajı göster
  static void showInfoSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        elevation: 8,
      ),
    );
  }

  /// Standart warning mesajı göster
  static void showWarningSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.warning_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        elevation: 8,
      ),
    );
  }

  /// Standart loading dialog göster
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    message ?? 'Yükleniyor...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  /// Standart onay dialogu göster
  static Future<bool?> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Evet',
    String cancelText = 'Hayır',
    Color? confirmColor,
    IconData? icon,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: confirmColor ?? Colors.blue),
                  const SizedBox(width: 8),
                ],
                Expanded(child: Text(title)),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelText),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: confirmColor ?? Colors.blue,
                ),
                child: Text(confirmText),
              ),
            ],
          ),
    );
  }

  /// Standart progress indicator widget
  static Widget buildProgressIndicator({String? message, double? progress}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (progress != null)
            CircularProgressIndicator(value: progress)
          else
            const CircularProgressIndicator(),
          const SizedBox(height: 16),
          if (message != null)
            Text(
              message,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  /// Standart boş liste widget'ı
  static Widget buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 80, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionText),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Dosya boyutunu formatla
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Standart app bar oluştur
  static AppBar buildAppBar({
    required String title,
    List<Widget>? actions,
    bool showBackButton = true,
    Color? backgroundColor,
    Color? foregroundColor,
    double? elevation,
  }) {
    return AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: backgroundColor ?? Colors.white,
      foregroundColor: foregroundColor ?? Colors.black87,
      elevation: elevation ?? 0,
      actions: actions,
      leading: showBackButton ? null : Container(),
    );
  }

  /// Standart refresh indicator
  static Widget buildRefreshIndicator({
    required Widget child,
    required Future<void> Function() onRefresh,
  }) {
    return RefreshIndicator(onRefresh: onRefresh, child: child);
  }

  /// Standart gradient container
  static Container buildGradientContainer({
    required Widget child,
    List<Color>? colors,
    BorderRadius? borderRadius,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors ?? [Colors.blue.shade50, Colors.white],
        ),
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }

  /// Standart animated fade in
  static Widget buildFadeIn({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: child,
    );
  }

  /// Tarayıcı durum widget'ı
  static Widget buildScannerStatusWidget({
    required String status,
    required Color color,
    required IconData icon,
    String? message,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                if (message != null) ...[
                  const SizedBox(height: 4),
                  Text(message, style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tarayıcı hata mesajı widget'ı
  static Widget buildScannerErrorWidget({
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontSize: 14)),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: Text(actionText),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Tarayıcı başarı mesajı widget'ı
  static Widget buildScannerSuccessWidget({
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontSize: 14)),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_forward),
              label: Text(actionText),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Tarayıcı progress widget'ı
  static Widget buildScannerProgressWidget({
    required String message,
    double? progress,
    bool showCancel = false,
    VoidCallback? onCancel,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (progress != null) ...[
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ] else
            const LinearProgressIndicator(),
          if (showCancel && onCancel != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.cancel),
              label: const Text('İptal'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  /// Tarayıcı ayarları dialog'u
  static Future<Map<String, dynamic>?> showScannerSettingsDialog(
    BuildContext context, {
    required Map<String, dynamic> currentSettings,
  }) async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => _ScannerSettingsDialog(currentSettings: currentSettings),
    );
  }

  /// Tarayıcı bilgi dialog'u
  static void showScannerInfoDialog(
    BuildContext context, {
    required String scannerName,
    required Map<String, dynamic> scannerInfo,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(child: Text('$scannerName Bilgileri')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...scannerInfo.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              '${entry.key}:',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(child: Text(entry.value.toString())),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kapat'),
              ),
            ],
          ),
    );
  }

  /// Tarayıcı yardım dialog'u
  static void showScannerHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.help_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text('Tarayıcı Yardımı'),
              ],
            ),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tarayıcı Kurulumu:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('1. Tarayıcınızı USB ile bilgisayara bağlayın'),
                  Text('2. Tarayıcı sürücülerini yükleyin'),
                  Text('3. Tarayıcınızı açın ve hazır duruma getirin'),
                  SizedBox(height: 16),
                  Text(
                    'Tarama İşlemi:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('1. "Tarayıcıları Yenile" butonuna basın'),
                  Text('2. Listeden tarayıcınızı seçin'),
                  Text('3. Belgeyi tarayıcıya yerleştirin'),
                  Text('4. "Belge Tara" butonuna basın'),
                  SizedBox(height: 16),
                  Text(
                    'Sorun Giderme:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• Tarayıcınızı yeniden başlatın'),
                  Text('• USB kablosunu kontrol edin'),
                  Text('• Sürücü güncellemelerini kontrol edin'),
                  Text('• Tarayıcı kapağının kapalı olduğundan emin olun'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tamam'),
              ),
            ],
          ),
    );
  }
}

/// Tarayıcı ayarları dialog widget'ı
class _ScannerSettingsDialog extends StatefulWidget {
  final Map<String, dynamic> currentSettings;

  const _ScannerSettingsDialog({required this.currentSettings});

  @override
  State<_ScannerSettingsDialog> createState() => _ScannerSettingsDialogState();
}

class _ScannerSettingsDialogState extends State<_ScannerSettingsDialog> {
  late Map<String, dynamic> _settings;

  @override
  void initState() {
    super.initState();
    _settings = Map.from(widget.currentSettings);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings, color: Colors.blue),
          SizedBox(width: 8),
          Text('Tarayıcı Ayarları'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Çözünürlük
            if (_settings.containsKey('resolution')) ...[
              const Text('Çözünürlük (DPI):'),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _settings['selectedResolution'] ?? 300,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items:
                    (_settings['resolution'] as List)
                        .map<DropdownMenuItem<int>>((res) {
                          return DropdownMenuItem(
                            value: res,
                            child: Text('$res DPI'),
                          );
                        })
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _settings['selectedResolution'] = value;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            // Renk modu
            if (_settings.containsKey('colorModes')) ...[
              const Text('Renk Modu:'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _settings['selectedColorMode'] ?? 'color',
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items:
                    (_settings['colorModes'] as List)
                        .map<DropdownMenuItem<String>>((mode) {
                          return DropdownMenuItem(
                            value: mode,
                            child: Text(
                              mode == 'color'
                                  ? 'Renkli'
                                  : mode == 'grayscale'
                                  ? 'Gri Tonlama'
                                  : 'Siyah-Beyaz',
                            ),
                          );
                        })
                        .toList(),
                onChanged: (value) {
                  setState(() {
                    _settings['selectedColorMode'] = value;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            // Çift taraflı
            if (_settings.containsKey('duplex')) ...[
              CheckboxListTile(
                title: const Text('Çift Taraflı Tarama'),
                value: _settings['selectedDuplex'] ?? false,
                onChanged: (value) {
                  setState(() {
                    _settings['selectedDuplex'] = value;
                  });
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_settings),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
