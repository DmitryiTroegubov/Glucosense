package com.example.myapplication

import android.Manifest
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.rounded.Bluetooth
import androidx.compose.material.icons.rounded.BluetoothConnected
import androidx.compose.material.icons.rounded.BluetoothDisabled
import androidx.compose.material.icons.rounded.Fingerprint
import androidx.compose.material.icons.rounded.Science
import androidx.compose.material.icons.rounded.Terminal
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.app.ActivityCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.IOException
import java.io.InputStream
import java.util.*

// --- CONFIG ---
val TARGET_DEVICE_NAME = "GlucoSensor_ESP32" // Имя вашего ESP32 в Bluetooth
val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

// --- COLORS ---
val DarkBg = Color(0xFF0F172A)
val CardBg = Color(0xFF1E293B)
val AccentBlue = Color(0xFF38BDF8)
val AccentPurple = Color(0xFF818CF8)
val SuccessGreen = Color(0xFF34D399)
val WarningOrange = Color(0xFFFB923C)
val ErrorRed = Color(0xFFF87171)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Быстрый запрос прав (для прототипа)
        if (checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_SCAN), 1)
        }

        setContent {
            MaterialTheme(colorScheme = darkColorScheme(background = DarkBg)) {
                GlucoseApp(::connectToDevice, ::disconnectDevice)
            }
        }
    }

    private var socket: BluetoothSocket? = null

    private suspend fun connectToDevice(mac: String): InputStream? {
        return withContext(Dispatchers.IO) {
            try {
                val adapter = getSystemService(BluetoothManager::class.java).adapter
                // Если MAC пустой, ищем по имени (для удобства)
                val device = if (mac.isEmpty()) {
                    if (ActivityCompat.checkSelfPermission(this@MainActivity, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) return@withContext null
                    adapter.bondedDevices.find { it.name == TARGET_DEVICE_NAME } ?: return@withContext null
                } else {
                    adapter.getRemoteDevice(mac)
                }

                socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                socket?.connect()
                socket?.inputStream
            } catch (e: Exception) {
                e.printStackTrace()
                null
            }
        }
    }

    private fun disconnectDevice() {
        try { socket?.close() } catch (e: Exception) {}
    }
}

// --- DATA CLASSES ---
data class PipelineData(
    val pi: String = "--",
    val x1: String = "--",
    val x2: String = "--"
)

enum class SensorState {
    IDLE, CALIBRATING, MEASURING, NO_FINGER, RESULT_READY
}

