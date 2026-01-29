package com.flutech.flupass.autofill

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.RecyclerView
import com.flutech.flupass.R

class AutofillChooserAdapter(
    private val onItemClick: (AutofillEntry) -> Unit,
) : RecyclerView.Adapter<AutofillChooserAdapter.ViewHolder>() {

    private val items = mutableListOf<AutofillEntry>()

    fun submitList(entries: List<AutofillEntry>) {
        items.clear()
        items.addAll(entries)
        notifyDataSetChanged()
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val inflater = LayoutInflater.from(parent.context)
        val view = inflater.inflate(R.layout.item_autofill_account, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        holder.bind(items[position])
    }

    override fun getItemCount(): Int = items.size

    inner class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {

        private val avatar: TextView = view.findViewById(R.id.autofill_avatar)
        private val title: TextView = view.findViewById(R.id.autofill_title_text)
        private val subtitleView: TextView = view.findViewById(R.id.autofill_subtitle_text)

        fun bind(entry: AutofillEntry) {
            val primary = entry.primaryLabel()
            val subtitle = entry.secondaryLabel()
            title.text = primary
            subtitleView.text = subtitle
            subtitleView.visibility =
                if (subtitle.isNullOrBlank()) {
                    View.GONE
                } else {
                    View.VISIBLE
                }

            avatar.text = buildAvatarText(primary, subtitle, entry)

            itemView.setOnClickListener { onItemClick(entry) }
        }
    }

    private fun buildAvatarText(
        primary: String,
        subtitle: String?,
        entry: AutofillEntry,
    ): String {
        val source = primary.takeIf { it.isNotBlank() }
            ?: subtitle?.takeIf { it.isNotBlank() }
            ?: entry.username.takeIf { it.isNotBlank() }
            ?: entry.title.takeIf { it.isNotBlank() }
            ?: entry.website?.takeIf { it.isNotBlank() }
            ?: "F"
        val initial = source.firstOrNull { it.isLetterOrDigit() } ?: 'F'
        return initial.uppercaseChar().toString()
    }
}
