import Foundation

enum GasCalibration {

    /// Converts the MQ3 sensor's Rs/Ro ratio into a gas concentration
    /// in mg/L, which is then used directly as ppm (1 mg/L = 1 ppm
    /// per DFRobot's breathalyzer calibration reference).
    ///
    /// Formula: mg/L = 0.189563503(Rs/Ro)² − 0.86177665431(Rs/Ro) + 1.079213151
    static func ppm(fromRsRo rsRo: Double) -> Double {
        let a: Double = 0.189563503
        let b: Double = -0.86177665431
        let c: Double = 1.079213151

        var mgPerL = (a * pow(rsRo, 2)) + (b * rsRo) + c
        mgPerL *= 100;

        // Concentration can't be negative — clamp at zero
        // in case the curve produces a negative value at
        // very low Rs/Ro ratios (near-zero gas presence)
        return max(mgPerL, 0)
    }
}