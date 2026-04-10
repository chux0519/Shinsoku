package com.shinsoku.mobile

import android.content.Intent
import android.provider.Settings
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.ArrayAdapter
import androidx.appcompat.app.AppCompatActivity
import com.shinsoku.mobile.databinding.ActivityMainBinding
import com.shinsoku.mobile.ime.RecognitionEngineFactory
import com.shinsoku.mobile.ime.RecognitionProviderDiagnostics
import com.shinsoku.mobile.speechcore.VoiceInputProfiles
import com.shinsoku.mobile.history.AndroidVoiceInputHistoryStore
import com.shinsoku.mobile.history.HistoryActivity
import com.shinsoku.mobile.ime.queryImeStatus
import com.shinsoku.mobile.processing.AndroidVoicePostProcessor
import com.shinsoku.mobile.processing.NativeTranscriptCleanup
import com.shinsoku.mobile.settings.SettingsActivity
import com.shinsoku.mobile.settings.AndroidVoiceInputConfigStore
import com.shinsoku.mobile.settings.AndroidVoiceProviderConfigStore
import com.shinsoku.mobile.speechcore.CommitSuffixMode
import com.shinsoku.mobile.speechcore.VoiceInputCommit
import com.shinsoku.mobile.speechcore.VoiceInputController
import com.shinsoku.mobile.speechcore.VoiceInputControllerObserver
import com.shinsoku.mobile.speechcore.VoiceInputHistoryEntry
import com.shinsoku.mobile.speechcore.TranscriptCommitPlanner
import com.shinsoku.mobile.speechcore.TranscriptPostProcessingMode
import com.shinsoku.mobile.speechcore.VoiceRecognitionProvider
import com.shinsoku.mobile.speechcore.VoiceTransformMode
import com.shinsoku.mobile.speechcore.VoiceInputUiState
import android.Manifest
import android.content.pm.PackageManager
import android.view.inputmethod.InputMethodManager
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import java.util.UUID
import com.shinsoku.mobile.settings.AndroidVoiceRuntimeConfigStore

class MainActivity : AppCompatActivity() {
    companion object {
        private const val TAG = "ShinsokuMain"
    }

