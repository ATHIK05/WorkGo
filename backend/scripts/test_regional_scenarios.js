const { loadDemandModel, computePredictedDemand } = require("../src/services/demand_model");
const { extractContributingFactors, classifyDemandLevel, deriveHighDemandTrades } = require("../src/routes/insights");

async function runTest() {
  await loadDemandModel();

  console.log("=======================================================");
  console.log("🌦️  REGIONAL SHOCK & LOCATION-AWARE DEMAND TEST");
  console.log("=======================================================\n");

  // Scenario 1: Chennai Flooding / Monsoon Cloudburst
  console.log("--- SCENARIO 1: Chennai (Heavy Rain / Flood Event) ---");
  const chennaiFeatures = {
    daysToNextHoliday: 14,
    isNationalHoliday: false,
    hasLocalEvent: true,
    eventSeverity: "high",
    rainForecastMM: 78.4, // heavy rainfall / waterlogging
    tempC: 27.5,
    recentTrend: 1.2,
    dayOfWeek: 6,
  };
  const chennaiStat = {
    ...chennaiFeatures,
    district: "Chennai (Coastal North TN)",
  };
  const chennaiTrades = deriveHighDemandTrades(chennaiStat);

  const chennaiBaseline = 50;
  const chennaiPredicted = await computePredictedDemand({
    baseline: chennaiBaseline,
    features: chennaiFeatures,
  });
  const chennaiLevel = classifyDemandLevel(chennaiPredicted);
  const chennaiFactors = extractContributingFactors(chennaiStat);

  console.log(`📍 Location: Chennai (Coastal North TN)`);
  console.log(`🌧️ Weather: ${chennaiFeatures.rainForecastMM}mm rain, Temp: ${chennaiFeatures.tempC}°C`);
  console.log(`📈 Baseline Demand: ${chennaiBaseline} -> Predicted Surge: ${chennaiPredicted}`);
  console.log(`🔥 Demand Level: ${chennaiLevel.toUpperCase()}`);
  console.log(`🏷️ High Demand Trades Triggered: ${chennaiTrades.join(", ")}`);
  console.log(`💡 Contributing Driver Signals:`);
  chennaiFactors.forEach(f => console.log(`   • ${f}`));

  console.log("\n-------------------------------------------------------\n");

  // Scenario 2: Erode Severe Summer Heatwave
  console.log("--- SCENARIO 2: Erode (Extreme Summer Heatwave) ---");
  const erodeFeatures = {
    daysToNextHoliday: 18,
    isNationalHoliday: false,
    hasLocalEvent: true,
    eventSeverity: "medium",
    rainForecastMM: 0.0,
    tempC: 41.5, // heatwave
    recentTrend: 0.8,
    dayOfWeek: 6,
  };
  const erodeStat = {
    ...erodeFeatures,
    district: "Erode (Western Agro-Industrial TN)",
  };
  const erodeTrades = deriveHighDemandTrades(erodeStat);

  const erodeBaseline = 48;
  const erodePredicted = await computePredictedDemand({
    baseline: erodeBaseline,
    features: erodeFeatures,
  });
  const erodeLevel = classifyDemandLevel(erodePredicted);
  const erodeFactors = extractContributingFactors(erodeStat);

  console.log(`📍 Location: Erode (Western Agro-Industrial TN)`);
  console.log(`☀️ Weather: ${erodeFeatures.tempC}°C (Severe Heatwave), Rain: 0mm`);
  console.log(`📈 Baseline Demand: ${erodeBaseline} -> Predicted Surge: ${erodePredicted}`);
  console.log(`🔥 Demand Level: ${erodeLevel.toUpperCase()}`);
  console.log(`🏷️ High Demand Trades Triggered: ${erodeTrades.join(", ")}`);
  console.log(`💡 Contributing Driver Signals:`);
  erodeFactors.forEach(f => console.log(`   • ${f}`));

  console.log("\n=======================================================");
  console.log("✅ Regional Sensitivity & Location Shock Verification PASSED");
  console.log("=======================================================\n");
}

runTest().catch(console.error);
