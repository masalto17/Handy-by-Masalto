import 'package:event_radio_app/l10n/app_localizations.dart';
import 'package:event_radio_app/src/core/config/env_config.dart';
import 'package:event_radio_app/src/core/theme/app_theme.dart';
import 'package:event_radio_app/src/shared/data/event_radio_providers.dart';
import 'package:event_radio_app/src/shared/domain/event_radio_repository.dart';
import 'package:event_radio_app/src/shared/domain/invite_code_parser.dart';
import 'package:event_radio_app/src/shared/presentation/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrJoinScreen extends ConsumerStatefulWidget {
  const QrJoinScreen({super.key});

  @override
  ConsumerState<QrJoinScreen> createState() => _QrJoinScreenState();
}

class _QrJoinScreenState extends ConsumerState<QrJoinScreen> {
  late final MobileScannerController _scannerController;
  final _manualController = TextEditingController(
    text: EnvConfig.allowDemoShortcuts ? 'SATI26' : '',
  );
  String? _error;
  bool _cameraRequested = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(autoStart: false);
    // Intenta abrir la camara apenas se entra a la pantalla, para que
    // escanear sea un solo paso. Si falla (permiso o navegador sin camara),
    // queda el ingreso manual como respaldo.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _submit(String rawCode) async {
    if (_isSubmitting) return;
    final code = InviteCodeParser.fromQrValue(rawCode);
    if (code.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).scanQrEmptyCode);
      return;
    }

    setState(() {
      _error = null;
      _isSubmitting = true;
    });

    try {
      final session =
          await ref.read(currentSessionProvider.notifier).joinByCode(code);
      if (!mounted) return;
      if (session.event.isOperational(DateTime.now())) {
        context.go('/event');
      } else {
        context.go('/closed');
      }
    } on JoinEventException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context).scanQrReadError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _startCamera() async {
    setState(() {
      _cameraRequested = true;
      _error = null;
    });

    try {
      await _scannerController.start();
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = AppLocalizations.of(context).scanQrCameraError,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      title: l10n.scanQr,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.scanQrTitle,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.scanQrHint,
            style: const TextStyle(color: Colors.white70),
          ),
          if (EnvConfig.allowDemoShortcuts) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : () => _submit('event-radio://join?code=SATI26'),
              icon: const Icon(Icons.bolt),
              label: Text(l10n.scanQrDemoButton),
            ),
          ],
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: Colors.white24),
                ),
                child: _cameraRequested
                    ? MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) {
                          String? raw;
                          for (final barcode in capture.barcodes) {
                            final value = barcode.rawValue;
                            if (value != null && value.trim().isNotEmpty) {
                              raw = value;
                              break;
                            }
                          }
                          if (raw != null) _submit(raw);
                        },
                      )
                    : const _ScannerPlaceholder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _startCamera,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(l10n.scanQrActivateCamera),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _manualController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: l10n.scanQrCodeOrQrLabel,
              errorText: _error,
              prefixIcon: const Icon(Icons.qr_code_2),
            ),
            onSubmitted: _isSubmitting ? null : _submit,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed:
                _isSubmitting ? null : () => _submit(_manualController.text),
            icon: _isSubmitting
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: Text(_isSubmitting ? l10n.joinValidating : l10n.scanQrUseCode),
          ),
        ],
      ),
    );
  }
}

class _ScannerPlaceholder extends StatelessWidget {
  const _ScannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Icon(Icons.qr_code_scanner, size: 96, color: Colors.white24),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.accent, width: 3),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 24,
          child: Text(
            AppLocalizations.of(context).scanQrCameraPaused,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white70,
                ),
          ),
        ),
      ],
    );
  }
}
