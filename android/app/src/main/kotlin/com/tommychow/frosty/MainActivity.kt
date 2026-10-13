package com.tommychow.frosty

import cl.puntito.simple_pip_mode.PipCallbackHelperActivityWrapper
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : PipCallbackHelperActivityWrapper() {
    private var textureManager: IvsTextureManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Full-screen IVS player (SurfaceView).
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "frosty/ivs-player",
            IvsPlayerViewFactory(messenger),
        )

        // Texture-backed IVS players for the smooth in-app mini player.
        textureManager = IvsTextureManager(this, flutterEngine.renderer, messenger)
    }
}
