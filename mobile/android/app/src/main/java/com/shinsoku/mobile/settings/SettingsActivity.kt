package com.shinsoku.mobile.settings

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import com.shinsoku.mobile.databinding.ActivitySettingsBinding

class SettingsActivity : AppCompatActivity() {
    private lateinit var binding: ActivitySettingsBinding
    private lateinit var configStore: AndroidVoiceInputConfigStore
    private val requestMicrophonePermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) {
            bindState()
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySettingsBinding.inflate(layoutInflater)
        setContentView(binding.root)
        configStore = AndroidVoiceInputConfigStore(this)

        binding.requestPermissionButton.setOnClickListener {
            requestMicrophonePermission.launch(Manifest.permission.RECORD_AUDIO)
        }
        binding.autoCommitSwitch.setOnCheckedChangeListener { _, isChecked ->
            configStore.saveAutoCommit(isChecked)
        }
        binding.appendTrailingSpaceSwitch.setOnCheckedChangeListener { _, isChecked ->
            configStore.saveAppendTrailingSpace(isChecked)
        }
        binding.saveLanguageButton.setOnClickListener {
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
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED

        binding.permissionStatusText.text = getString(
            if (granted) com.shinsoku.mobile.R.string.permission_status_granted
            else com.shinsoku.mobile.R.string.permission_status_missing,
        )
        binding.autoCommitSwitch.isChecked = profile.autoCommit
        binding.appendTrailingSpaceSwitch.isChecked = profile.appendTrailingSpace
        val languageText = profile.languageTag.orEmpty()
        if (binding.languageTagEdit.text?.toString() != languageText) {
            binding.languageTagEdit.setText(languageText)
        }
    }
}
