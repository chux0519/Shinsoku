package com.shinsoku.mobile

import android.content.Intent
import android.provider.Settings
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.shinsoku.mobile.databinding.ActivityMainBinding
import com.shinsoku.mobile.settings.SettingsActivity
import android.Manifest
import android.content.pm.PackageManager
import android.view.inputmethod.InputMethodManager
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding
    private val requestMicrophonePermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) {
            updatePermissionStatus()
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

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
        updatePermissionStatus()
    }

    private fun updatePermissionStatus() {
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECORD_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED

        binding.permissionStatusText.text = getString(
            if (granted) R.string.permission_status_granted else R.string.permission_status_missing,
        )
    }
}
