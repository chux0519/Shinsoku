package com.shinsoku.mobile.speechcore

object TranscriptCommitPlanner {
    fun plan(text: String, profile: VoiceInputProfile): VoiceInputCommit =
        VoiceInputCommit(
            text = text + when (profile.commitSuffixMode) {
                CommitSuffixMode.None -> ""
                CommitSuffixMode.Space -> " "
                CommitSuffixMode.Newline -> "\n"
            },
        )
}
