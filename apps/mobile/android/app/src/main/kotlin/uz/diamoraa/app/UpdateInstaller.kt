package uz.diamoraa.app

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import java.io.File

/**
 * Installs a downloaded update through a PackageInstaller session (not an ACTION_VIEW intent), so Diamoraa itself
 * becomes the "installer of record". From then on Android 12+ lets it update itself WITHOUT asking
 * (USER_ACTION_NOT_REQUIRED) - the app is updated quietly while the person is in another app.
 *  - silent = true: if Android still wants a confirmation (older Android, first update after a browser install,
 *    a vendor that forbids it), nothing pops up - the «Установить» strip stays in the app instead.
 *  - silent = false: the person tapped «Установить» - the system confirmation is shown when needed.
 */
object UpdateInstaller {
    const val EXTRA_SILENT = "uz.diamoraa.app.update.SILENT"

    fun install(context: Context, apk: File, silent: Boolean) {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(context.packageName)
            setSize(apk.length())
            if (Build.VERSION.SDK_INT >= 31) setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        }
        val id = installer.createSession(params)
        installer.openSession(id).use { session ->
            session.openWrite("diamoraa.apk", 0, apk.length()).use { out ->
                apk.inputStream().use { it.copyTo(out, 1 shl 16) }
                session.fsync(out)
            }
            val intent = Intent(context, UpdateResultReceiver::class.java).putExtra(EXTRA_SILENT, silent)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
            session.commit(PendingIntent.getBroadcast(context, id, intent, flags).intentSender)
        }
    }
}

class UpdateResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        if (status != PackageInstaller.STATUS_PENDING_USER_ACTION) return // success restarts the app's process; failure: the strip stays
        val sessionId = intent.getIntExtra(PackageInstaller.EXTRA_SESSION_ID, -1)
        if (intent.getBooleanExtra(UpdateInstaller.EXTRA_SILENT, false)) {
            // quiet attempt, but Android wants a confirmation: never pop a dialog over another app
            if (sessionId >= 0) runCatching { context.packageManager.packageInstaller.abandonSession(sessionId) }
            return
        }
        @Suppress("DEPRECATION")
        val confirm: Intent? = if (Build.VERSION.SDK_INT >= 33) intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java) else intent.getParcelableExtra(Intent.EXTRA_INTENT)
        confirm?.let { context.startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
    }
}
