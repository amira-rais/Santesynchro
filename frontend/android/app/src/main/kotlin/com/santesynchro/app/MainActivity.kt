package com.santesynchro.app

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // Intercepte les RemoteException de Health Connect au niveau Android
        // avant qu'elles ne tuent le processus (non catchable depuis Dart)
        installHealthConnectSafeHandler()
        super.onCreate(savedInstanceState)
    }

    private fun installHealthConnectSafeHandler() {
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()

        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            val message = throwable.message ?: ""
            val cause = throwable.cause?.message ?: ""
            val stackTrace = throwable.stackTrace.joinToString("\n") { it.toString() }

            // Filtre spécifique aux erreurs de liaison Health Connect
            val isHealthConnectError =
                message.contains("Binding", ignoreCase = true) ||
                message.contains("RemoteException", ignoreCase = true) ||
                cause.contains("Binding", ignoreCase = true)  ||
                stackTrace.contains("HealthConnectClient", ignoreCase = true) ||
                stackTrace.contains("healthdata", ignoreCase = true) ||
                stackTrace.contains("cachet.plugins.health", ignoreCase = true)

            if (isHealthConnectError) {
                // Log sans crasher — Health Connect n'est pas disponible sur cet appareil
                Log.w("SanteSynchro", "Health Connect indisponible (supprimé): $message")
            } else {
                // Tous les autres crashs sont délégués au handler par défaut
                defaultHandler?.uncaughtException(thread, throwable)
            }
        }
    }
}
