package com.shinsoku.mobile.speechcore

object TranscriptCommitPlanner {
    var nativeCommitPlanner: ((text: String, suffixModeName: String) -> String)? = null

    fun plan(text: String, profile: VoiceInputProfile): VoiceInputCommit {
        val suffixModeName = profile.commitSuffixMode.name
        val planned = nativeCommitPlanner?.invoke(text, suffixModeName)
            ?: defaultPlan(text, suffixModeName)
        return VoiceInputCommit(text = planned)
    }

    private fun defaultPlan(text: String, suffixModeName: String): String =
        text + when (suffixModeName) {
            CommitSuffixMode.None.name -> ""
            CommitSuffixMode.Newline.name -> "\n"
            else -> " "
        }
}
