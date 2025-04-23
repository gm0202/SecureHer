package com.example.secureher

import android.content.Intent
import android.net.Uri
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.secureher.app/whatsapp"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openWhatsApp") {
                val phone: String? = call.argument("phone")
                val message: String? = call.argument("message")

                if (phone != null && message != null) {
                    openWhatsApp(phone, message)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGUMENTS", "Phone and message are required", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun openWhatsApp(phone: String, message: String) {
        try {
            // Format the phone number
            val formattedPhone = formatPhoneNumber(phone)
            
            // Create the WhatsApp URI
            val uri = Uri.parse("whatsapp://send?phone=$formattedPhone&text=${Uri.encode(message)}")
            
            // Create the intent
            val intent = Intent(Intent.ACTION_VIEW, uri)
            intent.setPackage("com.whatsapp")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            intent.addFlags(Intent.FLAG_ACTIVITY_NO_HISTORY)
            intent.addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)

            // Check if WhatsApp is installed and launch it
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
            } else {
                Toast.makeText(this, "WhatsApp is not installed.", Toast.LENGTH_SHORT).show()
            }
        } catch (e: Exception) {
            e.printStackTrace()
            Toast.makeText(this, "Error opening WhatsApp: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }

    private fun formatPhoneNumber(phone: String): String {
        var formattedPhone = phone.replace("[^0-9]".toRegex(), "")
        if (formattedPhone.startsWith("0")) {
            formattedPhone = formattedPhone.substring(1)
        }
        if (!formattedPhone.startsWith("91")) {
            formattedPhone = "91$formattedPhone"
        }
        return formattedPhone
    }
}
