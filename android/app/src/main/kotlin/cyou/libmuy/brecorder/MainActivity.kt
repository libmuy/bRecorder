package cyou.libmuy.brecorder

import android.os.Build
import android.os.Bundle
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity


class MainActivity: FlutterActivity() {
    private var platformChannelsHandler: PlatformChannelsHandler? = null

    @RequiresApi(Build.VERSION_CODES.M)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        platformChannelsHandler = PlatformChannelsHandler(this, flutterEngine)
        platformChannelsHandler!!.initialize()
    }

}