    private lateinit var binding: ActivityMainBinding
    private lateinit var configStore: AndroidVoiceInputConfigStore
    private lateinit var historyStore: AndroidVoiceInputHistoryStore
    private lateinit var providerConfigStore: AndroidVoiceProviderConfigStore
    private lateinit var runtimeConfigStore: AndroidVoiceRuntimeConfigStore
    private lateinit var presetOptions: LinkedHashMap<String, com.shinsoku.mobile.speechcore.VoiceInputProfile>
    private var labController: VoiceInputController? = null
    private val requestMicrophonePermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) {
            bindState()
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        configStore = AndroidVoiceInputConfigStore(this)
        historyStore = AndroidVoiceInputHistoryStore(this)
        providerConfigStore = AndroidVoiceProviderConfigStore(this)
        runtimeConfigStore = AndroidVoiceRuntimeConfigStore(this)
        presetOptions = LinkedHashMap<String, com.shinsoku.mobile.speechcore.VoiceInputProfile>().apply {
            VoiceInputProfiles.builtIns.forEach { put(it.displayName, it) }
        }
        binding.mainWorkflowPresetDropdown.setAdapter(
            ArrayAdapter(this, android.R.layout.simple_list_item_1, presetOptions.keys.toList()),
        )
        binding.mainWorkflowPresetDropdown.setOnItemClickListener { _, _, position, _ ->
            presetOptions.values.elementAtOrNull(position)?.let {
                configStore.saveProfile(it)
                bindState()
            }
        }

        binding.requestPermissionButton.setOnClickListener {
            requestMicrophonePermission.launch(Manifest.permission.RECORD_AUDIO)
        }
        TranscriptCommitPlanner.nativeCommitPlanner = NativeTranscriptCleanup::planTranscriptCommit
        binding.openKeyboardSettingsButton.setOnClickListener {
            startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS))
        }
        binding.openInputMethodPickerButton.setOnClickListener {
            val imm = getSystemService(InputMethodManager::class.java)
            imm?.showInputMethodPicker()
        }
        binding.openSettingsButton.setOnClickListener {
            startActivity(Intent(this, SettingsActivity::class.java))
        }
        binding.openHistoryButton.setOnClickListener {
            startActivity(Intent(this, HistoryActivity::class.java))
        }
        binding.voiceLabMicButton.setOnClickListener {
            ensureLabController()
            labController?.onMicTapped()
        }
        binding.voiceLabInsertButton.setOnClickListener {
            labController?.commitPending()
        }
        binding.voiceLabClearButton.setOnClickListener {
            labController?.discardPending()
        }
    }

    override fun onResume() {
        super.onResume()
        rebuildLabController()
        bindState()
    }

    override fun onDestroy() {
        labController?.destroy()
        labController = null
        super.onDestroy()
    }

    private fun bindState() {
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
        val imeStatus = queryImeStatus(this)
        val profile = configStore.loadProfile()

        binding.permissionStatusText.text = getString(
            if (granted) R.string.permission_status_granted else R.string.permission_status_missing,
        )
        binding.keyboardEnabledStatusText.text = getString(
            if (imeStatus.enabled) R.string.keyboard_enabled_status else R.string.keyboard_disabled_status,
        )
        binding.keyboardSelectedStatusText.text = getString(
            if (imeStatus.selected) R.string.keyboard_selected_status else R.string.keyboard_not_selected_status,
        )
        binding.behaviorSummaryText.text = profile.behaviorSummary + " • " + (profile.languageTag ?: getString(R.string.language_auto_label)) + "\n" + when {
            !profile.transform.enabled -> getString(R.string.transform_summary_disabled)
            profile.transform.mode == VoiceTransformMode.Cleanup -> getString(R.string.transform_summary_cleanup)
            profile.transform.mode == VoiceTransformMode.Translation -> getString(
                R.string.transform_summary_translation,
                profile.transform.translationSourceLanguage,
                profile.transform.translationTargetLanguage,
            )
            else -> getString(R.string.transform_summary_custom)
        }
        binding.activeProfileText.text = getString(R.string.active_profile_template, profile.displayName)
        val providerConfig = providerConfigStore.load()
        val runtimeConfig = runtimeConfigStore.loadRuntimeConfig()
        val providerStatus = RecognitionProviderDiagnostics.status(providerConfig)
        binding.providerSummaryText.text = getString(
            R.string.provider_summary_template,
            when (providerConfig.activeRecognitionProvider) {
                VoiceRecognitionProvider.AndroidSystem -> getString(R.string.provider_android_system)
                VoiceRecognitionProvider.OpenAiCompatible -> getString(R.string.provider_openai_compatible)
                VoiceRecognitionProvider.Soniox -> getString(R.string.provider_soniox)
                VoiceRecognitionProvider.Bailian -> getString(R.string.provider_bailian)
            },
            providerStatus.summary,
        ) + "\n" + getString(
            R.string.post_processing_summary_template,
            when (runtimeConfig.postProcessingConfig.mode) {
                TranscriptPostProcessingMode.Disabled -> getString(R.string.post_processing_disabled)
                TranscriptPostProcessingMode.LocalCleanup -> getString(R.string.post_processing_local_cleanup)
                TranscriptPostProcessingMode.ProviderAssisted -> getString(R.string.post_processing_provider_assisted)
            },
        ) + "\n" + providerStatus.detail
        binding.mainPresetSummaryText.text = profile.summary.ifBlank { getString(R.string.preset_custom_summary) }
        binding.mainWorkflowPresetDropdown.setText(profile.displayName, false)
        val latestEntry = historyStore.listEntries(limit = 1).firstOrNull()
        binding.recentHistoryPreviewText.text = latestEntry?.text ?: getString(R.string.history_empty)
    }

    private fun rebuildLabController() {
        labController?.destroy()
        labController = VoiceInputController(
            engine = RecognitionEngineFactory.create(this),
            configStore = configStore,
            observer = object : VoiceInputControllerObserver {
                override fun onStateChanged(state: VoiceInputUiState) {
                    runOnUiThread { bindVoiceLabState(state) }
                }

                override fun onCommitRequested(commit: VoiceInputCommit) {
                    runOnUiThread {
                        val existing = binding.testEditor.text?.toString().orEmpty()
                        binding.testEditor.setText(existing + commit.text)
                        binding.testEditor.setSelection(binding.testEditor.text?.length ?: 0)
                        appendHistory(commit)
                        bindState()
                    }
                }
            },
            postProcessor = AndroidVoicePostProcessor(this),
        )
    }

    private fun ensureLabController() {
        if (labController == null) {
            rebuildLabController()
        }
    }

    private fun bindVoiceLabState(state: VoiceInputUiState) {
        when (state) {
            is VoiceInputUiState.Idle -> {
                binding.voiceLabStatusText.text = getString(R.string.voice_lab_idle)
                binding.voiceLabMicButton.text = getString(R.string.voice_lab_start)
                binding.voiceLabInsertButton.visibility = View.GONE
                binding.voiceLabClearButton.visibility = View.GONE
            }

            is VoiceInputUiState.Preparing -> {
                binding.voiceLabStatusText.text = getString(R.string.ime_title_preparing)
                binding.voiceLabMicButton.text = getString(R.string.voice_lab_stop)
                binding.voiceLabInsertButton.visibility = View.GONE
                binding.voiceLabClearButton.visibility = View.GONE
            }

            is VoiceInputUiState.Listening -> {
                binding.voiceLabStatusText.text = if (state.partialTranscript.isBlank()) {
                    getString(R.string.ime_title_listening)
                } else {
                    state.partialTranscript
                }
                binding.voiceLabMicButton.text = getString(R.string.voice_lab_stop)
                binding.voiceLabInsertButton.visibility = View.GONE
                binding.voiceLabClearButton.visibility = View.GONE
            }

            is VoiceInputUiState.Processing -> {
                binding.voiceLabStatusText.text = getString(R.string.voice_lab_processing)
                binding.voiceLabMicButton.text = getString(R.string.voice_lab_stop)
                binding.voiceLabInsertButton.visibility = View.GONE
                binding.voiceLabClearButton.visibility = View.GONE
            }

            is VoiceInputUiState.PendingCommit -> {
                binding.voiceLabStatusText.text = state.text.trimEnd('\n', ' ')
                binding.voiceLabMicButton.text = getString(R.string.voice_lab_start)
                binding.voiceLabInsertButton.visibility = View.VISIBLE
                binding.voiceLabClearButton.visibility = View.VISIBLE
            }

            is VoiceInputUiState.Error -> {
                Log.e(TAG, "Voice lab error: ${state.message}")
                binding.voiceLabStatusText.text = state.message
                binding.voiceLabMicButton.text = getString(R.string.voice_lab_start)
                binding.voiceLabInsertButton.visibility = View.GONE
                binding.voiceLabClearButton.visibility = View.GONE
            }
        }
    }

    private fun appendHistory(commit: VoiceInputCommit) {
        val profile = configStore.loadProfile()
        val runtimeConfig = runtimeConfigStore.loadRuntimeConfig()
        historyStore.appendEntry(
            VoiceInputHistoryEntry(
                id = UUID.randomUUID().toString(),
                text = commit.text,
                committedAtEpochMillis = System.currentTimeMillis(),
                provider = providerLabel(providerConfigStore.load().activeRecognitionProvider),
                profileName = profile.displayName,
                transformMode = profile.transform.mode.name,
                postProcessingMode = runtimeConfig.postProcessingConfig.mode.name,
                autoCommit = profile.autoCommit,
                commitSuffixMode = profile.commitSuffixMode,
                languageTag = profile.languageTag,
                debugDetail = buildString {
                    append("request_format=")
                    append(profile.transform.requestFormat.name)
                    append(", transform_enabled=")
                    append(profile.transform.enabled)
                    if (profile.transform.mode == VoiceTransformMode.Translation) {
                        append(", source=")
                        append(profile.transform.translationSourceLanguage)
                        append(", target=")
                        append(profile.transform.translationTargetLanguage)
                    }
                },
            ),
        )
    }

    private fun providerLabel(provider: VoiceRecognitionProvider): String = when (provider) {
        VoiceRecognitionProvider.AndroidSystem -> getString(R.string.provider_android_system)
        VoiceRecognitionProvider.OpenAiCompatible -> getString(R.string.provider_openai_compatible)
        VoiceRecognitionProvider.Soniox -> getString(R.string.provider_soniox)
        VoiceRecognitionProvider.Bailian -> getString(R.string.provider_bailian)
    }
}
