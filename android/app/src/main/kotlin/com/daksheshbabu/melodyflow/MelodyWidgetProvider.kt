package com.daksheshbabu.melodyflow

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import java.io.File

/**
 * Home-screen widget provider for Melody Flow's 4x1 player widget.
 */
class MelodyWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "MelodyWidget"

        const val ACTION_PLAY_PAUSE = "com.daksheshbabu.melodyflow.PLAY_PAUSE"
        const val ACTION_SKIP_NEXT  = "com.daksheshbabu.melodyflow.SKIP_NEXT"
        const val ACTION_SKIP_PREV  = "com.daksheshbabu.melodyflow.SKIP_PREV"
        const val ACTION_REFRESH    = "com.daksheshbabu.melodyflow.WIDGET_REFRESH"

        private const val PREFS_NAME = "HomeWidgetPreferences"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate for ${appWidgetIds.size} widget(s)")
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        Log.d(TAG, "onReceive: ${intent.action}")

        when (intent.action) {
            ACTION_PLAY_PAUSE, ACTION_SKIP_NEXT, ACTION_SKIP_PREV -> {
                handleControlAction(context, intent.action!!)
            }
            ACTION_REFRESH, AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                val mgr = AppWidgetManager.getInstance(context)
                val ids = mgr.getAppWidgetIds(
                    ComponentName(context, MelodyWidgetProvider::class.java)
                )
                for (id in ids) updateWidget(context, mgr, id)
            }
        }
    }

    private fun handleControlAction(context: Context, action: String) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("widget_action", action)
            putExtra("widget_silent", true)
        }
        context.startActivity(intent)
    }

    private fun updateWidget(
        context: Context,
        mgr: AppWidgetManager,
        widgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_4x1)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val title = prefs.getString("widget_title", null)
            ?: context.getString(R.string.widget_default_title)
        val artist = prefs.getString("widget_artist", null)
            ?: context.getString(R.string.widget_default_subtitle)
        val isPlaying = prefs.getBoolean("widget_is_playing", false)
        val artworkPath = prefs.getString("widget_artwork_path", null)

        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_artist, artist)

        views.setImageViewResource(
            R.id.widget_play_pause,
            if (isPlaying) android.R.drawable.ic_media_pause
            else android.R.drawable.ic_media_play
        )

        val bitmap = loadArtwork(artworkPath)
        if (bitmap != null) {
            views.setImageViewBitmap(R.id.widget_artwork, bitmap)
        } else {
            views.setImageViewResource(
                R.id.widget_artwork,
                R.drawable.ic_music_fallback
            )
        }

        val openAppIntent = PendingIntent.getActivity(
            context, widgetId,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_artwork, openAppIntent)
        views.setOnClickPendingIntent(R.id.widget_info_container, openAppIntent)

        views.setOnClickPendingIntent(
            R.id.widget_prev,
            controlPendingIntent(context, ACTION_SKIP_PREV, widgetId)
        )
        views.setOnClickPendingIntent(
            R.id.widget_play_pause,
            controlPendingIntent(context, ACTION_PLAY_PAUSE, widgetId)
        )
        views.setOnClickPendingIntent(
            R.id.widget_next,
            controlPendingIntent(context, ACTION_SKIP_NEXT, widgetId)
        )

        mgr.updateAppWidget(widgetId, views)
    }

    private fun controlPendingIntent(
        context: Context,
        action: String,
        widgetId: Int
    ): PendingIntent {
        val intent = Intent(context, MelodyWidgetProvider::class.java).apply {
            this.action = action
            data = Uri.parse("melodyflow://widget/$widgetId/$action")
        }
        return PendingIntent.getBroadcast(
            context,
            widgetId * 10 + action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun loadArtwork(path: String?): Bitmap? {
        if (path.isNullOrEmpty()) return null
        return try {
            val file = File(path)
            if (!file.exists()) return null
            BitmapFactory.decodeFile(file.absolutePath)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to load artwork from $path: $e")
            null
        }
    }
}