// --- UI COMPOSABLE ---
@Composable
fun GlucoseApp(
    connectAction: suspend (String) -> InputStream?,
    disconnectAction: () -> Unit
) {
    var connectionState by remember { mutableStateOf(false) }
    var sensorState by remember { mutableStateOf(SensorState.IDLE) }
    var pipelineData by remember { mutableStateOf(PipelineData()) }

    // Calibration logic
    var calibrationTimeLeft by remember { mutableFloatStateOf(15.0f) }
    val maxCalibrationTime = 15.0f

    // Logs
    val logs = remember { mutableStateListOf<String>() }
    var showTerminal by remember { mutableStateOf(false) }

    // Connection Input
    var macInput by remember { mutableStateOf("") }
    var isConnecting by remember { mutableStateOf(false) }

    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    // --- PARSER LOGIC ---
    fun parseLine(line: String) {
        // 1. Detect NO FINGER
        if (line.contains("NO FINGER")) {
            sensorState = SensorState.NO_FINGER
            return
        }

        // 2. Detect Calibration
        if (line.contains("Calibration:")) {
            sensorState = SensorState.CALIBRATING
            try {
                // Извлекаем число перед "s left"
                val timeStr = line.substringAfter("Calibration:").substringBefore("s left").trim()
                val time = timeStr.toFloatOrNull() ?: 0f
                if (time < 1000) { // фильтр от глюка 4294967
                    calibrationTimeLeft = time
                }
            } catch (e: Exception) {}
            return
        }

        // 3. Detect Result Header
        if (line.contains("PIPELINE RESULT")) {
            sensorState = SensorState.MEASURING // Временное состояние перед парсингом значений
            return
        }

        // 4. Parse Values
        if (line.contains("Perfusion Index (PI):")) {
            val value = line.substringAfter(":").trim()
            pipelineData = pipelineData.copy(pi = value)
        }
        if (line.contains("FEATURE X1")) {
            val value = line.substringAfter(":").trim()
            pipelineData = pipelineData.copy(x1 = value)
        }
        if (line.contains("FEATURE X2")) {
            val value = line.substringAfter(":").trim()
            pipelineData = pipelineData.copy(x2 = value)
            sensorState = SensorState.RESULT_READY // Финал пайплайна
        }
    }

    // --- BLUETOOTH LISTENER ---
    fun startListening(stream: InputStream) {
        scope.launch(Dispatchers.IO) {
            val buffer = ByteArray(1024)
            var bytes: Int
            while (true) {
                try {
                    if (stream.available() > 0) {
                        bytes = stream.read(buffer)
                        val message = String(buffer, 0, bytes)
                        val lines = message.split("\r\n", "\n")

                        lines.forEach { line ->
                            if(line.isNotEmpty()) {
                                withContext(Dispatchers.Main) {
                                    logs.add(line)
                                    if (logs.size > 200) logs.removeAt(0)
                                    parseLine(line)
                                }
                            }
                        }
                    }
                } catch (e: IOException) {
                    withContext(Dispatchers.Main) {
                        connectionState = false
                        sensorState = SensorState.IDLE
                    }
                    break
                }
            }
        }
    }

    // --- LAYOUT ---
    Scaffold(
        containerColor = DarkBg,
        topBar = {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
                    .background(CardBg, RoundedCornerShape(16.dp))
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Text("GlucoSense AI", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                    Text(
                        if (connectionState) "Connected" else "Disconnected",
                        color = if (connectionState) SuccessGreen else Color.Gray,
                        fontSize = 12.sp
                    )
                }

                IconButton(
                    onClick = {
                        if (connectionState) {
                            disconnectAction()
                            connectionState = false
                        } else {
                            scope.launch {
                                isConnecting = true
                                val stream = connectAction(macInput)
                                if (stream != null) {
                                    connectionState = true
                                    startListening(stream)
                                }
                                isConnecting = false
                            }
                        }
                    },
                    modifier = Modifier
                        .size(48.dp)
                        .background(if (connectionState) ErrorRed.copy(alpha=0.2f) else AccentBlue.copy(alpha=0.2f), CircleShape)
                ) {
                    if (isConnecting) {
                        CircularProgressIndicator(modifier = Modifier.size(24.dp), color = AccentBlue)
                    } else {
                        Icon(
                            if (connectionState) Icons.Rounded.BluetoothConnected else Icons.Rounded.Bluetooth,
                            contentDescription = "BT",
                            tint = if (connectionState) ErrorRed else AccentBlue
                        )
                    }
                }
            }
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {

            // 1. MAIN VISUALIZATION AREA
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(220.dp)
                    .clip(RoundedCornerShape(24.dp))
                    .background(Brush.linearGradient(listOf(Color(0xFF2E3B55), Color(0xFF1E293B)))),
                contentAlignment = Alignment.Center
            ) {
                when (sensorState) {
                    SensorState.CALIBRATING -> {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            val progress = (maxCalibrationTime - calibrationTimeLeft) / maxCalibrationTime
                            Box(contentAlignment = Alignment.Center) {
                                CircularProgressIndicator(
                                    progress = { 1f }, // Back track
                                    modifier = Modifier.size(120.dp),
                                    color = Color.White.copy(alpha = 0.1f),
                                    strokeWidth = 8.dp,
                                )
                                CircularProgressIndicator(
                                    progress = { progress.coerceIn(0f, 1f) },
                                    modifier = Modifier.size(120.dp),
                                    color = AccentBlue,
                                    strokeWidth = 8.dp,
                                    strokeCap = androidx.compose.ui.graphics.StrokeCap.Round
                                )
                                Text(
                                    "${calibrationTimeLeft}s",
                                    color = Color.White,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 20.sp
                                )
                            }
                            Spacer(Modifier.height(16.dp))
                            Text("CALIBRATING...", color = AccentBlue, letterSpacing = 2.sp, fontSize = 12.sp)
                        }
                    }
                    SensorState.NO_FINGER -> {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(Icons.Rounded.Warning, null, tint = WarningOrange, modifier = Modifier.size(64.dp))
                            Spacer(Modifier.height(16.dp))
                            Text("NO FINGER DETECTED", color = WarningOrange, fontWeight = FontWeight.Bold)
                            Text("Place finger to start", color = Color.Gray, fontSize = 12.sp)
                        }
                    }
                    SensorState.RESULT_READY, SensorState.MEASURING -> {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(Icons.Rounded.Science, null, tint = SuccessGreen, modifier = Modifier.size(64.dp))
                            Spacer(Modifier.height(8.dp))
                            Text("DATA ACQUIRED", color = SuccessGreen, fontWeight = FontWeight.Bold)
                        }
                    }
                    else -> {
                        Text("WAITING FOR DEVICE...", color = Color.Gray)
                    }
                }
            }

            Spacer(Modifier.height(24.dp))

            // 2. DATA CARDS GRID
            Text("PIPELINE OUTPUT", color = Color.Gray, fontSize = 12.sp, modifier = Modifier.align(Alignment.Start))
            Spacer(Modifier.height(8.dp))

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                DataCard(
                    title = "Log IR",
                    value = pipelineData.x1,
                    icon = Icons.Rounded.Fingerprint,
                    color = AccentPurple,
                    modifier = Modifier.weight(1f)
                )
                Spacer(Modifier.width(8.dp))
                DataCard(
                    title = "Log Ratio",
                    value = pipelineData.x2,
                    icon = Icons.Rounded.Science,
                    color = AccentBlue,
                    modifier = Modifier.weight(1f)
                )
            }
            Spacer(Modifier.height(8.dp))
            DataCard(
                title = "Perfusion Index (PI)",
                value = pipelineData.pi,
                icon = Icons.Rounded.BluetoothDisabled, // Просто иконка волны/сигнала
                color = if(pipelineData.pi.contains(".")) SuccessGreen else Color.Gray,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(Modifier.weight(1f))

            // 3. TERMINAL TOGGLE
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { showTerminal = !showTerminal }
                    .padding(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(Icons.Rounded.Terminal, null, tint = Color.Gray)
                Spacer(Modifier.width(8.dp))
                Text(if(showTerminal) "Hide Serial Monitor" else "Show Serial Monitor", color = Color.Gray, fontSize = 14.sp)
            }

            AnimatedVisibility(visible = showTerminal) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(200.dp)
                        .background(Color.Black, RoundedCornerShape(8.dp))
                        .border(1.dp, Color.DarkGray, RoundedCornerShape(8.dp))
                        .padding(8.dp)
                ) {
                    LazyColumn(state = listState) {
                        items(logs) { log ->
                            Text(log, color = SuccessGreen, fontSize = 10.sp, fontFamily = FontFamily.Monospace)
                        }
                    }
                    LaunchedEffect(logs.size) {
                        if (logs.isNotEmpty()) listState.animateScrollToItem(logs.lastIndex)
                    }
                }
            }
        }
    }
}

@Composable
fun DataCard(
    title: String,
    value: String,
    icon: ImageVector,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .background(CardBg, RoundedCornerShape(16.dp))
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, null, tint = color.copy(alpha = 0.7f), modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(8.dp))
            Text(title, color = Color.Gray, fontSize = 12.sp)
        }
        Spacer(Modifier.height(8.dp))
        Text(
            value,
            color = Color.White,
            fontWeight = FontWeight.Bold,
            fontSize = 20.sp,
            fontFamily = FontFamily.Monospace
        )
    }
}