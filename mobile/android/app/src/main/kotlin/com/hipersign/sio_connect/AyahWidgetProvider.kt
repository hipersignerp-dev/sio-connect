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

/**
 * Home-screen widget with Noor, SIO Connect's lantern. Noor's face and words follow the day: happy once today's
 * ayah is read; hello in the morning, waiting in the afternoon, worried in the evening, nearly out late at night;
 * light out after a missed day. Also shows the ayah, the streak and the next prayer. Data comes from the app.
 */
class AyahWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val st = NoorState.of(widgetData)
        val cal = st.cal
        val fresh = st.fresh
        val readToday = st.readToday
        val streak = st.streak
        val games = st.games
        val name = st.name
        val mood = st.mood
        val pick = cal.get(Calendar.YEAR) * 400 + (cal.get(Calendar.MONTH) + 1) * 31 + cal.get(Calendar.DAY_OF_MONTH)
        val says = line(mood, if (games) streak else 0, name, pick)
        val img = NoorState.face(context, mood, streak)
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.ayah_widget)
            v.setImageViewResource(R.id.w_noor, img)
            v.setTextViewText(R.id.w_says, says)
            v.setTextViewText(
                R.id.w_text,
                if (fresh) (widgetData.getString("w_text", "") ?: "") else "Tap to open today’s ayah",
            )
            v.setTextViewText(R.id.w_header, if (games && streak > 0) "🔥 $streak" else if (readToday) "✅ Read" else "")
            v.setTextViewText(R.id.w_prayer, nextPrayer(widgetData.getString("w_times", "") ?: ""))
            v.setOnClickPendingIntent(R.id.w_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            appWidgetManager.updateAppWidget(id, v)
        }
    }

    private fun line(mood: String, streak: Int, name: String, pick: Int): String {
        val n = if (name.isEmpty()) "" else ", $name"
        val s = streak > 0
        val lines = when (mood) {
            "happy" -> listOfNotNull(
                if (s) "$streak days$n! I’m growing so well 🌱" else null,
                "Alhamdulillah! You watered me today 💧",
                "Thank you$n. I feel so fresh. See you tomorrow!",
            )
            "hello" -> listOf("Assalamu Alaikum$n! ☀️ One ayah to water me?", "Morning! Let’s grow together today 🌱")
            "waiting" -> listOfNotNull(
                "I’m waiting for you$n 👀 Just one ayah.",
                if (s) "Your $streak-day sprout is getting thirsty." else null,
                "I saved today’s ayah for you$n.",
            )
            "worried" -> listOfNotNull(
                "I’m getting thirsty$n… 🥺",
                if (s) "Please don’t let me dry up after $streak days!" else null,
                "My leaves are drooping… one ayah and I’ll stand up again.",
            )
            "urgent" -> listOfNotNull(
                "I’m so thirsty$n! One ayah before you sleep?",
                if (s) "Only a few hours left for your $streak days 😢" else null,
            )
            else -> listOf("I dried up$n… 🥀 Water me today and I’ll grow again.", "Every day is a new start. Plant me again?")
        }
        return lines[pick % lines.size]
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
        return "🕌 ${next.first} " + String.format(Locale.US, "%d:%02d %s", h12, m, if (h < 12) "AM" else "PM")
    }
}
