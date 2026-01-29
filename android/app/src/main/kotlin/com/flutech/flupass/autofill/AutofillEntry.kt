package com.flutech.flupass.autofill

import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject

data class AutofillEntry(
    val id: Int?,
    val title: String,
    val username: String,
    val password: String,
    val website: String?
) {
    fun primaryLabel(): String {
        return when {
            username.isNotBlank() -> username
            title.isNotBlank() -> title
            else -> websiteLabel() ?: ""
        }
    }

    fun secondaryLabel(): String? {
        val primary = primaryLabel()
        val candidates = listOfNotNull(
            when {
                username.isNotBlank() && username != primary -> username
                else -> null
            },
            when {
                title.isNotBlank() && title != primary -> title
                else -> null
            },
            websiteLabel()?.takeIf { it.isNotBlank() && it != primary },
        )
        return candidates.firstOrNull()
    }

    private fun websiteLabel(): String? {
        val raw = website?.takeIf { it.isNotBlank() } ?: return null
        val parsedHost = try {
            Uri.parse(raw).host
        } catch (_: Throwable) {
            null
        }
        return (parsedHost ?: raw)
            .removePrefix("www.")
            .ifBlank { null }
    }

    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("id", id)
            put("title", title)
            put("username", username)
            put("password", password)
            put("website", website)
        }
    }

    companion object {
        fun fromMap(map: Map<String, Any?>): AutofillEntry? {
            val title = map["title"] as? String ?: return null
            val username = map["username"] as? String ?: return null
            val password = map["password"] as? String ?: return null
            val id = when (val rawId = map["id"]) {
                is Int -> rawId
                is Long -> rawId.toInt()
                is Double -> rawId.toInt()
                else -> null
            }
            val website = (map["website"] as? String)?.takeIf { it.isNotBlank() }

            return AutofillEntry(
                id = id,
                title = title,
                username = username,
                password = password,
                website = website,
            )
        }

        fun fromJsonArray(raw: String): List<AutofillEntry> {
            val array = JSONArray(raw)
            val entries = mutableListOf<AutofillEntry>()
            for (index in 0 until array.length()) {
                val obj = array.optJSONObject(index) ?: continue
                val title = obj.optString("title")
                val username = obj.optString("username")
                val password = obj.optString("password")
                if (title.isBlank() || username.isBlank() || password.isBlank()) {
                    continue
                }
                val website = obj.optString("website").takeIf { it.isNotBlank() }
                val id = if (obj.has("id") && !obj.isNull("id")) obj.optInt("id") else null
                entries.add(
                    AutofillEntry(
                        id = id,
                        title = title,
                        username = username,
                        password = password,
                        website = website,
                    ),
                )
            }
            return entries
        }
    }
}
