package cyou.libmuy.brecorder

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity


class MainActivity: FlutterActivity() {
    private var methodCallHandler: MethodCallHandler? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        methodCallHandler = MethodCallHandler(this, flutterEngine)
        methodCallHandler!!.handleMethodCalls()
    }

}
