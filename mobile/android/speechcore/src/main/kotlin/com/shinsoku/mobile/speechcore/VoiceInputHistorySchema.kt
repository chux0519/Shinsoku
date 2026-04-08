package com.shinsoku.mobile.speechcore

object VoiceInputHistorySchema {
    const val DATABASE_NAME = "shinsoku_voice_input.db"
    const val DATABASE_VERSION = 2

    const val TABLE_HISTORY = "voice_input_history"
    const val COLUMN_ID = "id"
    const val COLUMN_TEXT = "text"
    const val COLUMN_COMMITTED_AT_EPOCH_MILLIS = "committed_at_epoch_millis"
    const val COLUMN_PROVIDER = "provider"
    const val COLUMN_PROFILE_NAME = "profile_name"
    const val COLUMN_TRANSFORM_MODE = "transform_mode"
    const val COLUMN_POST_PROCESSING_MODE = "post_processing_mode"
    const val COLUMN_AUTO_COMMIT = "auto_commit"
    const val COLUMN_COMMIT_SUFFIX_MODE = "commit_suffix_mode"
    const val COLUMN_LANGUAGE_TAG = "language_tag"
    const val COLUMN_DEBUG_DETAIL = "debug_detail"
}
