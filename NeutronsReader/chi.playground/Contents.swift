import UIKit

extension Int {
    
    func factorial() -> Double {
        if self <= 1 {
            return 1
        }
      return (1...self).map(Double.init).reduce(1.0, *)
    }
    
}

var measured = [7677, 22643, 24784, 13560, 4018, 692, 52, 2]
let PkExpected = [0.00674, 0.05965, 0.22055, 0.35090, 0.25438, 0.08935, 0.01674, 0.00169, 0.00740]

for ePercent in 1...99 {
    let minN = 2
    let maxN = measured.count-2
    
    let Nd = measured.reduce(.zero, +)
    let e: Double = Double(ePercent) / 100.0
    var expected = [Int]()
    for _ in 0...maxN {
        expected.append(0)
    }
    var chi21: Double = 0
    var chi22: Double = 0
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
        chi21 += pow(Double(measured[index]) - Double(expected[index]), 2)/Double(expected[index])
    }
    for index in minN...maxN {
        let indexNext = index+1
        if indexNext < maxN {
            let measuredPerNext = Double(measured[index])/Double(measured[indexNext])
            let expectedPerNext = Double(expected[index])/Double(expected[indexNext])
            chi22 += pow(measuredPerNext - expectedPerNext, 2)/expectedPerNext
        }
    }
    print(String(format: "%d\t%.5f\t%.5f", ePercent, chi21, chi22))
}
