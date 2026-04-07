package com.shinsoku.mobile.ime

import android.content.Context
import android.provider.Settings
import android.view.inputmethod.InputMethodManager

data class AndroidImeStatus(
    val enabled: Boolean,
    val selected: Boolean,
)

fun queryImeStatus(context: Context): AndroidImeStatus {
    val imm = context.getSystemService(InputMethodManager::class.java)
    val enabled = imm?.enabledInputMethodList?.any { it.packageName == context.packageName } == true
    val selectedId = Settings.Secure.getString(
        context.contentResolver,
        Settings.Secure.DEFAULT_INPUT_METHOD,
    ).orEmpty()
    val selected = selectedId.startsWith("${context.packageName}/")
    return AndroidImeStatus(enabled = enabled, selected = selected)
}
