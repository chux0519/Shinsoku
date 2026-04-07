package com.shinsoku.mobile

import android.content.Intent
import android.provider.Settings
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.shinsoku.mobile.databinding.ActivityMainBinding
import com.shinsoku.mobile.ime.queryImeStatus
import com.shinsoku.mobile.settings.SettingsActivity
import com.shinsoku.mobile.settings.AndroidVoiceInputConfigStore
import com.shinsoku.mobile.speechcore.CommitSuffixMode
import android.Manifest
import android.content.pm.PackageManager
import android.view.inputmethod.InputMethodManager
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding
    private lateinit var configStore: AndroidVoiceInputConfigStore
    private val requestMicrophonePermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) {
            bindState()
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        configStore = AndroidVoiceInputConfigStore(this)

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
        binding.openSettingsButton.setOnClickListener {
            startActivity(Intent(this, SettingsActivity::class.java))
        }
    }

    override fun onResume() {
        super.onResume()
        bindState()
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
        binding.behaviorSummaryText.text = getString(
            R.string.behavior_summary_template,
            if (profile.autoCommit) getString(R.string.behavior_auto_commit_on) else getString(R.string.behavior_auto_commit_off),
            when (profile.commitSuffixMode) {
                CommitSuffixMode.None -> getString(R.string.commit_suffix_none)
                CommitSuffixMode.Space -> getString(R.string.commit_suffix_space)
                CommitSuffixMode.Newline -> getString(R.string.commit_suffix_newline)
            },
            profile.languageTag ?: getString(R.string.language_auto_label),
        )
    }
}
