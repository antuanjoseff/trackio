package app.antuanjoseff.trackio

import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
	private val channelName = "trackio/file_open_intents"
	private var pendingGpxPath: String? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		pendingGpxPath = extractGpxPathFromIntent(intent)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"consumePendingGpxPath" -> {
						result.success(pendingGpxPath)
						pendingGpxPath = null
					}
					else -> result.notImplemented()
				}
			}
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)

		val extracted = extractGpxPathFromIntent(intent)
		if (!extracted.isNullOrEmpty()) {
			pendingGpxPath = extracted
		}
	}

	private fun extractGpxPathFromIntent(intent: Intent?): String? {
		if (intent == null) return null

		val uri = when (intent.action) {
			Intent.ACTION_VIEW -> intent.data
			Intent.ACTION_SEND -> intent.getParcelableExtra(Intent.EXTRA_STREAM)
			else -> null
		} ?: return null

		val copiedPath = copyUriToCache(uri)
		if (copiedPath != null && copiedPath.lowercase().endsWith(".gpx")) {
			return copiedPath
		}

		return null
	}

	private fun copyUriToCache(uri: Uri): String? {
		val fileName = resolveFileName(uri) ?: "imported_track.gpx"
		val cacheFile = File(cacheDir, fileName)

		return try {
			contentResolver.openInputStream(uri)?.use { input ->
				cacheFile.outputStream().use { output ->
					input.copyTo(output)
				}
			}
			cacheFile.absolutePath
		} catch (_: Exception) {
			null
		}
	}

	private fun resolveFileName(uri: Uri): String? {
		var fileName: String? = null

		if (uri.scheme == "content") {
			val cursor: Cursor? = contentResolver.query(uri, null, null, null, null)
			cursor?.use {
				if (it.moveToFirst()) {
					val nameIndex = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
					if (nameIndex >= 0) {
						fileName = it.getString(nameIndex)
					}
				}
			}
		}

		if (fileName.isNullOrBlank()) {
			fileName = uri.lastPathSegment?.substringAfterLast('/')
		}

		if (fileName.isNullOrBlank()) {
			return null
		}

		if (!fileName!!.contains('.')) {
			fileName = "$fileName.gpx"
		}

		return fileName
	}
}
