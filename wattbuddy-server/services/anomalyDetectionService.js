// Anomaly Detection Service for WattBuddy

const db = require('../config/database');

class AnomalyDetectionService {
  // Peak hours: 9-11 AM, 5-9 PM (high demand)
  static isPeakHour() {
    const hour = new Date().getHours();
    return (hour >= 9 && hour <= 11) || (hour >= 17 && hour <= 21);
  }

  // High-power appliances threshold: > 500W at peak hours
  static isHighPowerUsage(power) {
    return power > 500;
  }

  // Detect if user is using specific appliances
  static detectAppliance(power, current) {
    if (power > 1500) return 'Iron Box / Heater'; // ~1500-2000W
    if (power > 1000) return 'Microwave / Heavy Duty Device'; // ~1000W
    if (power > 500) return 'Motor / Compressor'; // ~500-1000W
    if (power > 200) return 'AC / Water Heater'; // ~200-500W
    if (power > 100) return 'Television / Refrigerator'; // ~100-200W
    return null;
  }

  // Check for anomalies
  static async checkAnomalies(userId, voltage, current, power) {
    try {
      const anomalies = [];
      const tips = [];
      const isPeak = this.isPeakHour();
      const hour = new Date().getHours();

      // 1. Voltage anomaly
      if (voltage < 180 || voltage > 240) {
        anomalies.push({
          type: 'voltage_anomaly',
          severity: 'warning',
          message: `⚡ Voltage out of range: ${voltage.toFixed(1)}V (expected 180-240V)`,
          tip: 'Unstable voltage detected. Use a voltage stabilizer.'
        });
      }

      // 2. Peak hour high usage
      if (isPeak && this.isHighPowerUsage(power)) {
        const appliance = this.detectAppliance(power, current);
        anomalies.push({
          type: 'peak_hour_usage',
          severity: 'info',
          message: `⏰ Peak hour high usage detected: ${power.toFixed(2)}W (${hour}:00)`,
          appliance: appliance,
          tip: `📌 Tip: Avoid using ${appliance} during peak hours (${isPeak ? 'NOW' : 'later'}). Shift usage to off-peak hours (12-4 PM or 10 PM-6 AM) to save 20-30% on bills.`
        });
      }

      // 3. Sustained high usage (overload risk)
      const recentReadings = await db.query(
        `SELECT power_consumption FROM energy_readings 
         WHERE user_id = $1 
         AND recorded_at > NOW() - INTERVAL '10 minutes'
         ORDER BY recorded_at DESC
         LIMIT 10`,
        [userId]
      );

      if (recentReadings.rows.length > 5) {
        const avgPower = recentReadings.rows.reduce((sum, r) => sum + r.power_consumption, 0) / recentReadings.rows.length;
        if (avgPower > 2000) {
          anomalies.push({
            type: 'overload_risk',
            severity: 'critical',
            message: `🔴 Sustained high usage: ${avgPower.toFixed(2)}W (Overload risk!)`,
            tip: '⚠️ URGENT: Reduce power consumption. You are approaching overload. Disconnect some devices.'
          });
        }
      }

      // 4. Unusual usage pattern (compared to daily average)
      const dailyAvg = await db.query(
        `SELECT AVG(power_consumption) as avg_power FROM energy_readings 
         WHERE user_id = $1 
         AND recorded_at > NOW() - INTERVAL '24 hours'`,
        [userId]
      );

      if (dailyAvg.rows[0]?.avg_power) {
        const deviation = (power - dailyAvg.rows[0].avg_power) / dailyAvg.rows[0].avg_power * 100;
        if (deviation > 150) {
          anomalies.push({
            type: 'unusual_pattern',
            severity: 'info',
            message: `📊 Usage 150% higher than daily average`,
            tip: 'Check if additional devices are running. This will increase your monthly bill.'
          });
        }
      }

      return {
        hasAnomalies: anomalies.length > 0,
        anomalies,
        tips: [...new Set(anomalies.map(a => a.tip))], // Unique tips
        isPeakHour: isPeak,
        currentHour: hour
      };
    } catch (error) {
      console.error('❌ Anomaly Detection Error:', error);
      return { hasAnomalies: false, anomalies: [], tips: [] };
    }
  }
}

module.exports = AnomalyDetectionService;
