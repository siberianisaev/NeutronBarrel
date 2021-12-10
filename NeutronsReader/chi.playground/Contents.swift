import Foundation

extension Int {
    
    func factorial() -> Double {
        if self <= 1 {
            return 1
        }
      return (1...self).map(Double.init).reduce(1.0, *)
    }
    
}


let m = NeutronsMultiplicity.init(info: [0: 30, 1: 56, 2: 55, 3: 31, 4: 6, 5: 2, 6: 1], efficiency: 43.6, efficiencyError: 1.0)
print(m.stringValue())

//let a1 = [
//"AR208PB002.001_303889", "AR208PB23.138_375743"]
//let a2 = ["AR208PB002.001_303889", "AR208PB002.001_303889", "AR208PB002.001_303889"]
//let set1 = Set(a1)
//let set2 = Set(a2)
//let sub = set1.symmetricDifference(set2)
//print(sub)


let events = 1419612
let neutrons = 2435546
let average = 1.715642020495741 //± 0.001811610238618803
let efficiency = 54.7
let efficiencyError = 0.1
let averageErrorWithEfficiency = (Double(neutrons)/(Double(events) * (efficiency/100)))*(1/Double(neutrons) + 1/Double(events) + pow(efficiencyError/efficiency, 2)).squareRoot()
print("\n*Average: \(average * 100.0/efficiency) ± \(averageErrorWithEfficiency)")

var measured = [96135, 257551, 269196, 141210, 40847, 7083, 801, 58, 3, 1]
let PkExpected = [0.0061, 0.0608, 0.2272, 0.3460, 0.2476, 0.0906, 0.0190, 0.0024, 0.0002, 0.0001]

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
