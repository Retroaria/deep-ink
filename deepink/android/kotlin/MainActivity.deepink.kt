    // ---- Deep Ink: sleep screen over the lock screen --------------------------------
    // Called from Lua (plugins/deepink.koplugin) through JNI.

    @Suppress("DEPRECATION")
    fun deepInkShowWhenLocked(enable: Int) {
        runOnUiThread {
            val on = enable != 0
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(on)
            } else if (on) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
            }
        }
    }

    @Suppress("DEPRECATION")
    fun deepInkDismissKeyguard() {
        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val km = getSystemService(Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
                km.requestDismissKeyguard(this, null)
            } else {
                window.addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)
            }
        }
    }

    fun deepInkIsLocked(): Int {
        val km = getSystemService(Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
        return if (km.isKeyguardLocked) 1 else 0
    }

    @Suppress("DEPRECATION")
    fun deepInkIsScreenOn(): Int {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val on = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH) pm.isInteractive else pm.isScreenOn
        return if (on) 1 else 0
    }
    // ---- end Deep Ink ----------------------------------------------------------------

