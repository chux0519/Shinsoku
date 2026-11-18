import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shinsoku_mobile/features/common/widgets.dart';
import 'package:shinsoku_mobile/features/settings/keyboard_setup_view.dart';
import 'package:shinsoku_mobile/services/provider_settings.dart';
import 'package:shinsoku_mobile/services/smoke_test.dart';
import 'package:shinsoku_mobile/services/transcription_service.dart';
import 'package:shinsoku_mobile/services/voice_profiles.dart';
import 'package:shinsoku_mobile/ui/ui.dart';

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
    this.profiles = const [],
    this.onProfileAdded,
    this.onProfileOpened,
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

  /// Voice profiles (DESIGN §7: Settings › Profiles).
  final List<VoiceProfile> profiles;
  final VoidCallback? onProfileAdded;
  final ValueChanged<VoiceProfile>? onProfileOpened;

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
    final providerConfigured = switch (_speechProvider) {
      'soniox' => _sonioxKeyController.text.trim().isNotEmpty,
      _ => _bailianKeyController.text.trim().isNotEmpty,
    };
    final textModel = _bailianTextModelController.text.trim().isEmpty
        ? 'qwen-flash'
        : _bailianTextModelController.text.trim();
    const gap = SizedBox(height: SkSpace.xl);
    const fieldGap = SizedBox(height: SkSpace.m);

    return SkPage(
      title: 'Settings',
      children: [
        SkSection(
          label: 'Recognition',
          children: [
            SkListRow.toggle(
              leading: Icons.mic_none_rounded,
              title: 'Microphone access',
              subtitle: widget.microphoneAllowed
                  ? 'Allowed for voice capture'
                  : 'Tap to allow microphone access',
              value: widget.microphoneAllowed,
              onChanged: (_) => widget.onMicrophonePressed(),
            ),
            SkSectionBody(
              child: SkSegmented<String>(
                semanticLabel: 'Speech provider',
                segments: const [
                  SkSegment(value: 'bailian', label: 'Bailian'),
                  SkSegment(value: 'soniox', label: 'Soniox'),
                ],
                selected: _speechProvider,
                onChanged: (value) => setState(() => _speechProvider = value),
              ),
            ),
            SkListRow.toggle(
              leading: Icons.translate_rounded,
              title: 'Text post-processing',
              subtitle: 'Use $textModel for cleanup or translation',
              value: _textTransformEnabled,
              onChanged: (value) =>
                  setState(() => _textTransformEnabled = value),
            ),
            SkListRow.toggle(
              leading: Icons.cloud_outlined,
              title: 'Cloud processing',
              subtitle: providerConfigured
                  ? 'Provider credentials are saved'
                  : 'Save provider credentials before real transcription',
              value: widget.cloudProcessingEnabled,
              onChanged: widget.onCloudProcessingChanged,
            ),
          ],
        ),
        gap,
        if (widget.providerSettingsLoading) ...[
          const SkStatusLine(text: 'Loading saved settings', busy: true),
          const SizedBox(height: SkSpace.m),
        ],
        SkSection(
          label: _speechProvider == 'soniox' ? 'Soniox' : 'Bailian',
          children: [
            SkSectionBody(
              child: _speechProvider == 'soniox'
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _keyField(
                          _sonioxKeyController,
                          show: _showSonioxKey,
                          onToggle: () =>
                              setState(() => _showSonioxKey = !_showSonioxKey),
                        ),
                        fieldGap,
                        SkTextArea.field(
                          controller: _sonioxModelController,
                          label: 'Realtime model',
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _keyField(
                          _bailianKeyController,
                          show: _showBailianKey,
                          onToggle: () => setState(
                            () => _showBailianKey = !_showBailianKey,
                          ),
                        ),
                        fieldGap,
                        _FieldLabel('Recognition mode'),
                        SkSegmented<String>(
                          semanticLabel: 'Recognition mode',
                          segments: const [
                            SkSegment(
                              value: bailianAsrModeRealtime,
                              label: 'Streaming',
                            ),
                            SkSegment(
                              value: bailianAsrModeQwen,
                              label: 'Qwen-ASR',
                            ),
                          ],
                          selected: _bailianAsrMode,
                          onChanged: (value) =>
                              setState(() => _bailianAsrMode = value),
                        ),
                        fieldGap,
                        SkTextArea.field(
                          controller: bailianRealtimeModelController,
                          label: 'Streaming ASR model',
                        ),
                        fieldGap,
                        SkTextArea.field(
                          controller: _bailianAsrModelController,
                          label: 'Qwen-ASR batch model',
                        ),
                        fieldGap,
                        SkTextArea.field(
                          controller: _bailianTextModelController,
                          label: 'Post-processing OpenAI model',
                          helper: 'Used only when Text post-processing is on',
                        ),
                        fieldGap,
                        SkTextArea.field(
                          controller: _bailianBaseController,
                          label: 'OpenAI-compatible base URL',
                          keyboardType: TextInputType.url,
                        ),
                        fieldGap,
                        SkTextArea.field(
                          controller: bailianRealtimeUrlController,
                          label: 'Realtime WebSocket URL',
                          keyboardType: TextInputType.url,
                        ),
                      ],
                    ),
            ),
          ],
        ),
        const SizedBox(height: SkSpace.l),
        SkButton(
          label: widget.providerSettingsSaving ? 'Saving' : 'Save Settings',
          busy: widget.providerSettingsSaving,
          expand: true,
          onPressed: _save,
        ),
        gap,
        SkSection(
          label: 'Profiles',
          children: [
            for (final profile in widget.profiles)
              SkListRow(
                title: profile.name,
                subtitle: profile.intent,
                subtitleMaxLines: 1,
                chevron: true,
                onTap: widget.onProfileOpened == null
                    ? null
                    : () => widget.onProfileOpened!(profile),
              ),
            SkListRow(
              leading: Icons.add_rounded,
              title: 'Add profile',
              accentTitle: true,
              onTap: widget.onProfileAdded,
            ),
          ],
        ),
        gap,
        SkSection(
          label: 'Keyboard',
          children: [
            SkListRow(
              leading: Icons.keyboard_alt_outlined,
              title: 'Keyboard setup',
              subtitle: 'Add Shinsoku and allow Full Access',
              chevron: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const KeyboardSetupView(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _keyField(
    TextEditingController controller, {
    required bool show,
    required VoidCallback onToggle,
  }) {
    return SkTextArea.field(
      controller: controller,
      label: 'API key',
      obscureText: !show,
      trailing: SkIconButton(
        tooltip: show ? 'Hide key' : 'Show key',
        onPressed: onToggle,
        icon: show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: SkType.secondary.copyWith(
          color: SkColors.of(context).textSecondary,
        ),
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
