package com.example.milogia
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.content.Intent
import android.content.Context
import android.app.KeyguardManager
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.milogia.app/settings"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Mantener la pantalla encendida y mostrar sobre el lockscreen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openMiuiPermissionSettings" -> {
                    try {
                        val intent = Intent("miui.intent.action.APP_PERM_EDITOR")
                        intent.setClassName("com.miui.securitycenter", "com.miui.permcenter.permissions.PermissionsEditorActivity")
                        intent.putExtra("extra_pkgname", packageName)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            intent.data = Uri.parse("package:$packageName")
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("UNAVAILABLE", "No se pudo abrir la configuración", null)
                        }
                    }
                }
                "checkMiuiPermissions" -> {
                    result.success(checkMiuiPermissionStatus())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkMiuiPermissionStatus(): Boolean {
        val ops = getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
        try {
            val method = android.app.AppOpsManager::class.java.getMethod(
                "checkOpNoThrow",
                Int::class.javaPrimitiveType,
                Int::class.javaPrimitiveType,
                String::class.java
            )
            // 10020: OP_SHOW_WHEN_LOCKED (MIUI específico)
            // 10021: OP_BACKGROUND_START_ACTIVITY (MIUI específico)
            val resultLocked = method.invoke(ops, 10020, android.os.Process.myUid(), packageName) as Int
            val resultBackground = method.invoke(ops, 10021, android.os.Process.myUid(), packageName) as Int
            
            return resultLocked == android.app.AppOpsManager.MODE_ALLOWED && 
                   resultBackground == android.app.AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            // Si hay error (no es MIUI o cambió la API), retornamos true por seguridad para no molestar
            return true 
        }
    }
}
