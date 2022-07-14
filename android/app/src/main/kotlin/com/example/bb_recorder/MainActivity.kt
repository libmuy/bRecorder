package com.example.bb_recorder

import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.IntentFilter
import android.media.MediaMetadataRetriever
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel


class MainActivity: FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
//        GeneratedPluginRegistrant.registerWith(this)

        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "libmuy.com/bb_recorder").setMethodCallHandler { call, result ->
            if (call.method == "getDuration") {
                val path:String = call.arguments as String;
//                val mmr = MediaMetadataRetriever()
//                mmr.setDataSource(path)
//                val durationStr = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
//                val millSecond = durationStr!!.toInt()
//                result.success(millSecond)
                result.success(101)
            } else {
//                result.notImplemented()
                result.success(102)
            }
        }
    }

}
