#include <Wire.h>
#include "MAX30105.h" 
#include "heartRate.h" 

MAX30105 particleSensor;

// === НАСТРОЙКИ ===
byte ledBrightness = 0x1F; 
byte sampleAverage = 4;    
byte ledMode = 2;          
byte sampleRate = 100;     
int pulseWidth = 411;      
int adcRange = 4096;       

// === ПЕРЕМЕННЫЕ BPM И HRV ===
const byte RATE_SIZE = 4; 
byte rates[RATE_SIZE];
byte rateSpot = 0;
long lastBeat = 0; 
float beatsPerMinute;
int beatAvg = 0;

float beatIntervals[50]; 
int beatCountInWindow = 0;

// === ПЕРЕМЕННЫЕ DC и ФИЛЬТР ===
float irDC = 0;
float redDC = 0;
const float alpha = 0.01; 

// === ПАЙПЛАЙН ===
unsigned long fingerPressStartTime = 0; 
bool collectingData = false;            

// === АКУМУЛЯТОРЫ ДЛЯ PEARSON И STATS ===
double sumIR_AC = 0;
double sumRed_AC = 0;
double sumIR_AC_Sq = 0;
double sumRed_AC_Sq = 0;
double sumCrossProd = 0;

// Увеличенные лимиты для корректной работы с 18-битным АЦП MAX30105
float irAC_max = -9999999.0;
float irAC_min =  9999999.0;
float redAC_max = -9999999.0; 
float redAC_min =  9999999.0; 
float irDC_max_drift = -9999999.0;
float irDC_min_drift =  9999999.0;

long sampleCount = 0;
int clippingCount = 0;

bool saturationDetected = false;
unsigned long lastPrintTime = 0;

// === ФУНКЦИЯ СБРОСА СТАТИСТИКИ ===
void resetStats() {
  sumIR_AC = 0; sumRed_AC = 0;
  sumIR_AC_Sq = 0; sumRed_AC_Sq = 0;
  sumCrossProd = 0;
  
  irAC_max = -9999999.0; irAC_min =  9999999.0;
  redAC_max = -9999999.0; redAC_min =  9999999.0;
  irDC_max_drift = -9999999.0; irDC_min_drift =  9999999.0;
  
  sampleCount = 0;
  clippingCount = 0;
  saturationDetected = false;
  
  beatCountInWindow = 0;
  // Не сбрасываем beatAvg полностью, чтобы сохранить историю пульса
}

void setup() {
  Serial.begin(115200);
  Serial.println("System Start: Pro Analytics Mode (Data Collection Phase)");

  Wire.begin(21, 22);

  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("MAX30102 not found. Check wiring!");
    while (1);
  }

  particleSensor.setup(ledBrightness, sampleAverage, ledMode, sampleRate, pulseWidth, adcRange);
  particleSensor.setPulseAmplitudeGreen(0); 
  particleSensor.clearFIFO();
}

