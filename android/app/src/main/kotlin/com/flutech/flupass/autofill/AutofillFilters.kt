package com.flutech.flupass.autofill

fun filterEntriesByDomain(
    entries: List<AutofillEntry>,
    webDomain: String?,
): List<AutofillEntry> {
    val normalized = webDomain
        ?.lowercase()
        ?.removePrefix("https://")
        ?.removePrefix("http://")
        ?.removePrefix("www.")
        ?.takeIf { it.isNotBlank() }
    if (normalized.isNullOrBlank()) {
        return entries
    }
    return entries.filter { entry ->
        val website = entry.website?.lowercase()?.removePrefix("www.") ?: return@filter false
        website.contains(normalized)
    }
}
