# Quick Reference: ESP32 Calibration

## Web Interface URLs

| URL | Purpose |
|-----|---------|
| `http://ESP32_IP/` | Home page with current settings |
| `http://ESP32_IP/data` | Trigger single sensor read (appears in Serial) |
| `http://ESP32_IP/calibrate` | View calibration instructions |
| `http://ESP32_IP/calibrate-test?power=1500` | **Start calibration with 1500W appliance** |

Replace `ESP32_IP` with your ESP32's IP address (printed in Serial Monitor at startup)

---

## Calibration Steps (TL;DR)

1. **Upload firmware** with `rawADCMode = true`
2. **Wait 30 seconds** for diagnostics to finish
3. **Visit URL:** `http://[IP]/calibrate-test?power=1500` (with your appliance power)
4. **Plug in appliance immediately** - keep it running 30 seconds
5. **Check Serial Monitor** for calculated `voltage_scale` value
6. **Update code:** Change `float voltage_scale = 1.0;` to new value
7. **Re-upload firmware**
8. **Done!** Readings should now be accurate

---

## Serial Monitor Output Interpretation

### Diagnostics (First 30 seconds)
```
[1] I_ADC: 2048 (1651.4mV) | V_ADC: 1823 (1461.2mV) | RANGES[I: 2045-2051 | V: 1822-1824]
```
✅ Good: ADC around 2048, RANGES narrow (±5-10)
❌ Bad: ADC below 1500 or above 2500, RANGES huge (±100+)

### Normal Operation (After calibration)
```
Voltage: 220.50V | Current: 3.750A | Power: 826.88W | PF: 1.00 | Energy: 0.0002kWh
```
✅ Good: Voltage 200-240V, Power matches appliance rating
❌ Bad: Voltage 0.5-5V or 50000V, Power millions of watts

### Calibration Results
```
📊 RESULTS:
  Known Power: 1500W
  Measured Power: 800W
  Calibration Factor: 1.8750

✏️  UPDATE YOUR CODE:
  Change: float voltage_scale = 1.00;
  To:     float voltage_scale = 1.88;
```
👈 **Copy this value and update code!**

---

## Recommended Appliances (Ranked)

| Rank | Appliance | Power | Notes |
|------|-----------|-------|-------|
| 🥇 | Electric kettle | 1500W | Best - clear results, stable |
| 🥈 | Space heater | 750-1500W | Good - stable power draw |
| 🥉 | Incandescent 60W bulb | 60W | Reliable - constant power |
| 4️⃣ | Phone charger | 5-10W | Hard to measure error - low power |
| ❌ | Fan (variable speed) | 50-100W | Variable - inconsistent results |
| ❌ | Microwave | 500-1000W | Pulses - inconsistent results |

---

## Common Issues & Fixes

### "Measured power too low (0W)"
→ Plug in appliance BEFORE clicking calibration link!

### Voltage still wrong after calibration
→ Check you copied exact value from Serial Monitor to code
→ Make sure you re-uploaded after editing code

### Current sensor shows huge swings in diagnostics
→ Normal if AC present. Algorithm handles this.
→ If persistent even disconnected from AC, check power supply

### Calibration results differ each time
→ Normal variation for low-power appliances
→ Use higher-power appliance (1500W+) for consistency

---

## Code Changes Needed

### Enable Calibration Mode
Just visit the web URL - no code change needed!

### Disable Diagnostics (After calibration complete)
```cpp
// Line in code:
bool rawADCMode = false;  // Change from true to false

// Then re-upload
```

### Update voltage_scale (Required!)
```cpp
// Line in code:
float voltage_scale = 1.0;  // Change to value from Serial Monitor

// Example from calibration:
float voltage_scale = 1.88;  // Then re-upload
```

---

## Files Updated in This Release

- ✅ `esp32_corrected_FINAL.ino` - Added calibration functions, web endpoints
- ✅ `CALIBRATION_GUIDE.md` - Full calibration documentation
- ✅ `QUICK_REFERENCE.md` - This file

---

## Next: Flutter App Integration

Once calibration complete and readings accurate:
→ See `FLUTTER_ESP32_INTEGRATION.md` for app integration steps

