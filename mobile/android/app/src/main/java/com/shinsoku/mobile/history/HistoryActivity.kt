package com.shinsoku.mobile.history

import android.os.Bundle
import android.text.format.DateFormat
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.card.MaterialCardView
import com.shinsoku.mobile.R
import com.shinsoku.mobile.databinding.ActivityHistoryBinding
import com.shinsoku.mobile.speechcore.CommitSuffixMode
import com.shinsoku.mobile.speechcore.VoiceInputHistoryEntry
import java.util.Date

class HistoryActivity : AppCompatActivity() {
    private lateinit var binding: ActivityHistoryBinding
    private lateinit var historyStore: AndroidVoiceInputHistoryStore

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityHistoryBinding.inflate(layoutInflater)
        setContentView(binding.root)
        historyStore = AndroidVoiceInputHistoryStore(this)

        binding.clearHistoryButton.setOnClickListener {
            historyStore.clear()
            bindState()
        }
    }

    override fun onResume() {
        super.onResume()
        bindState()
    }

    private fun bindState() {
        val entries = historyStore.listEntries(limit = 50)
        binding.historyEmptyText.visibility = if (entries.isEmpty()) TextView.VISIBLE else TextView.GONE
        binding.historyContainer.removeAllViews()
        entries.forEach { entry ->
            binding.historyContainer.addView(buildHistoryCard(entry))
        }
    }

    private fun buildHistoryCard(entry: VoiceInputHistoryEntry): MaterialCardView {
        val card = MaterialCardView(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).also { it.topMargin = dp(12) }
            radius = dp(16).toFloat()
        }
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(18), dp(18), dp(18))
        }
        val textView = TextView(this).apply {
            text = entry.text
            setTextAppearance(com.google.android.material.R.style.TextAppearance_Material3_BodyLarge)
        }
        val metaView = TextView(this).apply {
            val time = DateFormat.format("yyyy-MM-dd HH:mm", Date(entry.committedAtEpochMillis))
            val mode = if (entry.autoCommit) {
                getString(R.string.history_mode_auto)
            } else {
                getString(R.string.history_mode_review)
            }
            val suffix = when (entry.commitSuffixMode) {
                CommitSuffixMode.None -> getString(R.string.commit_suffix_none)
                CommitSuffixMode.Space -> getString(R.string.commit_suffix_space)
                CommitSuffixMode.Newline -> getString(R.string.commit_suffix_newline)
            }
            text = getString(
                R.string.history_meta_template,
                time,
                mode,
                suffix,
                entry.languageTag ?: getString(R.string.language_auto_label),
            )
            setTextAppearance(com.google.android.material.R.style.TextAppearance_Material3_BodySmall)
            setPadding(0, dp(10), 0, 0)
        }
        content.addView(textView)
        content.addView(metaView)
        card.addView(content)
        return card
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}
