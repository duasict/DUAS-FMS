package com.duas.fms

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installCrashLogger()
        super.onCreate(savedInstanceState)
    }

    private fun installCrashLogger() {
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val sw = StringWriter()
                throwable.printStackTrace(PrintWriter(sw))
                val ts = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
                val entry = buildString {
                    append("=== FMS Crash Report ===\n")
                    append("Time    : $ts\n")
                    append("Thread  : ${thread.name}\n")
                    append("Class   : ${throwable.javaClass.name}\n")
                    append("Message : ${throwable.message}\n")
                    append("Stack   :\n$sw\n\n")
                }
                val dir = getExternalFilesDir(null) ?: filesDir
                File(dir, "crash.log").appendText(entry)
            } catch (_: Exception) { /* never let the logger crash */ }
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }
}
