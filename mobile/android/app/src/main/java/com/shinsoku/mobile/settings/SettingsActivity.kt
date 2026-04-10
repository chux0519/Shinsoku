package com.shinsoku.mobile.settings

import android.os.Bundle
import android.view.View
import android.widget.ArrayAdapter
import androidx.appcompat.app.AppCompatActivity
import com.shinsoku.mobile.R
import com.shinsoku.mobile.databinding.ActivitySettingsBinding
import com.shinsoku.mobile.ime.RecognitionProviderDiagnostics
import com.shinsoku.mobile.speechcore.CommitSuffixMode
import com.shinsoku.mobile.speechcore.TranscriptPostProcessingMode
import com.shinsoku.mobile.speechcore.VoiceInputProfile
import com.shinsoku.mobile.speechcore.VoiceInputProfiles
import com.shinsoku.mobile.speechcore.VoiceRefineRequestFormat
import com.shinsoku.mobile.speechcore.VoiceRecognitionProvider
import com.shinsoku.mobile.speechcore.NativeVoiceTransformSummary
import com.shinsoku.mobile.speechcore.NativeVoiceRuntimeMetadata
import com.shinsoku.mobile.speechcore.VoiceTransformPromptBuilder
import com.shinsoku.mobile.speechcore.VoiceTransformConfig
import com.shinsoku.mobile.speechcore.VoiceTransformMode

class SettingsActivity : AppCompatActivity() {
    private lateinit var binding: ActivitySettingsBinding
    private lateinit var configStore: AndroidVoiceInputConfigStore
    private lateinit var providerConfigStore: AndroidVoiceProviderConfigStore
    private lateinit var runtimeConfigStore: AndroidVoiceRuntimeConfigStore
    private lateinit var presetOptions: LinkedHashMap<String, VoiceInputProfile>
    private lateinit var providerOptions: LinkedHashMap<String, VoiceRecognitionProvider>
    private lateinit var postProcessingOptions: LinkedHashMap<String, TranscriptPostProcessingMode>

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySettingsBinding.inflate(layoutInflater)
        setContentView(binding.root)
        configStore = AndroidVoiceInputConfigStore(this)
        providerConfigStore = AndroidVoiceProviderConfigStore(this)
        runtimeConfigStore = AndroidVoiceRuntimeConfigStore(this)
        presetOptions = LinkedHashMap<String, VoiceInputProfile>().apply {
            VoiceInputProfiles.builtIns.forEach { put(it.displayName, it) }
        }
        providerOptions = linkedMapOf(
            NativeVoiceRuntimeMetadata.describe(
                VoiceRecognitionProvider.AndroidSystem,
                TranscriptPostProcessingMode.LocalCleanup,
            ).providerLabel to VoiceRecognitionProvider.AndroidSystem,
            NativeVoiceRuntimeMetadata.describe(
                VoiceRecognitionProvider.OpenAiCompatible,
                TranscriptPostProcessingMode.LocalCleanup,
            ).providerLabel to VoiceRecognitionProvider.OpenAiCompatible,
            NativeVoiceRuntimeMetadata.describe(
                VoiceRecognitionProvider.Soniox,
                TranscriptPostProcessingMode.LocalCleanup,
            ).providerLabel to VoiceRecognitionProvider.Soniox,
            NativeVoiceRuntimeMetadata.describe(
                VoiceRecognitionProvider.Bailian,
                TranscriptPostProcessingMode.LocalCleanup,
            ).providerLabel to VoiceRecognitionProvider.Bailian,
        )
        postProcessingOptions = linkedMapOf(
            NativeVoiceRuntimeMetadata.describe(
                VoiceRecognitionProvider.AndroidSystem,
                TranscriptPostProcessingMode.Disabled,
            ).compactPostProcessingLabel to TranscriptPostProcessingMode.Disabled,
            NativeVoiceRuntimeMetadata.describe(
                VoiceRecognitionProvider.AndroidSystem,
                TranscriptPostProcessingMode.LocalCleanup,
            ).compactPostProcessingLabel to TranscriptPostProcessingMode.LocalCleanup,
            NativeVoiceRuntimeMetadata.describe(
                VoiceRecognitionProvider.AndroidSystem,
                TranscriptPostProcessingMode.ProviderAssisted,
            ).compactPostProcessingLabel to TranscriptPostProcessingMode.ProviderAssisted,
        )
        binding.workflowPresetDropdown.setAdapter(
            ArrayAdapter(this, android.R.layout.simple_list_item_1, presetOptions.keys.toList()),
        )
        binding.recognitionBackendDropdown.setAdapter(
            ArrayAdapter(this, android.R.layout.simple_list_item_1, providerOptions.keys.toList()),
        )
        binding.postProcessingDropdown.setAdapter(
            ArrayAdapter(this, android.R.layout.simple_list_item_1, postProcessingOptions.keys.toList()),
        )
        binding.workflowPresetDropdown.setOnItemClickListener { _, _, position, _ ->
            presetOptions.values.elementAtOrNull(position)?.let {
                configStore.saveProfile(it)
                bindState()
            }
        }
        binding.recognitionBackendDropdown.setOnItemClickListener { _, _, position, _ ->
            providerOptions.values.elementAtOrNull(position)?.let {
                saveProviderSelection(it)
            }
        }
        binding.postProcessingDropdown.setOnItemClickListener { _, _, position, _ ->
            postProcessingOptions.values.elementAtOrNull(position)?.let {
                runtimeConfigStore.savePostProcessingMode(it)
                bindState()
            }
        }

