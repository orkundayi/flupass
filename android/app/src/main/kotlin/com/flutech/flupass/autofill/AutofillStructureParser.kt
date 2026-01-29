package com.flutech.flupass.autofill

import android.app.assist.AssistStructure
import android.os.Build
import android.view.View
import android.view.autofill.AutofillId

data class AutofillFieldIds(
    val usernameId: AutofillId?,
    val passwordId: AutofillId?,
    val webDomain: String?,
    val packageName: String?,
)

class AutofillStructureParser(private val structure: AssistStructure) {
    fun parseCredentialFields(): AutofillFieldIds {
        var usernameId: AutofillId? = null
        var passwordId: AutofillId? = null
        var webDomain: String? = null
        val packageName = structure.activityComponent?.packageName

        for (index in 0 until structure.windowNodeCount) {
            val node = structure.getWindowNodeAt(index).rootViewNode
            traverse(node) { viewNode ->
                if (usernameId == null && isUsernameField(viewNode)) {
                    usernameId = viewNode.autofillId
                }
                if (passwordId == null && isPasswordField(viewNode)) {
                    passwordId = viewNode.autofillId
                }
                if (webDomain == null) {
                    webDomain = viewNode.webDomain
                }
            }
            if (usernameId != null && passwordId != null) {
                break
            }
        }

        return AutofillFieldIds(
            usernameId = usernameId,
            passwordId = passwordId,
            webDomain = webDomain,
            packageName = packageName,
        )
    }

    private fun traverse(node: AssistStructure.ViewNode, block: (AssistStructure.ViewNode) -> Unit) {
        block(node)
        for (index in 0 until node.childCount) {
            traverse(node.getChildAt(index), block)
        }
    }

    private fun isUsernameField(node: AssistStructure.ViewNode): Boolean {
        val hints = node.autofillHints
        if (hints != null && hints.any { isUsernameHint(it) }) {
            return true
        }
        val resourceId = node.idEntry?.lowercase()
        if (resourceId != null && usernameResourceHints.any { resourceId.contains(it) }) {
            return true
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && node.htmlInfo != null) {
            val attributes = node.htmlInfo?.attributes ?: emptyList()
            val hasUsernameType = attributes.any { attr ->
                attr.first.equals("type", ignoreCase = true) &&
                    usernameHtmlTypes.contains(attr.second.lowercase())
            }
            if (hasUsernameType) {
                return true
            }
        }
        return false
    }

    private fun isPasswordField(node: AssistStructure.ViewNode): Boolean {
        val hints = node.autofillHints
        if (hints != null && hints.any { isPasswordHint(it) }) {
            return true
        }
        val resourceId = node.idEntry?.lowercase()
        if (resourceId != null && passwordResourceHints.any { resourceId.contains(it) }) {
            return true
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && node.htmlInfo != null) {
            val attributes = node.htmlInfo?.attributes ?: emptyList()
            val hasPasswordType = attributes.any { attr ->
                attr.first.equals("type", ignoreCase = true) &&
                    attr.second.equals("password", ignoreCase = true)
            }
            if (hasPasswordType) {
                return true
            }
        }
        return false
    }

    private fun isUsernameHint(hint: String): Boolean {
        val normalized = hint.lowercase()
        return normalized == View.AUTOFILL_HINT_USERNAME ||
            normalized == View.AUTOFILL_HINT_EMAIL_ADDRESS ||
            normalized.contains("email") ||
            normalized.contains("login") ||
            normalized.contains("user")
    }

    private fun isPasswordHint(hint: String): Boolean {
        val normalized = hint.lowercase()
        return normalized == View.AUTOFILL_HINT_PASSWORD ||
            normalized.contains("password")
    }

    companion object {
        private val usernameResourceHints = listOf("email", "user", "login")
        private val passwordResourceHints = listOf("pass", "password", "pwd")
        private val usernameHtmlTypes = setOf("email", "text", "login", "username")
    }
}
