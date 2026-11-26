package com.hipersign.sio_connect

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/** What Noor feels right now, worked out from what the app saved (shared by both widgets). */
class NoorState(
    val cal: Calendar,
    val fresh: Boolean,
    val readToday: Boolean,
    val streak: Int,
    val games: Boolean,
    val name: String,
    val mood: String,
) {
    companion object {
        fun of(d: SharedPreferences): NoorState {
            val cal = Calendar.getInstance()
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(cal.time)
            val fresh = d.getString("w_day", "") == today
            val readToday = d.getString("w_read_day", "") == today
            val streak = if (readToday || fresh) d.getInt("w_streak", 0) else 0
            val games = !d.getBoolean("w_hide_games", false)
            val missed = d.getBoolean("w_missed", false) && !readToday
            val name = (d.getString("w_name", "") ?: "").trim()
            val h = cal.get(Calendar.HOUR_OF_DAY)
            val mood = when {
                readToday -> "happy"
                missed && streak == 0 -> "out"
                h < 12 -> "hello"
                h < 17 -> "waiting"
                h < 21 -> "worried"
                else -> "urgent"
            }
            return NoorState(cal, fresh, readToday, streak, games, name, mood)
        }

        fun stage(streak: Int) = when {
            streak >= 100 -> 4
            streak >= 30 -> 3
            streak >= 7 -> 2
            streak >= 3 -> 1
            else -> 0
        }

        /** The sprout picture for a mood at the size the streak has grown to (dried-up seedling when out). */
        fun face(context: Context, mood: String, streak: Int): Int {
            val img = when (mood) {
                "happy" -> "happy"
                "out" -> "out"
                "waiting" -> "waiting"
                "worried", "urgent" -> "sad"
                else -> "hello"
            }
            val st = if (mood == "out") 0 else stage(streak)
            val id = context.resources.getIdentifier("sprout_s${st}_$img", "drawable", context.packageName)
            return if (id != 0) id else R.drawable.noor_hello
        }
    }
}

/**
 * Small 2×2 widget, Duolingo-style: big streak number, a short nudge with the person's name, and Noor the sprout
 * in its pot at the bottom (bigger as the streak grows). The colour follows Noor's mood (sky blue in the morning, dusk purple in the evening, red late
 * at night, gold once today's ayah is read, grey when the light went out).
 */
class NoorWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val st = NoorState.of(widgetData)
        val first = st.name.split(" ").firstOrNull { it.isNotEmpty() } ?: ""
        val n = if (first.isEmpty()) "" else "$first! "
        val says = when (st.mood) {
            "happy" -> if (first.isEmpty()) "Watered today 💧" else "Thank you, $first 💧"
            "hello" -> "${n}Ayah time? ☀️"
            "waiting" -> "${n}One ayah? 👀"
            "worried" -> "${n}I’m thirsty 🥺"
            "urgent" -> "${n}Water me! 💧"
            else -> if (first.isEmpty()) "I dried up… 🥀" else "$first… I dried up 🥀"
        }
        val bg = when (st.mood) {
            "happy" -> R.drawable.noor_bg_happy
            "waiting" -> R.drawable.noor_bg_waiting
            "worried" -> R.drawable.noor_bg_worried
            "urgent" -> R.drawable.noor_bg_urgent
            "out" -> R.drawable.noor_bg_out
            else -> R.drawable.noor_bg_hello
        }
        val pic = NoorState.face(context, st.mood, st.streak)
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, R.layout.noor_widget)
            v.setInt(R.id.n_root, "setBackgroundResource", bg)
            v.setImageViewResource(R.id.n_noor, pic)
            v.setTextViewText(R.id.n_says, says)
            if (st.games) {
                v.setViewVisibility(R.id.n_flame, View.VISIBLE)
                v.setTextViewText(R.id.n_streak, st.streak.toString())
            } else {
                v.setViewVisibility(R.id.n_flame, View.GONE)
                v.setTextViewText(R.id.n_streak, if (st.readToday) "✓" else "Noor")
            }
            v.setOnClickPendingIntent(R.id.n_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            appWidgetManager.updateAppWidget(id, v)
        }
    }
}
