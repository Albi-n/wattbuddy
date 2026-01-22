# 🔧 ESP32 Current Sensor Troubleshooting Guide

## Problem: Current reads 0A even with loads connected

## Root Causes (in order of likelihood):

### 1. ❌ **Load Not in Series with Current Sensor** (MOST LIKELY)
**Issue**: Devices are plugged directly into wall outlet, NOT through the ACS712 sensor

**Solution**:
- Don't plug devices into the wall
- Instead, wire them through this circuit:
  ```
  AC Main → ACS712 IP+ (current in) → Relay → Device → AC Neutral
                ↓
           ACS712 OUT → ESP32 GPIO 34
  ```

### 2. ❌ **ACS712 Sensor Not Connected**
**Check these pins:**
- ACS712 GND → ESP32 GND
- ACS712 VCC (5V) → ESP32 5V
- ACS712 OUT → ESP32 GPIO 34 (ADC)

### 3. ❌ **Wrong Offset/Sensitivity Calibration**
**Current formula in code:**
```cpp
current_digital = (iV - 1.65) / 0.185;  // offset 1.65V, sensitivity 0.185V/A
```

**To test if this is wrong:**
1. Upload `esp32_energy_monitor_CALIBRATION.ino` (provided)
2. Open Serial Monitor (115200 baud)
3. You'll see raw ADC values like:
   ```
   🔍 rawI=2048 | iV=1.650V | I=0.000A || rawV=1823 | vV=1.478V | V=220.0V
   ```

**Interpreting output:**
- `iV ≈ 1.65V` when no current = Offset is correct ✅
- `iV ≈ 2.45V` when no current = Offset should be 2.45V, not 1.65V ❌
- When you draw 10A, `iV` should increase by 1.85V (10A × 0.185V/A)

### 4. ❌ **ACS712 Module Defective**
Test by:
1. Measure ACS712 OUT pin voltage with multimeter (no load)
   - Should be ~1.65V (at 220V nominal)
   - Or around 2.5V (some modules)
2. Connect high current load
   - Voltage should increase noticeably
   - If voltage doesn't change = module might be dead

### 5. ❌ **ESP32 ADC Pin Damaged**
Test by:
1. Pin 34 should read ~2048 raw (middle of 4095 range)
2. If always reading max (4095) or min (0) = pin damaged

## Quick Diagnostic Steps:

**Step 1: Upload calibration sketch**
```
File → Open → esp32_energy_monitor_CALIBRATION.ino
Upload to ESP32
```

**Step 2: Open Serial Monitor (115200 baud)**
```
Tools → Serial Monitor
```

**Step 3: Watch output**
```
Initial (no load):
  rawI=2048 | iV=1.650V | I=0.000A

With Iron (1500W @ 220V ≈ 6.8A):
  rawI=2700 | iV=2.200V | I=2.970A  ✅ Current should increase!
  OR
  rawI=2048 | iV=1.650V | I=0.000A  ❌ Current not changing = problem!
```

**Step 4: Report findings**
Send screenshot of serial output showing:
- Baseline values (no load)
- Values with iron box turned ON
- Values with iron box turned OFF

## Sensor Pin Check (with Multimeter):

```
ACS712 Pinout:
- Pin 1: GND (black wire to ESP32 GND)
- Pin 2: VCC (red wire to ESP32 5V)  
- Pin 3: OUT (yellow wire to ESP32 GPIO 34)
- Pin 4: Not used

With multimeter in DC voltage mode on OUT pin:
- No current: Should read 1.6-2.5V (depends on offset)
- With load: Should increase noticeably
```

## Common Issues & Fixes:

| Issue | Symptom | Fix |
|-------|---------|-----|
| Wrong offset | Always 0A | Upload CALIBRATION.ino, find actual mid-voltage, update offset |
| Loose wire | Sometimes 0A, sometimes works | Check all connections, resolder if needed |
| IC not powered | Always 0A | Check VCC wire has 5V with multimeter |
| ADC pin broken | Always reads 0 | Use different GPIO pin (GPIO 35, 32, 39) |
| Relay shorts current path | Inconsistent readings | Check relay isn't stuck in wrong position |

## Next Steps:

1. **Try the calibration sketch first** - This shows exactly what's wrong
2. **Share the serial output** - I can see the raw values and fix the offset
3. **If still not working** - Check hardware connections with multimeter

---

## Current Sensor Specifications (ACS712-30A):

- **Sensitivity**: 185 mV/A (0.185V per Ampere)
- **Mid-point voltage**: 2.5V (some modules use 1.65V)
- **Max current**: ±30A
- **Operating voltage**: 4.5-5.5V

Your code currently uses:
- **Offset**: 1.65V
- **Sensitivity**: 0.185V/A

If your module has different values, the offset needs adjustment!
