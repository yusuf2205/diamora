package uz.diamoraa.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * The home-screen widget for staff: today's deliveries, pick-ups and overdue work. The app writes the lines (in its
 * language) every time «Обзор» refreshes; a tap opens the app.
 */
class ManagerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.manager_widget).apply {
                setTextViewText(R.id.widget_title, widgetData.getString("w_title", null) ?: "💎 Diamoraa")
                setTextViewText(R.id.widget_line1, widgetData.getString("w_line1", null) ?: "Откройте Diamoraa")
                line(this, R.id.widget_line2, widgetData.getString("w_line2", null))
                line(this, R.id.widget_line3, widgetData.getString("w_line3", null))
                line(this, R.id.widget_updated, widgetData.getString("w_updated", null))
                setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun line(views: RemoteViews, viewId: Int, text: String?) {
        views.setTextViewText(viewId, text ?: "")
        views.setViewVisibility(viewId, if (text.isNullOrEmpty()) View.GONE else View.VISIBLE)
    }
}