void loop() {
  particleSensor.check(); 

  // Объявляем переменные вне цикла while, чтобы они были доступны для Live-вывода
  long irRaw = 0;
  long redRaw = 0;

  while (particleSensor.available()) {
    irRaw = particleSensor.getFIFOIR();
    redRaw = particleSensor.getFIFORed();
    particleSensor.nextSample(); 

    // Проверка клиппинга
    bool isClipping = (irRaw > 260000 || redRaw > 260000);
    if (isClipping) saturationDetected = true;

    // === ЕСТЬ ЛИ ПАЛЕЦ? ===
    if (irRaw < 30000) {
      if (collectingData) {
        Serial.println("\n--- NO FINGER DETECTED. RESETTING ---");
        collectingData = false;
        fingerPressStartTime = 0;
        irDC = 0; redDC = 0;
        resetStats();
      }
    } else {
      
      // Первый старт
      if (fingerPressStartTime == 0) {
        fingerPressStartTime = millis();
        collectingData = true;
        irDC = irRaw; redDC = redRaw; 
        resetStats();
        Serial.println("Finger Detected! Stabilizing 20 seconds...");
      }

      // 1. Фильтр постоянной составляющей (DC)
      irDC = (1.0 - alpha) * irDC + alpha * irRaw;
      redDC = (1.0 - alpha) * redDC + alpha * redRaw;

      // 2. Выделение переменной составляющей (AC)
      float irAC = irRaw - irDC;
      float redAC = redRaw - redDC;

      // 3. Улучшенный алгоритм детекции ударов сердца
      long beatInput = (long)(irAC + 30000); 
      
      if (checkForBeat(beatInput) == true) {
        long delta = millis() - lastBeat;
        lastBeat = millis();
        beatsPerMinute = 60 / (delta / 1000.0);
        
        if (beatsPerMinute < 255 && beatsPerMinute > 20) {
          rates[rateSpot++] = (byte)beatsPerMinute;
          rateSpot %= RATE_SIZE;
          beatAvg = 0;
          for (byte x = 0 ; x < RATE_SIZE ; x++) beatAvg += rates[x];
          beatAvg /= RATE_SIZE;

          // Собираем интервалы для SDNN только во время чистого окна
          unsigned long elapsed = millis() - fingerPressStartTime;
          if (collectingData && elapsed > 20000 && elapsed < 25000) {
             if (beatCountInWindow < 50) { // Защита от переполнения массива
                beatIntervals[beatCountInWindow++] = delta;
             }
          }
        }
      }

      // === ОКНО СБОРА ДАННЫХ (с 20 по 25 секунду) ===
      unsigned long elapsed = millis() - fingerPressStartTime;

      if (collectingData && elapsed > 20000 && elapsed < 25000) {
        
        // Математика Пирсона (накапливаем суммы)
        sumIR_AC += irAC;
        sumRed_AC += redAC;
        sumIR_AC_Sq += (irAC * irAC);
        sumRed_AC_Sq += (redAC * redAC);
        sumCrossProd += (irAC * redAC);

        // Min/Max для амплитуды пульса
        if (irAC > irAC_max) irAC_max = irAC;
        if (irAC < irAC_min) irAC_min = irAC;
        
        if (redAC > redAC_max) redAC_max = redAC;
        if (redAC < redAC_min) redAC_min = redAC;

        // Дрейф базовой линии
        if (irDC > irDC_max_drift) irDC_max_drift = irDC;
        if (irDC < irDC_min_drift) irDC_min_drift = irDC;

        if (isClipping) clippingCount++;
        sampleCount++;
      }

      // === ФИНАЛЬНЫЙ РАСЧЕТ В 25 СЕКУНД ===
      if (collectingData && elapsed >= 25000) {
        
        if (sampleCount > 50) { // Защита от деления на ноль
          
          // --- 1. КОРРЕЛЯЦИЯ ПИРСОНА (Качество сигнала) ---
          double numerator = (sampleCount * sumCrossProd) - (sumIR_AC * sumRed_AC);
          
          // ЗАЩИТА ОТ NaN: Проверяем, что под корнем не образуется отрицательное число из-за погрешностей float
          double val_IR = (sampleCount * sumIR_AC_Sq) - (sumIR_AC * sumIR_AC);
          double val_Red = (sampleCount * sumRed_AC_Sq) - (sumRed_AC * sumRed_AC);
          if (val_IR < 0) val_IR = 0;
          if (val_Red < 0) val_Red = 0;
          
          double denominator = sqrt(val_IR * val_Red);
          float correlation = 0;
          if (denominator > 0) correlation = numerator / denominator;

          // --- 2. ФИЗИЧЕСКИЕ МАРКЕРЫ (Peak-to-Peak, PI, SpO2) ---
          float irAC_pp = irAC_max - irAC_min;
          float redAC_pp = redAC_max - redAC_min;
          
          // Считаем PI через Peak-to-Peak (ровно как в тренировочном датасете)
          float irPI = (irDC > 0) ? ((irAC_pp / irDC) * 1000.0) : 0; 
          float redPI = (redDC > 0) ? ((redAC_pp / redDC) * 1000.0) : 0;
          float ratio = (irPI > 0) ? (redPI / irPI) : 0;
          
          float spo2 = 110.0 - (25.0 * ratio);
          spo2 = constrain(spo2, 0, 100); 

          float drift_val = irDC_max_drift - irDC_min_drift;

          // --- 3. ВАРИАБЕЛЬНОСТЬ ПУЛЬСА (SDNN) ---
          float beat_std = 0;
          if (beatCountInWindow > 1) {
             float meanInterval = 0;
             for(int i=0; i<beatCountInWindow; i++) meanInterval += beatIntervals[i];
             meanInterval /= beatCountInWindow;
             
             float varSum = 0;
             for(int i=0; i<beatCountInWindow; i++) varSum += pow(beatIntervals[i] - meanInterval, 2);
             beat_std = sqrt(varSum / beatCountInWindow);
          }

          // --- 4. ОПТИЧЕСКОЕ ПОГЛОЩЕНИЕ (X1 и X2) ---
          // ЗАЩИТА: логарифм нуля или отрицательного числа выдаст ошибку
          float safe_irDC = (irDC > 1.0) ? irDC : 1.0;
          float safe_redDC = (redDC > 1.0) ? redDC : 1.0;
          
          float X1 = log10(safe_irDC); 
          float X2 = log10(safe_redDC / safe_irDC);


          // --- ВЫВОД ОТЧЕТА В ПОРТ ---
          Serial.println("\n\n========================================");
          Serial.println("           FINAL REPORT (25s Window)    ");
          Serial.println("========================================");
          
          Serial.print("Correlation (Pearson): "); Serial.println(correlation, 4);
          if (correlation < 0.70) Serial.println(">>> WARNING: POOR SIGNAL QUALITY (< 0.70) <<<");
          
          Serial.print("X1 (IR Absorbance):    "); Serial.println(X1, 4);
          Serial.print("X2 (Red/IR Ratio Log): "); Serial.println(X2, 4);
          Serial.print("Perfusion Index (PI):  "); Serial.println(irPI, 4);
          Serial.print("Ratio R:               "); Serial.println(ratio, 4);
          Serial.print("Beats in Window:       "); Serial.println(beatCountInWindow);
          Serial.print("Avg BPM:               "); Serial.println(beatAvg);
          Serial.print("SDNN (Var):            "); Serial.println(beat_std, 1);
          Serial.print("Est. SpO2:             "); Serial.print(spo2, 1); Serial.println("%");
          Serial.print("Drift (DC change):     "); Serial.println(drift_val, 0);
          Serial.println("----------------------------------------");
          
          // Вывод удобной строки для копирования в ваш txt / csv файл
          Serial.println("COPY THIS LINE TO YOUR CSV FILE:");
          Serial.print("data.txt,DATE,TIME,id 1 I,GLUCOSE_HERE,");
          Serial.print(X1, 4); Serial.print(",");
          Serial.print(X2, 4); Serial.print(",");
          Serial.print(irPI, 4); Serial.print(",");
          Serial.print(spo2, 1); Serial.print(",");
          Serial.print(beatAvg); Serial.print(",");
          Serial.print(ratio, 4); Serial.print(",");
          Serial.print(correlation, 4); Serial.print(",");
          Serial.print(irAC_pp, 0); Serial.print(",");
          Serial.print(drift_val, 0); Serial.print(",");
          Serial.print(beatCountInWindow); Serial.print(",");
          Serial.println(beat_std, 4);
          Serial.println("========================================\n");
          
        } else {
          Serial.println("ERROR: Not enough samples collected (Glare/Movement?)");
        }

        // === МЯГКИЙ РЕСТАРТ ===
        // Делаем паузу 1.5 секунды, чистим буфер сенсора и начинаем новый отсчет
        delay(1500); 
        particleSensor.clearFIFO(); 
        fingerPressStartTime = millis(); 
        resetStats();
      }
    } 
  }

  // Live вывод (монитор / плоттер) пока идет сбор данных
  if (collectingData && millis() - lastPrintTime > 500) {
     unsigned long t = millis() - fingerPressStartTime;
     Serial.print("Timer: "); 
     Serial.print(t/1000.0, 1);
     Serial.print("s | Phase: ");
     if (t < 20000) Serial.print("Stabilizing...  ");
     else Serial.print("COLLECTING DATA!");
     Serial.print(" | BPM: "); Serial.print(beatAvg);
     
     // Используем переменные, объявленные в начале loop()
     Serial.print(" | IR_AC: "); Serial.println((long)(irRaw - irDC)); 
     lastPrintTime = millis();
  }
}