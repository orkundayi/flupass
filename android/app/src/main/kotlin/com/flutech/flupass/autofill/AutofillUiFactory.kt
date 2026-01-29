package com.flutech.flupass.autofill

import android.app.PendingIntent
import android.content.Context
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import android.widget.inline.InlinePresentationSpec
import androidx.annotation.RequiresApi
import androidx.autofill.inline.v1.InlineSuggestionUi
import android.service.autofill.InlinePresentation
import com.flutech.flupass.R

object AutofillUiFactory {
    fun createDatasetPresentation(context: Context, entry: AutofillEntry): RemoteViews {
        return createDatasetPresentation(
            context,
            entry.primaryLabel(),
            entry.secondaryLabel(),
        )
    }

    fun createDatasetPresentation(
        context: Context,
        title: String,
        subtitle: String?,
    ): RemoteViews {
        return RemoteViews(context.packageName, R.layout.autofill_dataset_item).apply {
            setTextViewText(R.id.autofill_title, title)
            setTextViewText(R.id.autofill_subtitle, subtitle.orEmpty())
            setViewVisibility(
                R.id.autofill_subtitle,
                if (subtitle.isNullOrBlank()) View.GONE else View.VISIBLE,
            )
        }
    }

    @RequiresApi(Build.VERSION_CODES.R)
    fun createInlinePresentation(
        context: Context,
        entry: AutofillEntry,
        spec: InlinePresentationSpec,
        attribution: PendingIntent,
    ) = createInlinePresentation(
        context = context,
        title = entry.primaryLabel(),
        subtitle = entry.secondaryLabel(),
        spec = spec,
        attribution = attribution,
    )

    @RequiresApi(Build.VERSION_CODES.R)
    fun createInlinePresentation(
        context: Context,
        title: String,
        subtitle: String?,
        spec: InlinePresentationSpec,
        attribution: PendingIntent,
    ) = when {
        title.isBlank() -> null
        else -> {
            val contentBuilder = InlineSuggestionUi.newContentBuilder(attribution)
                .setTitle(title)
                .setContentDescription(title)
                .setStartIcon(AutofillUiIcons.launcherIcon(context))
            subtitle?.let { contentBuilder.setSubtitle(it) }
            val content = contentBuilder.build()
            InlinePresentation(content.slice, spec, false)
        }
    }
}
