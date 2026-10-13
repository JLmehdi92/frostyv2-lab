package com.tommychow.frosty

import cl.puntito.simple_pip_mode.PipCallbackHelperActivityWrapper
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : PipCallbackHelperActivityWrapper() {
    private var textureManager: IvsTextureManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Texture-backed IVS players (channel screen, mini player and PiP).
        textureManager = IvsTextureManager(this, flutterEngine.renderer, messenger)
    }
}
