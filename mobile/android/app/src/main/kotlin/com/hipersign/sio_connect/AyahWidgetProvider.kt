package com.hipersign.sio_connect

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/** Home-screen widget: today's ayah (Malayalam), the streak, and the next prayer time. Data comes from the app. */
class AyahWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Calendar.getInstance().time)
        val fresh = widgetData.getString("w_day", "") == today
        val streak = widgetData.getInt("w_streak", 0)
        val readToday = fresh && widgetData.getBoolean("w_read", false)
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.ayah_widget)
            v.setTextViewText(
                R.id.w_header,
                (if (widgetData.getString("w_kind", "") == "Hadith") "HADITH OF THE DAY" else "AYAH OF THE DAY") +
                    if (streak > 0) "  ·  🔥 $streak" else "",
            )
            if (fresh) {
                v.setTextViewText(R.id.w_text, widgetData.getString("w_text", "") ?: "")
                v.setTextViewText(R.id.w_ref, "— " + (widgetData.getString("w_ref", "") ?: ""))
            } else {
                v.setTextViewText(R.id.w_text, "ഇന്നത്തെ ആയത്ത് വായിക്കാൻ തുറക്കുക · Tap to read today’s ayah")
                v.setTextViewText(R.id.w_ref, "")
            }
            v.setTextViewText(R.id.w_status, if (readToday) "✅ Read today" else "📖 Not read yet today")
            v.setTextViewText(R.id.w_prayer, nextPrayer(widgetData.getString("w_times", "") ?: ""))
            v.setOnClickPendingIntent(R.id.w_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            appWidgetManager.updateAppWidget(id, v)
        }
    }

    /** "Fajr|05:01,Dhuhr|12:21,..." → "🕌 Asr 3:42 PM" (the next one from now; tomorrow's Fajr after Isha). */
    private fun nextPrayer(times: String): String {
        if (times.isEmpty()) return ""
        val now = Calendar.getInstance()
        val mins = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val list = times.split(",").mapNotNull {
            val p = it.split("|")
            if (p.size != 2) return@mapNotNull null
            val hm = p[1].split(":")
            if (hm.size != 2) return@mapNotNull null
            Pair(p[0], (hm[0].toIntOrNull() ?: return@mapNotNull null) * 60 + (hm[1].toIntOrNull() ?: 0))
        }
        if (list.isEmpty()) return ""
        val next = list.firstOrNull { it.second > mins } ?: list.first()
        val h = next.second / 60
        val m = next.second % 60
        val h12 = if (h % 12 == 0) 12 else h % 12
        return "🕌 Next: ${next.first} " + String.format(Locale.US, "%d:%02d %s", h12, m, if (h < 12) "AM" else "PM")
    }
}
