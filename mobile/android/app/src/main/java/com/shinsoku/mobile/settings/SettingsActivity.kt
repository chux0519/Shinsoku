package com.shinsoku.mobile.settings

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.view.inputmethod.InputMethodManager
import androidx.appcompat.app.AppCompatActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import com.shinsoku.mobile.databinding.ActivitySettingsBinding
import com.shinsoku.mobile.ime.RecognitionProviderDiagnostics
import com.shinsoku.mobile.ime.queryImeStatus
import com.shinsoku.mobile.speechcore.CommitSuffixMode
import com.shinsoku.mobile.speechcore.VoiceInputProfile
import com.shinsoku.mobile.speechcore.VoiceInputProfiles
import com.shinsoku.mobile.speechcore.VoiceRecognitionProvider

class SettingsActivity : AppCompatActivity() {
    private lateinit var binding: ActivitySettingsBinding
    private lateinit var configStore: AndroidVoiceInputConfigStore
    private lateinit var providerConfigStore: AndroidVoiceProviderConfigStore
    private val requestMicrophonePermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) {
            bindState()
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySettingsBinding.inflate(layoutInflater)
        setContentView(binding.root)
        configStore = AndroidVoiceInputConfigStore(this)
        providerConfigStore = AndroidVoiceProviderConfigStore(this)

        binding.requestPermissionButton.setOnClickListener {
            requestMicrophonePermission.launch(Manifest.permission.RECORD_AUDIO)
        }
        binding.openKeyboardSettingsButton.setOnClickListener {
            startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS))
        }
        binding.openInputMethodPickerButton.setOnClickListener {
            val imm = getSystemService(InputMethodManager::class.java)
            imm?.showInputMethodPicker()
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
        binding.saveLanguageButton.setOnClickListener {
            configStore.saveLanguageTag(binding.languageTagEdit.text?.toString().orEmpty())
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
        binding.applyDictationPresetButton.setOnClickListener {
            configStore.saveProfile(VoiceInputProfiles.dictation)
            bindState()
        }
        binding.applyChatPresetButton.setOnClickListener {
            configStore.saveProfile(VoiceInputProfiles.chat)
            bindState()
        }
        binding.applyReviewPresetButton.setOnClickListener {
            configStore.saveProfile(VoiceInputProfiles.review)
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
        binding.providerAndroidSystemButton.setOnClickListener {
            saveProviderSelection(VoiceRecognitionProvider.AndroidSystem)
        }
        binding.providerOpenAiButton.setOnClickListener {
            saveProviderSelection(VoiceRecognitionProvider.OpenAiCompatible)
        }
        binding.providerSonioxButton.setOnClickListener {
            saveProviderSelection(VoiceRecognitionProvider.Soniox)
        }
        binding.providerBailianButton.setOnClickListener {
            saveProviderSelection(VoiceRecognitionProvider.Bailian)
        }
        binding.saveProviderConfigButton.setOnClickListener {
            val current = providerConfigStore.load()
            providerConfigStore.save(
                current.copy(
                    openAi = current.openAi.copy(
                        baseUrl = binding.openAiBaseUrlEdit.text?.toString().orEmpty().trim(),
                        apiKey = binding.openAiApiKeyEdit.text?.toString().orEmpty().trim(),
                        model = binding.openAiModelEdit.text?.toString().orEmpty().trim(),
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
        val providerStatus = RecognitionProviderDiagnostics.status(providerConfig)
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
        val imeStatus = queryImeStatus(this)

        binding.permissionStatusText.text = getString(
            if (granted) com.shinsoku.mobile.R.string.permission_status_granted
            else com.shinsoku.mobile.R.string.permission_status_missing,
        )
        binding.keyboardEnabledStatusText.text = getString(
            if (imeStatus.enabled) com.shinsoku.mobile.R.string.keyboard_enabled_status
            else com.shinsoku.mobile.R.string.keyboard_disabled_status,
        )
        binding.keyboardSelectedStatusText.text = getString(
            if (imeStatus.selected) com.shinsoku.mobile.R.string.keyboard_selected_status
            else com.shinsoku.mobile.R.string.keyboard_not_selected_status,
        )
        binding.activeProfileText.text = getString(com.shinsoku.mobile.R.string.active_profile_template, profile.displayName)
        binding.providerStatusText.text = getString(
            com.shinsoku.mobile.R.string.provider_summary_template,
            providerLabel(providerConfig.activeRecognitionProvider),
            providerStatus.summary,
        ) + "\n" + providerStatus.detail
        binding.autoCommitSwitch.isChecked = profile.autoCommit
        binding.appendTrailingSpaceSwitch.isChecked = profile.commitSuffixMode == CommitSuffixMode.Space
        val languageText = profile.languageTag.orEmpty()
        if (binding.languageTagEdit.text?.toString() != languageText) {
            binding.languageTagEdit.setText(languageText)
        }
        binding.commitSuffixNoneButton.isChecked = profile.commitSuffixMode == CommitSuffixMode.None
        binding.commitSuffixSpaceButton.isChecked = profile.commitSuffixMode == CommitSuffixMode.Space
        binding.commitSuffixNewlineButton.isChecked = profile.commitSuffixMode == CommitSuffixMode.Newline
        binding.currentBehaviorSummaryText.text = getString(
            com.shinsoku.mobile.R.string.behavior_summary_template,
            if (profile.autoCommit) getString(com.shinsoku.mobile.R.string.behavior_auto_commit_on)
            else getString(com.shinsoku.mobile.R.string.behavior_auto_commit_off),
            when (profile.commitSuffixMode) {
                CommitSuffixMode.None -> getString(com.shinsoku.mobile.R.string.commit_suffix_none)
                CommitSuffixMode.Space -> getString(com.shinsoku.mobile.R.string.commit_suffix_space)
                CommitSuffixMode.Newline -> getString(com.shinsoku.mobile.R.string.commit_suffix_newline)
            },
            profile.languageTag ?: getString(com.shinsoku.mobile.R.string.language_auto_label),
        )
        binding.recommendedPresetText.text = when {
            profile.id == VoiceInputProfiles.review.id ->
                getString(com.shinsoku.mobile.R.string.preset_review_summary)
            profile.id == VoiceInputProfiles.chat.id ->
                getString(com.shinsoku.mobile.R.string.preset_chat_summary)
            profile.id == VoiceInputProfiles.dictation.id ->
                getString(com.shinsoku.mobile.R.string.preset_dictation_summary)
            else ->
                getString(com.shinsoku.mobile.R.string.preset_custom_summary)
        }
        binding.providerAndroidSystemButton.isChecked =
            providerConfig.activeRecognitionProvider == VoiceRecognitionProvider.AndroidSystem
        binding.providerOpenAiButton.isChecked =
            providerConfig.activeRecognitionProvider == VoiceRecognitionProvider.OpenAiCompatible
        binding.providerSonioxButton.isChecked =
            providerConfig.activeRecognitionProvider == VoiceRecognitionProvider.Soniox
        binding.providerBailianButton.isChecked =
            providerConfig.activeRecognitionProvider == VoiceRecognitionProvider.Bailian

        if (binding.openAiBaseUrlEdit.text?.toString() != providerConfig.openAi.baseUrl) {
            binding.openAiBaseUrlEdit.setText(providerConfig.openAi.baseUrl)
        }
        if (binding.openAiApiKeyEdit.text?.toString() != providerConfig.openAi.apiKey) {
            binding.openAiApiKeyEdit.setText(providerConfig.openAi.apiKey)
        }
        if (binding.openAiModelEdit.text?.toString() != providerConfig.openAi.model) {
            binding.openAiModelEdit.setText(providerConfig.openAi.model)
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

        binding.openAiConfigCard.visibility =
            if (providerConfig.activeRecognitionProvider == VoiceRecognitionProvider.OpenAiCompatible) View.VISIBLE else View.GONE
        binding.sonioxConfigCard.visibility =
            if (providerConfig.activeRecognitionProvider == VoiceRecognitionProvider.Soniox) View.VISIBLE else View.GONE
        binding.bailianConfigCard.visibility =
            if (providerConfig.activeRecognitionProvider == VoiceRecognitionProvider.Bailian) View.VISIBLE else View.GONE
    }

    private fun saveProviderSelection(provider: VoiceRecognitionProvider) {
        providerConfigStore.save(providerConfigStore.load().copy(activeRecognitionProvider = provider))
        bindState()
    }

    private fun providerLabel(provider: VoiceRecognitionProvider): String = when (provider) {
        VoiceRecognitionProvider.AndroidSystem -> getString(com.shinsoku.mobile.R.string.provider_android_system)
        VoiceRecognitionProvider.OpenAiCompatible -> getString(com.shinsoku.mobile.R.string.provider_openai_compatible)
        VoiceRecognitionProvider.Soniox -> getString(com.shinsoku.mobile.R.string.provider_soniox)
        VoiceRecognitionProvider.Bailian -> getString(com.shinsoku.mobile.R.string.provider_bailian)
    }

}
