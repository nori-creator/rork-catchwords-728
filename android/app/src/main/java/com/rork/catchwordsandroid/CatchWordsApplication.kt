package com.rork.catchwordsandroid

import android.app.Application
import coil3.ImageLoader
import coil3.PlatformContext
import coil3.SingletonImageLoader
import coil3.request.crossfade
import com.rork.catchwordsandroid.data.AppGraph

class CatchWordsApplication : Application(), SingletonImageLoader.Factory {
    override fun onCreate() {
        super.onCreate()
        AppGraph.init(this)
    }

    /** Pictures fade in (iOS StickerImage: easeOut 0.25 s) instead of popping. */
    override fun newImageLoader(context: PlatformContext): ImageLoader =
        ImageLoader.Builder(context).crossfade(250).build()
}
