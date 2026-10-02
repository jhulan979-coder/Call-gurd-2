package com.example.call_guard

import android.Manifest
import android.app.Activity
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.CallLog
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingLog: MethodChannel.Result? = null
    private var pendingRole: MethodChannel.Result? = null
    private var pendingNotif: MethodChannel.Result? = null
    private var pendingContacts: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "callguard/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasCallLogPermission" -> result.success(hasLogPerm() && (hasContactsPerm() || contactsAsked()))
                    "requestCallLogPermission" -> {
                        if (hasLogPerm() && (hasContactsPerm() || contactsAsked())) {
                            result.success(true)
                        } else {
                            pendingLog = result
                            requestPermissions(arrayOf(Manifest.permission.READ_CALL_LOG, Manifest.permission.READ_CONTACTS), 1001)
                        }
                    }
                    "getRecentCalls" -> result.success(readCalls())
                    "hasContactsPermission" -> result.success(hasContactsPerm())
                    "requestContactsPermission" -> {
                        if (hasContactsPerm()) {
                            result.success(true)
                        } else {
                            pendingContacts = result
                            requestPermissions(arrayOf(Manifest.permission.READ_CONTACTS), 1003)
                        }
                    }
                    "getContacts" -> result.success(readContacts())
                    "hasSmsPermission" -> result.success(false)
                    "requestSmsPermission" -> result.success(false)
                    "getSms" -> result.success(ArrayList<Map<String, Any?>>())
                    "hasSendSms" -> result.success(false)
                    "requestSendSms" -> result.success(false)
                    "setAutoSms" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val text = call.argument<String>("text") ?: ""
                        getSharedPreferences("cg_native", Context.MODE_PRIVATE).edit()
                            .putBoolean("auto_sms", enabled)
                            .putString("auto_sms_text", text)
                            .apply()
                        result.success(true)
                    }
                    "getAutoSms" -> {
                        val p = getSharedPreferences("cg_native", Context.MODE_PRIVATE)
                        result.success(mapOf(
                            "enabled" to p.getBoolean("auto_sms", false),
                            "text" to (p.getString("auto_sms_text", "") ?: "")
                        ))
                    }
                    "isScreeningActive" -> result.success(roleHeld())
                    "requestScreeningRole" -> {
                        if (Build.VERSION.SDK_INT >= 29) {
                            requestRole(result)
                        } else {
                            result.success(false)
                        }
                    }
                    "requestNotificationPermission" -> requestNotif(result)
                    else -> result.notImplemented()
                }
            }
    }private fun has(p: String): Boolean {
        return checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasLogPerm(): Boolean {
        return has(Manifest.permission.READ_CALL_LOG)
    }

    private fun hasContactsPerm(): Boolean {
        return has(Manifest.permission.READ_CONTACTS)
    }

    private fun contactsAsked(): Boolean {
        return getSharedPreferences("cg_native", Context.MODE_PRIVATE).getBoolean("contacts_asked", false)
    }

    private fun roleHeld(): Boolean {
        if (Build.VERSION.SDK_INT < 29) return false
        return roleHeldApi29()
    }

    @android.annotation.TargetApi(29)
    private fun roleHeldApi29(): Boolean {
        val rm = getSystemService(Context.ROLE_SERVICE) as RoleManager
        return rm.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING) && rm.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
    }

    @android.annotation.TargetApi(29)
    private fun requestRole(result: MethodChannel.Result) {
        val rm = getSystemService(Context.ROLE_SERVICE) as RoleManager
        if (!rm.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) {
            result.success(false)
            return
        }
        if (rm.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) {
            result.success(true)
            return
        }
        pendingRole = result
        startActivityForResult(rm.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING), 2001)
    }

    private fun requestNotif(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 || has("android.permission.POST_NOTIFICATIONS")) {
            result.success(true)
        } else {
            pendingNotif = result
            requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 1002)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1001) {
            getSharedPreferences("cg_native", Context.MODE_PRIVATE).edit().putBoolean("contacts_asked", true).apply()
            pendingLog?.success(hasLogPerm())
            pendingLog = null
        }
        if (requestCode == 1002) {
            val ok = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingNotif?.success(ok)
            pendingNotif = null
        }
        if (requestCode == 1003) {
            pendingContacts?.success(hasContactsPerm())
            pendingContacts = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 2001) {
            pendingRole?.success(resultCode == Activity.RESULT_OK || roleHeld())
            pendingRole = null
        }
    }

    private fun lookupName(number: String?): String? {
        if (number.isNullOrEmpty() || !hasContactsPerm()) return null
        try {
            val uri = Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(number))
            val c = contentResolver.query(uri, arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME), null, null, null)
            c?.use {
                if (it.moveToFirst()) return it.getString(0)
            }
        } catch (e: Exception) {
        }
        return null
    }

    private fun readContacts(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        if (!hasContactsPerm()) return out
        try {
            val cursor = contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER
                ),
                null, null,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC"
            )
            cursor?.use {
                while (it.moveToNext()) {
                    out.add(mapOf(
                        "name" to it.getString(0),
                        "number" to it.getString(1)
                    ))
                }
            }
        } catch (e: Exception) {
        }
        return out
    }

    private fun readCalls(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        if (!hasLogPerm()) return out
        val cursor = contentResolver.query(
            CallLog.Calls.CONTENT_URI,
            arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.CACHED_NAME, CallLog.Calls.DATE, CallLog.Calls.TYPE),
            null, null, CallLog.Calls.DATE + " DESC"
        )
        cursor?.use {
            var count = 0
            while (it.moveToNext() && count < 100) {
                val number = it.getString(0)
                val cached = it.getString(1)
                val name = if (!cached.isNullOrEmpty()) cached else lookupName(number)
                out.add(mapOf(
                    "number" to number,
                    "name" to name,
                    "date" to it.getLong(2),
                    "type" to it.getInt(3)
                ))
                count++
            }
        }
        return out
    }
}