        binding.autoCommitSwitch.setOnCheckedChangeListener { _, isChecked ->
            configStore.saveAutoCommit(isChecked)
            bindState()
        }
        binding.appendTrailingSpaceSwitch.setOnCheckedChangeListener { _, isChecked ->
            // Legacy toggle retained only as a fast path for the common "space after dictation" choice.
            configStore.saveCommitSuffixMode(if (isChecked) CommitSuffixMode.Space else CommitSuffixMode.None)
            bindState()
        }
        binding.useAutoLanguageButton.setOnClickListener {
            configStore.saveLanguageTag("")
            bindState()
        }
        binding.useEnglishButton.setOnClickListener {
            configStore.saveLanguageTag("en-US")
            bindState()
        }
        binding.useChineseButton.setOnClickListener {
            configStore.saveLanguageTag("zh-CN")
            bindState()
        }
        binding.commitSuffixNoneButton.setOnClickListener {
            configStore.saveCommitSuffixMode(CommitSuffixMode.None)
            bindState()
        }
        binding.commitSuffixSpaceButton.setOnClickListener {
            configStore.saveCommitSuffixMode(CommitSuffixMode.Space)
            bindState()
        }
        binding.commitSuffixNewlineButton.setOnClickListener {
            configStore.saveCommitSuffixMode(CommitSuffixMode.Newline)
            bindState()
        }
        binding.transformModeCleanupButton.setOnClickListener {
            binding.transformModeCleanupButton.isChecked = true
            binding.transformModeTranslationButton.isChecked = false
            binding.transformModeCustomPromptButton.isChecked = false
        }
        binding.transformModeTranslationButton.setOnClickListener {
            binding.transformModeCleanupButton.isChecked = false
            binding.transformModeTranslationButton.isChecked = true
            binding.transformModeCustomPromptButton.isChecked = false
        }
        binding.transformModeCustomPromptButton.setOnClickListener {
            binding.transformModeCleanupButton.isChecked = false
            binding.transformModeTranslationButton.isChecked = false
            binding.transformModeCustomPromptButton.isChecked = true
        }
        binding.requestFormatSystemAndUserButton.setOnClickListener {
            binding.requestFormatSystemAndUserButton.isChecked = true
            binding.requestFormatSingleUserButton.isChecked = false
        }
        binding.requestFormatSingleUserButton.setOnClickListener {
            binding.requestFormatSystemAndUserButton.isChecked = false
            binding.requestFormatSingleUserButton.isChecked = true
        }
        binding.saveAllSettingsButton.setOnClickListener {
            val current = providerConfigStore.load()
            providerConfigStore.save(
                current.copy(
                    openAiRecognition = current.openAiRecognition.copy(
                        baseUrl = binding.openAiBaseUrlEdit.text?.toString().orEmpty().trim(),
                        apiKey = binding.openAiApiKeyEdit.text?.toString().orEmpty().trim(),
                        transcriptionModel = binding.openAiTranscriptionModelEdit.text?.toString().orEmpty().trim(),
                    ),
                    openAiPostProcessing = current.openAiPostProcessing.copy(
                        baseUrl = binding.postProcessOpenAiBaseUrlEdit.text?.toString().orEmpty().trim(),
                        apiKey = binding.postProcessOpenAiApiKeyEdit.text?.toString().orEmpty().trim(),
                        model = binding.postProcessOpenAiModelEdit.text?.toString().orEmpty().trim(),
                    ),
                    soniox = current.soniox.copy(
                        url = binding.sonioxUrlEdit.text?.toString().orEmpty().trim(),
                        apiKey = binding.sonioxApiKeyEdit.text?.toString().orEmpty().trim(),
                        model = binding.sonioxModelEdit.text?.toString().orEmpty().trim(),
                    ),
                    bailian = current.bailian.copy(
                        region = binding.bailianRegionEdit.text?.toString().orEmpty().trim(),
                        url = binding.bailianUrlEdit.text?.toString().orEmpty().trim(),
                        apiKey = binding.bailianApiKeyEdit.text?.toString().orEmpty().trim(),
                        model = binding.bailianModelEdit.text?.toString().orEmpty().trim(),
                    ),
                ),
            )
            configStore.saveTransform(currentTransformFromUi())
            configStore.saveLanguageTag(binding.languageTagEdit.text?.toString().orEmpty())
            bindState()
        }
    }

    override fun onResume() {
        super.onResume()
        bindState()
    }

    private fun bindState() {
        val profile = configStore.loadProfile()
        val providerConfig = providerConfigStore.load()
        val runtimeConfig = runtimeConfigStore.loadRuntimeConfig()
        val providerStatus = RecognitionProviderDiagnostics.status(providerConfig)
        val runtimeMetadata = NativeVoiceRuntimeMetadata.describe(
            providerConfig.activeRecognitionProvider,
            runtimeConfig.postProcessingConfig.mode,
        )
        binding.activeProfileText.text = getString(R.string.active_profile_template, profile.displayName)
        binding.currentBehaviorSummaryText.text = profile.behaviorSummary + " • " + (profile.languageTag ?: getString(R.string.language_auto_label))
        binding.providerStatusText.text = getString(
            R.string.provider_summary_template,
            runtimeMetadata.providerLabel,
            providerStatus.summary,
        ) + "\n" + getString(
            R.string.post_processing_summary_template,
            runtimeMetadata.postProcessingLabel,
        ) + "\n" + providerStatus.detail
        binding.workflowPresetDropdown.setText(profile.displayName, false)
        binding.recognitionBackendDropdown.setText(runtimeMetadata.providerLabel, false)
        binding.postProcessingDropdown.setText(runtimeMetadata.compactPostProcessingLabel, false)
        binding.autoCommitSwitch.isChecked = profile.autoCommit
        binding.appendTrailingSpaceSwitch.isChecked = profile.commitSuffixMode == CommitSuffixMode.Space
        val languageText = profile.languageTag.orEmpty()
        if (binding.languageTagEdit.text?.toString() != languageText) {
            binding.languageTagEdit.setText(languageText)
        }
        binding.commitSuffixNoneButton.isChecked = profile.commitSuffixMode == CommitSuffixMode.None
        binding.commitSuffixSpaceButton.isChecked = profile.commitSuffixMode == CommitSuffixMode.Space
        binding.commitSuffixNewlineButton.isChecked = profile.commitSuffixMode == CommitSuffixMode.Newline
        binding.transformEnabledSwitch.isChecked = profile.transform.enabled
        binding.transformModeCleanupButton.isChecked = profile.transform.mode == VoiceTransformMode.Cleanup
        binding.transformModeTranslationButton.isChecked = profile.transform.mode == VoiceTransformMode.Translation
        binding.transformModeCustomPromptButton.isChecked = profile.transform.mode == VoiceTransformMode.CustomPrompt
        binding.requestFormatSystemAndUserButton.isChecked =
            profile.transform.requestFormat == VoiceRefineRequestFormat.SystemAndUser
        binding.requestFormatSingleUserButton.isChecked =
            profile.transform.requestFormat == VoiceRefineRequestFormat.SingleUserMessage
        binding.recommendedPresetText.text = profile.summary.ifBlank { getString(R.string.preset_custom_summary) }

        if (binding.openAiBaseUrlEdit.text?.toString() != providerConfig.openAiRecognition.baseUrl) {
            binding.openAiBaseUrlEdit.setText(providerConfig.openAiRecognition.baseUrl)
        }
        if (binding.openAiApiKeyEdit.text?.toString() != providerConfig.openAiRecognition.apiKey) {
            binding.openAiApiKeyEdit.setText(providerConfig.openAiRecognition.apiKey)
        }
        if (binding.openAiTranscriptionModelEdit.text?.toString() != providerConfig.openAiRecognition.transcriptionModel) {
            binding.openAiTranscriptionModelEdit.setText(providerConfig.openAiRecognition.transcriptionModel)
        }
        if (binding.postProcessOpenAiBaseUrlEdit.text?.toString() != providerConfig.openAiPostProcessing.baseUrl) {
            binding.postProcessOpenAiBaseUrlEdit.setText(providerConfig.openAiPostProcessing.baseUrl)
        }
        if (binding.postProcessOpenAiApiKeyEdit.text?.toString() != providerConfig.openAiPostProcessing.apiKey) {
            binding.postProcessOpenAiApiKeyEdit.setText(providerConfig.openAiPostProcessing.apiKey)
        }
        if (binding.postProcessOpenAiModelEdit.text?.toString() != providerConfig.openAiPostProcessing.model) {
            binding.postProcessOpenAiModelEdit.setText(providerConfig.openAiPostProcessing.model)
        }
        if (binding.sonioxUrlEdit.text?.toString() != providerConfig.soniox.url) {
            binding.sonioxUrlEdit.setText(providerConfig.soniox.url)
        }
        if (binding.sonioxApiKeyEdit.text?.toString() != providerConfig.soniox.apiKey) {
            binding.sonioxApiKeyEdit.setText(providerConfig.soniox.apiKey)
        }
        if (binding.sonioxModelEdit.text?.toString() != providerConfig.soniox.model) {
            binding.sonioxModelEdit.setText(providerConfig.soniox.model)
        }
        if (binding.bailianRegionEdit.text?.toString() != providerConfig.bailian.region) {
            binding.bailianRegionEdit.setText(providerConfig.bailian.region)
        }
        if (binding.bailianUrlEdit.text?.toString() != providerConfig.bailian.url) {
            binding.bailianUrlEdit.setText(providerConfig.bailian.url)
        }
        if (binding.bailianApiKeyEdit.text?.toString() != providerConfig.bailian.apiKey) {
            binding.bailianApiKeyEdit.setText(providerConfig.bailian.apiKey)
        }
        if (binding.bailianModelEdit.text?.toString() != providerConfig.bailian.model) {
            binding.bailianModelEdit.setText(providerConfig.bailian.model)
        }
        if (binding.customPromptEdit.text?.toString() != profile.transform.customPrompt) {
            binding.customPromptEdit.setText(profile.transform.customPrompt)
        }
        if (binding.translationSourceLanguageEdit.text?.toString() != profile.transform.translationSourceLanguage) {
            binding.translationSourceLanguageEdit.setText(profile.transform.translationSourceLanguage)
        }
        if (binding.translationSourceCodeEdit.text?.toString() != profile.transform.translationSourceCode) {
            binding.translationSourceCodeEdit.setText(profile.transform.translationSourceCode)
        }
        if (binding.translationTargetLanguageEdit.text?.toString() != profile.transform.translationTargetLanguage) {
            binding.translationTargetLanguageEdit.setText(profile.transform.translationTargetLanguage)
        }
        if (binding.translationTargetCodeEdit.text?.toString() != profile.transform.translationTargetCode) {
            binding.translationTargetCodeEdit.setText(profile.transform.translationTargetCode)
        }
        if (binding.translationExtraInstructionsEdit.text?.toString() != profile.transform.translationExtraInstructions) {
            binding.translationExtraInstructionsEdit.setText(profile.transform.translationExtraInstructions)
        }

        binding.sonioxConfigCard.visibility =
            if (providerConfig.activeRecognitionProvider == VoiceRecognitionProvider.Soniox) View.VISIBLE else View.GONE
        binding.bailianConfigCard.visibility =
            if (providerConfig.activeRecognitionProvider == VoiceRecognitionProvider.Bailian) View.VISIBLE else View.GONE
        binding.postProcessingHintText.text = when (runtimeConfig.postProcessingConfig.mode) {
            TranscriptPostProcessingMode.Disabled ->
                getString(R.string.post_processing_hint_disabled)
            TranscriptPostProcessingMode.LocalCleanup ->
                getString(R.string.post_processing_hint_local_cleanup)
            TranscriptPostProcessingMode.ProviderAssisted ->
                getString(R.string.post_processing_hint_provider_assisted)
        }
        binding.transformSummaryText.text =
            NativeVoiceTransformSummary.build(profile.transform)
        val previewPlan = VoiceTransformPromptBuilder.build(
            getString(R.string.transform_preview_placeholder),
            profile,
        )
        if (previewPlan.requestFormat == VoiceRefineRequestFormat.SingleUserMessage) {
            binding.transformPreviewTitleText.text =
                getString(R.string.transform_single_prompt_preview_title)
            binding.transformPreviewText.text = buildString {
                append(previewPlan.systemPrompt.trim())
                append("\n\n")
                append(previewPlan.userContent)
            }
        } else {
            binding.transformPreviewTitleText.text =
                getString(R.string.transform_system_prompt_title)
            binding.transformPreviewText.text = previewPlan.systemPrompt
        }
    }

    private fun saveProviderSelection(provider: VoiceRecognitionProvider) {
        providerConfigStore.save(providerConfigStore.load().copy(activeRecognitionProvider = provider))
        bindState()
    }

    private fun currentTransformFromUi(): VoiceTransformConfig {
        val mode = when {
            binding.transformModeTranslationButton.isChecked -> VoiceTransformMode.Translation
            binding.transformModeCustomPromptButton.isChecked -> VoiceTransformMode.CustomPrompt
            else -> VoiceTransformMode.Cleanup
        }
        val requestFormat = if (binding.requestFormatSingleUserButton.isChecked) {
            VoiceRefineRequestFormat.SingleUserMessage
        } else {
            VoiceRefineRequestFormat.SystemAndUser
        }
        return VoiceTransformConfig(
            enabled = binding.transformEnabledSwitch.isChecked,
            mode = mode,
            requestFormat = requestFormat,
            customPrompt = binding.customPromptEdit.text?.toString().orEmpty().trim(),
            translationSourceLanguage = binding.translationSourceLanguageEdit.text?.toString().orEmpty().trim().ifEmpty { "Chinese" },
            translationSourceCode = binding.translationSourceCodeEdit.text?.toString().orEmpty().trim().ifEmpty { "zh" },
            translationTargetLanguage = binding.translationTargetLanguageEdit.text?.toString().orEmpty().trim().ifEmpty { "English" },
            translationTargetCode = binding.translationTargetCodeEdit.text?.toString().orEmpty().trim().ifEmpty { "en" },
            translationExtraInstructions = binding.translationExtraInstructionsEdit.text?.toString().orEmpty().trim(),
        )
    }

}
