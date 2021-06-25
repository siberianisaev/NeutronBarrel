import UIKit

extension Int {
    
    func factorial() -> Double {
        if self <= 1 {
            return 1
        }
      return (1...self).map(Double.init).reduce(1.0, *)
    }
    
}

var measured = [101656.0, 265134.0, 269843.0, 136380.0, 38094.0, 6138.0, 589.0, 33.0, 2.0]
let PkExpected = [0.0061, 0.0608, 0.2272, 0.3460, 0.2476, 0.0906, 0.0190, 0.0024, 0.0002]

let minN = 0
let maxN = measured.count-1
let Nd = measured.reduce(.zero, +)

print("Efficiency,Chi^2")
for step in 0...9999 {
    let e: Double = Double(step) / 10000.0
    var expected = [Int]()
    for _ in 0...maxN {
        expected.append(0)
    }
    var chi2: Double = 0
    for index in minN...maxN {
        let i = index
        var Nit: Double = 0
        for index2 in index...maxN {
            let k = index2
            let Pk: Double = PkExpected[k]
            Nit += (k.factorial() / (i.factorial() * (k - i).factorial())) * pow(e, Double(i)) * pow(1 - e, Double(k - i)) * Pk
        }
        Nit *= Double(Nd)
        expected[index] = Int(Nit)
    }
    for index in minN...maxN {
        let measuredN = Double(measured[index])
        let expectedN = Double(expected[index])
        if measured[index] > 5 && expected[index] > 5 {
            chi2 += pow(measuredN - expectedN, 2)/expectedN
        }
    }
    print(String(format: "%f,%.5f", e, chi2))
}
