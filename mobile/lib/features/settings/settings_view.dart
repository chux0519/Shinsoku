import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shinsoku_mobile/services/smoke_test.dart';
import 'package:shinsoku_mobile/services/transcription_service.dart';
import 'package:shinsoku_mobile/services/provider_settings.dart';
import 'package:shinsoku_mobile/features/common/widgets.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    required this.microphoneAllowed,
    required this.keyboardExtensionEnabled,
    required this.cloudProcessingEnabled,
    required this.providerSettings,
    required this.providerSettingsLoading,
    required this.providerSettingsSaving,
    required this.onMicrophonePressed,
    required this.onKeyboardChanged,
    required this.onCloudProcessingChanged,
    required this.onProviderSettingsSaved,
    super.key,
  });

  final bool microphoneAllowed;
  final bool keyboardExtensionEnabled;
  final bool cloudProcessingEnabled;
  final ProviderSettings providerSettings;
  final bool providerSettingsLoading;
  final bool providerSettingsSaving;
  final VoidCallback onMicrophonePressed;
  final ValueChanged<bool> onKeyboardChanged;
  final ValueChanged<bool> onCloudProcessingChanged;
  final Future<void> Function(ProviderSettings settings)
  onProviderSettingsSaved;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late String _speechProvider;
  late String _bailianAsrMode;
  late bool _textTransformEnabled;
  bool _showBailianKey = false;
  bool _showSonioxKey = false;

  late final TextEditingController _bailianBaseController;
  late final TextEditingController _bailianKeyController;
  late final TextEditingController _bailianTextModelController;
  late final TextEditingController _bailianAsrModelController;
  late final TextEditingController bailianRealtimeUrlController;
  late final TextEditingController bailianRealtimeModelController;
  late final TextEditingController _sonioxKeyController;
  late final TextEditingController _sonioxModelController;

  @override
  void initState() {
    super.initState();
    _bailianBaseController = TextEditingController();
    _bailianKeyController = TextEditingController();
    _bailianTextModelController = TextEditingController();
    _bailianTextModelController.addListener(_refreshPostProcessingModelLabel);
    _bailianAsrModelController = TextEditingController();
    bailianRealtimeUrlController = TextEditingController();
    bailianRealtimeModelController = TextEditingController();
    _sonioxKeyController = TextEditingController();
    _sonioxModelController = TextEditingController();
    _applySettings(widget.providerSettings);
  }

  @override
  void didUpdateWidget(covariant SettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.providerSettings != widget.providerSettings) {
      _applySettings(widget.providerSettings);
    }
  }

  @override
  void dispose() {
    _bailianTextModelController.removeListener(
      _refreshPostProcessingModelLabel,
    );
    _bailianBaseController.dispose();
    _bailianKeyController.dispose();
    _bailianTextModelController.dispose();
    _bailianAsrModelController.dispose();
    bailianRealtimeUrlController.dispose();
    bailianRealtimeModelController.dispose();
    _sonioxKeyController.dispose();
    _sonioxModelController.dispose();
    super.dispose();
  }

  void _refreshPostProcessingModelLabel() {
    if (mounted) {
      setState(() {});
    }
  }

  void _applySettings(ProviderSettings settings) {
    _speechProvider = settings.speechProvider;
    _bailianAsrMode =
        {
          bailianAsrModeRealtime,
          bailianAsrModeQwen,
        }.contains(settings.bailianAsrMode)
        ? settings.bailianAsrMode
        : bailianAsrModeRealtime;
    _textTransformEnabled = settings.textTransformEnabled;
    _bailianBaseController.text = settings.bailianApiBase;
    _bailianKeyController.text = settings.bailianApiKey;
    _bailianTextModelController.text = settings.bailianTextModel;
    _bailianAsrModelController.text = settings.bailianAsrModel;
    bailianRealtimeUrlController.text = settings.bailianRealtimeUrl;
    bailianRealtimeModelController.text = settings.bailianRealtimeModel;
    _sonioxKeyController.text = settings.sonioxApiKey;
    _sonioxModelController.text = settings.sonioxModel;
  }

  Future<void> _save() async {
    final settings = ProviderSettings(
      speechProvider: _speechProvider,
      textTransformEnabled: _textTransformEnabled,
      bailianAsrMode: _bailianAsrMode,
      bailianApiBase: _bailianBaseController.text.trim(),
      bailianApiKey: _bailianKeyController.text.trim(),
      bailianTextModel: _bailianTextModelController.text.trim(),
      bailianAsrModel: _bailianAsrModelController.text.trim(),
      bailianRealtimeUrl: bailianRealtimeUrlController.text.trim(),
      bailianRealtimeModel: bailianRealtimeModelController.text.trim(),
      sonioxApiKey: _sonioxKeyController.text.trim(),
      sonioxModel: _sonioxModelController.text.trim(),
    );

    try {
      await widget.onProviderSettingsSaved(settings);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Provider settings saved')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final providerConfigured = switch (_speechProvider) {
      'soniox' => _sonioxKeyController.text.trim().isNotEmpty,
      _ => _bailianKeyController.text.trim().isNotEmpty,
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const AppHeader(title: 'Settings', subtitle: 'Providers and workflow'),
        const SizedBox(height: 20),
        InfoPanel(
          child: Column(
            children: [
              SwitchListTile(
                value: widget.microphoneAllowed,
                onChanged: (_) => widget.onMicrophonePressed(),
                secondary: const Icon(Icons.mic_none),
                title: const Text('Microphone access'),
                subtitle: Text(
                  widget.microphoneAllowed
                      ? 'Allowed for voice capture'
                      : 'Tap to request iOS microphone access',
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.keyboard_alt_outlined),
                trailing: const Icon(Icons.chevron_right),
                onTap: openAppSettings,
                title: const Text('Keyboard setup'),
                subtitle: const Text(
                  'Add Shinsoku in iOS Keyboard settings and allow Full Access',
                ),
              ),
              const Divider(),
              SwitchListTile(
                value: widget.cloudProcessingEnabled,
                onChanged: widget.onCloudProcessingChanged,
                secondary: const Icon(Icons.cloud_outlined),
                title: const Text('Cloud processing'),
                subtitle: Text(
                  providerConfigured
                      ? 'Provider credentials are saved'
                      : 'Save provider credentials before real transcription',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.keyboard_command_key, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enable Shinsoku Keyboard',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                '1. Open iOS Settings > General > Keyboard > Keyboards.\n'
                '2. Add Shinsoku as a third-party keyboard.\n'
                '3. Turn on Allow Full Access so Paste can read the latest Shinsoku text.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: openAppSettings,
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open iOS Settings'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Speech Provider', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        InfoPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.providerSettingsLoading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
              ],
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'bailian',
                    label: Text('Bailian'),
                    icon: Icon(Icons.cloud_queue),
                  ),
                  ButtonSegment<String>(
                    value: 'soniox',
                    label: Text('Soniox'),
                    icon: Icon(Icons.graphic_eq),
                  ),
                ],
                selected: {_speechProvider},
                onSelectionChanged: (selection) {
                  setState(() {
                    _speechProvider = selection.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _textTransformEnabled,
                onChanged: (value) {
                  setState(() {
                    _textTransformEnabled = value;
                  });
                },
                secondary: const Icon(Icons.translate),
                title: const Text('Text post-processing'),
                subtitle: Text(
                  'Use ${_bailianTextModelController.text.trim().isEmpty ? "qwen-flash" : _bailianTextModelController.text.trim()} for cleanup or translation',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SaveSettingsButton(
          saving: widget.providerSettingsSaving,
          onPressed: _save,
        ),
        const SizedBox(height: 18),
        Text('Bailian', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        InfoPanel(
          child: Column(
            children: [
              ConfigTextField(
                controller: _bailianBaseController,
                icon: Icons.link,
                label: 'OpenAI-compatible base URL',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              ConfigTextField(
                controller: _bailianKeyController,
                icon: Icons.key,
                label: 'API key',
                obscureText: !_showBailianKey,
                trailing: IconButton(
                  tooltip: _showBailianKey ? 'Hide key' : 'Show key',
                  onPressed: () {
                    setState(() {
                      _showBailianKey = !_showBailianKey;
                    });
                  },
                  icon: Icon(
                    _showBailianKey
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ConfigTextField(
                controller: _bailianTextModelController,
                icon: Icons.auto_fix_high_outlined,
                label: 'Post-processing OpenAI model',
                helperText: 'Used only when Text post-processing is enabled',
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(
                      value: bailianAsrModeRealtime,
                      label: Text('Streaming'),
                      icon: Icon(Icons.podcasts),
                    ),
                    ButtonSegment<String>(
                      value: bailianAsrModeQwen,
                      label: Text('Qwen-ASR'),
                      icon: Icon(Icons.hearing),
                    ),
                  ],
                  selected: {_bailianAsrMode},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _bailianAsrMode = selection.first;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              ConfigTextField(
                controller: _bailianAsrModelController,
                icon: Icons.hearing,
                label: 'Qwen-ASR batch model',
              ),
              const SizedBox(height: 12),
              ConfigTextField(
                controller: bailianRealtimeUrlController,
                icon: Icons.hub_outlined,
                label: 'Realtime WebSocket URL',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              ConfigTextField(
                controller: bailianRealtimeModelController,
                icon: Icons.multitrack_audio,
                label: 'Streaming ASR model',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Soniox', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        InfoPanel(
          child: Column(
            children: [
              ConfigTextField(
                controller: _sonioxKeyController,
                icon: Icons.key,
                label: 'API key',
                obscureText: !_showSonioxKey,
                trailing: IconButton(
                  tooltip: _showSonioxKey ? 'Hide key' : 'Show key',
                  onPressed: () {
                    setState(() {
                      _showSonioxKey = !_showSonioxKey;
                    });
                  },
                  icon: Icon(
                    _showSonioxKey
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ConfigTextField(
                controller: _sonioxModelController,
                icon: Icons.multitrack_audio,
                label: 'Realtime model',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SaveSettingsButton(
          saving: widget.providerSettingsSaving,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _SaveSettingsButton extends StatelessWidget {
  const _SaveSettingsButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: saving ? null : onPressed,
        icon: saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(saving ? 'Saving' : 'Save Settings'),
      ),
    );
  }
}

class ConfigTextField extends StatelessWidget {
  const ConfigTextField({
    required this.controller,
    required this.icon,
    required this.label,
    this.helperText,
    this.keyboardType,
    this.obscureText = false,
    this.trailing,
    super.key,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final String? helperText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autocorrect: false,
      enableSuggestions: !obscureText,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        suffixIcon: trailing,
        labelText: label,
        helperText: helperText,
      ),
    );
  }
}

class SmokeTestPanel extends StatelessWidget {
  const SmokeTestPanel({required this.status, super.key});

  final SmokeTestStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = status.failed
        ? Icons.error_outline
        : status.finished
        ? Icons.check_circle_outline
        : Icons.cloud_sync_outlined;
    final color = status.failed ? scheme.error : scheme.primary;

    return InfoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(status.detail),
          if (status.transcript != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              status.transcript!,
              key: const ValueKey('soniox-smoke-transcript'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ],
      ),
    );
  }
}
