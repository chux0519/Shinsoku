import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shinsoku_mobile/features/settings/field_rules_view.dart';
import 'package:shinsoku_mobile/features/settings/keyboard_setup_view.dart';
import 'package:shinsoku_mobile/features/settings/use_in_apps_view.dart';
import 'package:shinsoku_mobile/l10n/failure_text.dart';
import 'package:shinsoku_mobile/l10n/l10n.dart';
import 'package:shinsoku_mobile/services/field_rules.dart';
import 'package:shinsoku_mobile/services/provider_settings.dart';
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
    this.fieldRules = const FieldRules(),
    this.onFieldRulesChanged,
    this.onOpenShortcuts,
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

  /// Field-kind rules and the Shortcuts launcher (profile-01 P4).
  final FieldRules fieldRules;
  final Future<void> Function(FieldRules rules)? onFieldRulesChanged;
  final Future<bool> Function()? onOpenShortcuts;

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
      // Not edited here (I3): keep what first launch or the user stored.
      sonioxLanguageHints: widget.providerSettings.sonioxLanguageHints,
      bailianLanguageHint: widget.providerSettings.bailianLanguageHint,
    );

    try {
      await widget.onProviderSettingsSaved(settings);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.settingsSaved)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.settingsSaveFailed(
              describeFailure(context.l10n, error),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
      title: l.settingsTitle,
      children: [
        SkSection(
          label: l.settingsSectionRecognition,
          children: [
            SkListRow.toggle(
              leading: Icons.mic_none_rounded,
              title: l.settingsMicrophoneTitle,
              subtitle: widget.microphoneAllowed
                  ? l.settingsMicrophoneAllowed
                  : l.settingsMicrophoneTapToAllow,
              value: widget.microphoneAllowed,
              onChanged: (_) => widget.onMicrophonePressed(),
            ),
            SkSectionBody(
              child: SkSegmented<String>(
                semanticLabel: l.settingsSpeechProvider,
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
              title: l.settingsPostProcessingTitle,
              subtitle: l.settingsPostProcessingSubtitle(textModel),
              value: _textTransformEnabled,
              onChanged: (value) =>
                  setState(() => _textTransformEnabled = value),
            ),
            SkListRow.toggle(
              leading: Icons.cloud_outlined,
              title: l.settingsCloudTitle,
              subtitle: providerConfigured
                  ? l.settingsCloudSaved
                  : l.settingsCloudNotSaved,
              value: widget.cloudProcessingEnabled,
              onChanged: widget.onCloudProcessingChanged,
            ),
          ],
        ),
        gap,
        if (widget.providerSettingsLoading) ...[
          SkStatusLine(text: l.settingsLoading, busy: true),
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
                          label: l.settingsRealtimeModel,
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
                        _FieldLabel(l.settingsRecognitionMode),
                        SkSegmented<String>(
                          semanticLabel: l.settingsRecognitionMode,
                          segments: [
                            SkSegment(
                              value: bailianAsrModeRealtime,
                              label: l.settingsModeStreaming,
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
                          label: l.settingsStreamingModel,
                        ),
                        fieldGap,
                        SkTextArea.field(
                          controller: _bailianAsrModelController,
                          label: l.settingsBatchModel,
                        ),
                        fieldGap,
                        SkTextArea.field(
                          controller: _bailianTextModelController,
                          label: l.settingsPostProcessingModel,
                          helper: l.settingsPostProcessingModelHelper,
                        ),
                        fieldGap,
                        SkTextArea.field(
                          controller: _bailianBaseController,
                          label: l.settingsBaseUrl,
                          keyboardType: TextInputType.url,
                        ),
                        fieldGap,
                        SkTextArea.field(
                          controller: bailianRealtimeUrlController,
                          label: l.settingsRealtimeUrl,
                          keyboardType: TextInputType.url,
                        ),
                      ],
                    ),
            ),
          ],
        ),
        const SizedBox(height: SkSpace.l),
        SkButton(
          label: widget.providerSettingsSaving
              ? l.settingsSaving
              : l.settingsSave,
          busy: widget.providerSettingsSaving,
          expand: true,
          onPressed: _save,
        ),
        gap,
        SkSection(
          label: l.settingsSectionProfiles,
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
              title: l.settingsAddProfile,
              accentTitle: true,
              onTap: widget.onProfileAdded,
            ),
            SkListRow(
              leading: Icons.apps_rounded,
              title: l.settingsUseInApps,
              subtitle: l.settingsUseInAppsSubtitle,
              chevron: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => widget.onOpenShortcuts == null
                      ? UseInAppsView.withSystemVersion()
                      : UseInAppsView.withSystemVersion(
                          onOpenShortcuts: widget.onOpenShortcuts!,
                        ),
                ),
              ),
            ),
            SkListRow(
              leading: Icons.text_fields_rounded,
              title: l.settingsFieldRules,
              subtitle: l.settingsFieldRulesSubtitle,
              chevron: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => FieldRulesView(
                    profiles: widget.profiles,
                    rules: widget.fieldRules,
                    onChanged: widget.onFieldRulesChanged ?? (_) async {},
                  ),
                ),
              ),
            ),
          ],
        ),
        gap,
        SkSection(
          label: l.settingsSectionKeyboard,
          children: [
            SkListRow(
              leading: Icons.keyboard_alt_outlined,
              title: l.settingsKeyboardSetup,
              subtitle: l.settingsKeyboardSetupSubtitle,
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
      label: context.l10n.settingsApiKey,
      obscureText: !show,
      trailing: SkIconButton(
        tooltip: show
            ? context.l10n.settingsHideKey
            : context.l10n.settingsShowKey,
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
