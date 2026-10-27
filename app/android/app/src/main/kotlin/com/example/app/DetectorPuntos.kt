package com.example.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Callable
import java.util.concurrent.Executors

/**
 * Detecta manos, pose y rostro con MediaPipe Tasks (los mismos modelos y la
 * misma configuración que `Extractor` en `ml/signcast/puntos_clave.py`) y se
 * los manda a Dart.
 *
 * Canales:
 *  - MethodChannel `signcast/puntos`: `iniciar`, `procesar`, `liberar`.
 *  - EventChannel `signcast/puntos/cuadros`: un `FloatArray` por imagen con
 *    mano izquierda (21x3), mano derecha (21x3), pose (33x3) y rostro (478x3).
 *    Lo no detectado va como NaN.
 *
 * Los modelos `hand_landmarker.task`, `pose_landmarker_lite.task` y
 * `face_landmarker.task` van en `android/app/src/main/assets/`
 * (ver `app/tool/copiar_modelos_mediapipe.ps1`).
 */
class DetectorPuntos(
    private val context: Context,
    mensajero: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val principal = Handler(Looper.getMainLooper())
    private var hilo: HandlerThread? = null
    private var trabajo: Handler? = null
    private var sink: EventChannel.EventSink? = null

    private var manos: HandLandmarker? = null
    private var pose: PoseLandmarker? = null
    private var cara: FaceLandmarker? = null
    private var ultimoTs = -1L

    // Los tres modelos corren a la vez, cada uno en su propio hilo. Cada modelo
    // se crea y se usa siempre en el mismo hilo (lo exige el delegado de GPU).
    private val ejManos = Executors.newSingleThreadExecutor()
    private val ejPose = Executors.newSingleThreadExecutor()
    private val ejCara = Executors.newSingleThreadExecutor()

    @Volatile private var msManos = 0L
    @Volatile private var msPose = 0L
    @Volatile private var msCara = 0L

    init {
        MethodChannel(mensajero, "signcast/puntos").setMethodCallHandler(this)
        EventChannel(mensajero, "signcast/puntos/cuadros").setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "iniciar" -> {
                val h = asegurarHilo()
                h.post {
                    try {
                        crearDetectores()
                        principal.post { result.success(null) }
                    } catch (e: Exception) {
                        Log.e(TAG, "No se pudieron crear los detectores", e)
                        principal.post { result.error("INICIO", e.message, null) }
                    }
                }
            }
            "procesar" -> procesar(call, result)
            "liberar" -> {
                liberar()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(argumentos: Any?, eventos: EventChannel.EventSink?) {
        sink = eventos
    }

    override fun onCancel(argumentos: Any?) {
        sink = null
    }

    private fun asegurarHilo(): Handler {
        trabajo?.let { return it }
        val t = HandlerThread("signcast-puntos").also { it.start() }
        hilo = t
        return Handler(t.looper).also { trabajo = it }
    }

    /** Misma configuración que `Extractor(modo="video")` de Python. */
    private fun crearDetectores() {
        if (manos != null) return
        try {
            crearDetectores(USAR_GPU)
            Log.i(TAG, "Delegado de MediaPipe: ${if (USAR_GPU) "GPU" else "CPU"}")
        } catch (e: Exception) {
            Log.w(TAG, "La GPU no está disponible, se usa la CPU", e)
            cerrarDetectores()
            crearDetectores(false)
            Log.i(TAG, "Delegado de MediaPipe: CPU")
        }
    }

    private fun cerrarDetectores() {
        ejManos.submit { manos?.close(); manos = null }.get()
        ejPose.submit { pose?.close(); pose = null }.get()
        ejCara.submit { cara?.close(); cara = null }.get()
    }

    private fun crearDetectores(gpu: Boolean) {
        fun base(archivo: String) = BaseOptions.builder()
            .setModelAssetPath(archivo)
            .apply { if (gpu) setDelegate(Delegate.GPU) }
            .build()

        ejManos.submit { manos = HandLandmarker.createFromOptions(
            context,
            HandLandmarker.HandLandmarkerOptions.builder()
                .setBaseOptions(base("hand_landmarker.task"))
                .setRunningMode(RunningMode.VIDEO)
                .setNumHands(2)
                .setMinHandDetectionConfidence(0.5f)
                .setMinHandPresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .build(),
        ) }.get()
        ejPose.submit { pose = PoseLandmarker.createFromOptions(
            context,
            PoseLandmarker.PoseLandmarkerOptions.builder()
                .setBaseOptions(base("pose_landmarker_lite.task"))
                .setRunningMode(RunningMode.VIDEO)
                .setNumPoses(1)
                .build(),
        ) }.get()
        ejCara.submit { cara = FaceLandmarker.createFromOptions(
            context,
            FaceLandmarker.FaceLandmarkerOptions.builder()
                .setBaseOptions(base("face_landmarker.task"))
                .setRunningMode(RunningMode.VIDEO)
                .setNumFaces(1)
                .build(),
        ) }.get()
    }

    private fun procesar(call: MethodCall, result: MethodChannel.Result) {
        val h = trabajo
        if (h == null || manos == null) {
            result.error("SIN_INICIAR", "Llama a iniciar antes de procesar.", null)
            return
        }
        val ancho = call.argument<Int>("ancho")!!
        val alto = call.argument<Int>("alto")!!
        val rotacion = call.argument<Int>("rotacion")!!
        val y = call.argument<ByteArray>("y")!!
        val u = call.argument<ByteArray>("u")!!
        val v = call.argument<ByteArray>("v")!!
        val filaY = call.argument<Int>("filaY")!!
        val filaUV = call.argument<Int>("filaUV")!!
        val pixelUV = call.argument<Int>("pixelUV")!!

        h.post {
            try {
                val t0 = SystemClock.elapsedRealtime()
                val bitmap = yuvABitmap(y, u, v, ancho, alto, filaY, filaUV, pixelUV)
                val derecho = girar(bitmap, rotacion)
                val msConversion = SystemClock.elapsedRealtime() - t0
                val cuadro = detectar(derecho)
                val tiempos = listOf(msConversion, msManos, msPose, msCara)
                principal.post {
                    sink?.success(cuadro)
                    result.success(tiempos)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error al procesar la imagen", e)
                principal.post { result.error("PROCESAR", e.message, null) }
            }
        }
    }

    /**
     * Devuelve el cuadro aplanado: mano izq, mano der, pose y rostro (NaN si
     * falta). La imagen va derecha y SIN espejo, igual que la webcam en Python;
     * la etiqueta Left/Right se usa tal cual la da MediaPipe.
     */
    private fun detectar(bitmap: Bitmap): FloatArray {
        val salida = FloatArray(LONGITUD) { Float.NaN }
        val imagen = BitmapImageBuilder(bitmap).build()
        val ts = maxOf(SystemClock.uptimeMillis(), ultimoTs + 1) // tiempos estrictamente crecientes
        ultimoTs = ts

        val fM = ejManos.submit(Callable<HandLandmarkerResult> {
            val t = SystemClock.elapsedRealtime()
            manos!!.detectForVideo(imagen, ts).also { msManos = SystemClock.elapsedRealtime() - t }
        })
        val fP = ejPose.submit(Callable<PoseLandmarkerResult> {
            val t = SystemClock.elapsedRealtime()
            pose!!.detectForVideo(imagen, ts).also { msPose = SystemClock.elapsedRealtime() - t }
        })
        val fC = ejCara.submit(Callable<FaceLandmarkerResult> {
            val t = SystemClock.elapsedRealtime()
            cara!!.detectForVideo(imagen, ts).also { msCara = SystemClock.elapsedRealtime() - t }
        })
        val rm = fM.get()
        val rp = fP.get()
        val rc = fC.get()
        var izqLibre = true
        var derLibre = true
        for ((i, puntos) in rm.landmarks().withIndex()) {
            val etiqueta = rm.handedness()[i][0].categoryName()
            // Misma regla que Python: "Left" -> izquierda si está libre; si no,
            // derecha si está libre; si no, sobrescribe la izquierda.
            val destino = when {
                etiqueta == "Left" && izqLibre -> 0
                derLibre -> 1
                else -> 0
            }
            if (destino == 0) izqLibre = false else derLibre = false
            copiar(puntos, salida, destino * PUNTOS_MANO * 3, PUNTOS_MANO)
        }

        rp.landmarks().firstOrNull()?.let { copiar(it, salida, OFFSET_POSE, PUNTOS_POSE) }

        rc.faceLandmarks().firstOrNull()?.let { copiar(it, salida, OFFSET_CARA, PUNTOS_CARA) }
        return salida
    }

    private fun copiar(
        puntos: List<com.google.mediapipe.tasks.components.containers.NormalizedLandmark>,
        destino: FloatArray,
        inicio: Int,
        maximo: Int,
    ) {
        for (i in 0 until minOf(puntos.size, maximo)) {
            destino[inicio + i * 3] = puntos[i].x()
            destino[inicio + i * 3 + 1] = puntos[i].y()
            destino[inicio + i * 3 + 2] = puntos[i].z()
        }
    }

    /** YUV_420_888 (los tres planos de `CameraImage`) a un bitmap ARGB. */
    private fun yuvABitmap(
        y: ByteArray, u: ByteArray, v: ByteArray,
        ancho: Int, alto: Int, filaY: Int, filaUV: Int, pixelUV: Int,
    ): Bitmap {
        val pixeles = IntArray(ancho * alto)
        for (fila in 0 until alto) {
            for (col in 0 until ancho) {
                val yy = y[fila * filaY + col].toInt() and 0xFF
                val iuv = (fila shr 1) * filaUV + (col shr 1) * pixelUV
                val uu = (u[iuv].toInt() and 0xFF) - 128
                val vv = (v[iuv].toInt() and 0xFF) - 128
                val r = (yy + 1.370705f * vv).toInt().coerceIn(0, 255)
                val g = (yy - 0.337633f * uu - 0.698001f * vv).toInt().coerceIn(0, 255)
                val b = (yy + 1.732446f * uu).toInt().coerceIn(0, 255)
                pixeles[fila * ancho + col] = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
            }
        }
        return Bitmap.createBitmap(pixeles, ancho, alto, Bitmap.Config.ARGB_8888)
    }

    private fun girar(bitmap: Bitmap, grados: Int): Bitmap {
        if (grados % 360 == 0) return bitmap
        val m = Matrix().apply { postRotate(grados.toFloat()) }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, m, true)
    }

    fun liberar() {
        val h = trabajo
        val cierre = Runnable {
            cerrarDetectores()
            hilo?.quitSafely()
        }
        if (h != null) h.post(cierre) else cierre.run()
        trabajo = null
        hilo = null
    }

    private companion object {
        const val TAG = "DetectorPuntos"

        /** Probar la GPU del teléfono; si falla se usa la CPU. */
        const val USAR_GPU = false
        const val PUNTOS_MANO = 21
        const val PUNTOS_POSE = 33
        const val PUNTOS_CARA = 478
        const val OFFSET_POSE = 2 * PUNTOS_MANO * 3
        const val OFFSET_CARA = OFFSET_POSE + PUNTOS_POSE * 3
        const val LONGITUD = OFFSET_CARA + PUNTOS_CARA * 3   // 1659, igual que CuadroPuntos.longitudPlano
    }
}
