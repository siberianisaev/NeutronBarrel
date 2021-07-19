import UIKit

extension Int {
    
    func factorial() -> Double {
        if self <= 1 {
            return 1
        }
      return (1...self).map(Double.init).reduce(1.0, *)
    }
    
}

//0        0.12465589189158728
//1        0.3234771191001485
//2        0.32895889862863936
//3        0.16693927636565484
//4        0.047338991217318535
//5        0.007757753527020059
//6        0.0008220556039255797
//7        4.790041222531227e-05
//8    3    2.1132534805284825e-06

var measured = [78849, 205178, 208655, 105368, 29409, 4705, 444, 23]
let PkExpected = [0.0061, 0.0608, 0.2272, 0.3460, 0.2476, 0.0906, 0.0190, 0.0024]//, 0.0002

let minN = 0
let maxN = measured.count-1
let Nd = measured.reduce(.zero, +)

print("Efficiency,Chi^2")
for step in 0...99999 {
    let e: Double = Double(step) / 100000.0
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
