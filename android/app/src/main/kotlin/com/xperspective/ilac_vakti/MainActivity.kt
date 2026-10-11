package com.xperspective.ilac_vakti

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private fun recordsDirectory(): File {
        val base = noBackupFilesDir.canonicalFile
        val directory = File(base, "private-records")
        check(directory.canonicalFile == directory.absoluteFile)
        check(directory.isDirectory || directory.mkdir())
        return directory
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ilac_vakti/private_records")
            .setMethodCallHandler { call, result ->
                if (call.method != "getDirectory" && call.method != "protectFiles") {
                    result.notImplemented()
                } else if (call.arguments != null) {
                    result.error("invalid_arguments", "No arguments accepted", null)
                } else {
                    try {
                        val directory = recordsDirectory()
                        for (name in listOf("records-0.ivault", "records-1.ivault")) {
                            val file = File(directory, name)
                            check(file.canonicalFile == file.absoluteFile)
                            check(!file.exists() || file.isFile)
                        }
                        result.success(if (call.method == "getDirectory") directory.path else true)
                    } catch (_: Exception) {
                        result.error("protection_failed", "Private storage unavailable", null)
                    }
                }
            }
    }
}
