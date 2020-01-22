import SwiftUI
import PlaygroundSupport

let POPULATION_SIZE = 20
let citiesCount = 20
let ELITE_SIZE = 1

let TOURNAMENT_SIZE = 5
let MAX_GENERATIONS_COUNT = 100

let FIELD_SIZE = 700.0
let minPosition = Float(10.0)
let maxPosition = Float(FIELD_SIZE-10.0)

var distancesDictionary = [String:Float]()

struct City: Equatable {
    var id = UUID()
    let x: Float
    let y: Float
    
    func distance(otherCity: City) -> Float {
        if let distance = distancesDictionary["\(id)\(otherCity.id)"] {
            return distance
        }
        
        let xDistance = abs(x - otherCity.x)
        let yDistance = abs(y - otherCity.y)
        let distance = sqrt(pow(xDistance, 2) + pow(yDistance, 2))
        distancesDictionary["\(id)\(otherCity.id)"] = distance
        return distance
    }
    
    func position() -> CGPoint {
        return CGPoint(x: Double(x), y: Double(y))
    }
    
    static func == (lhs: City, rhs: City) -> Bool {
        return
            lhs.x == rhs.x &&
            lhs.y == rhs.y
    }
}

struct Chromosome {
    var cities: [City]
    var summaryDistance: Double
    
    init(initialCities: [City]) {
        cities = initialCities
        summaryDistance = 0
        summaryDistance = countSummaryDistance()
    }
    
    private func countSummaryDistance() -> Double {
        var distance = 0.0
        
        for (index, city) in cities.enumerated() {
            if index > 0 {
                distance += Double(city.distance(otherCity: cities[index-1]))
            }
            if index == cities.count-1 {
                distance += Double(city.distance(otherCity: cities[0]))
            }
        }
        
        return distance
    }
    
    mutating func mutate() {
        let gene1 = Int.random(in: 0...citiesCount-1)
        let gene2 = Int.random(in: 0...citiesCount-1)
        
        cities.swapAt(gene1, gene2)
        summaryDistance = countSummaryDistance()
    }
}

var currentBestChromosome: Chromosome?

func selectParentTournament(_ population:[Chromosome]) -> Chromosome{
    var tournamentPopulation = [Chromosome]()
    for _ in 1...TOURNAMENT_SIZE {
        tournamentPopulation.append(population[Int(arc4random_uniform(UInt32(population.count)))])
    }

    let sortedTournamentPopulation = tournamentPopulation.sorted { (ch1, ch2) -> Bool in
        return ch1.summaryDistance < ch2.summaryDistance
    }
    return sortedTournamentPopulation.first!
}

func getEliteToPreserve(_ population: [Chromosome]) -> [Chromosome] {
    //sort by fitness
    let sortedPopulation = population.sorted { (ch1, ch2) -> Bool in
        return ch1.summaryDistance < ch2.summaryDistance
    }
    
    return sortedPopulation.dropLast(POPULATION_SIZE-ELITE_SIZE)
}

//create next generation
func createNextGeneration(population: [Chromosome]) -> [Chromosome] {
    var nextGeneration = [Chromosome]()
    
    nextGeneration.append(contentsOf: getEliteToPreserve(population))
    
    for _ in 1...POPULATION_SIZE-ELITE_SIZE {
        
        let chromosome1 = selectParentTournament(population)
        let chromosome2 = selectParentTournament(population)
        
        
        let gene1 = Int.random(in: 0...citiesCount-1)
        let gene2 = Int.random(in: 0...citiesCount-1)
        
        let crossoverStart = min(gene1, gene2)
        let crossoverEnd = max(gene1, gene2)
        
        var tempChromosome = [City]()
        for index in crossoverStart...crossoverEnd {
            tempChromosome.append(chromosome1.cities[index])
        }
        
        var newChromosome = [City]()
        for city in chromosome2.cities {
            if !tempChromosome.contains(city) {
                newChromosome.append(city)
            }
        }
        
        newChromosome.insert(contentsOf: tempChromosome, at: crossoverStart)
        var offspring = Chromosome(initialCities: newChromosome)
        offspring.mutate()
        nextGeneration.append(offspring)
    }
    
    return nextGeneration
}

//create default cities order
var tempArray = [City]()
for _ in 1...citiesCount {
    let x = Float.random(in: minPosition...maxPosition)
    let y = Float.random(in: minPosition...maxPosition)
    let city = City(x: x, y: y)
    print(city)
    tempArray.append(city)
}
let defaultOrder = tempArray

//create initial Population
var population = [Chromosome]()
for _ in 1...POPULATION_SIZE {
    let chromosome = Chromosome(initialCities: defaultOrder.shuffled())
    population.append(chromosome)
}

public class TSPView: UIView  {

    public init() {
        super.init(frame: CGRect(x: 0, y: 0, width: FIELD_SIZE, height: FIELD_SIZE))
        backgroundColor = UIColor.white
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func draw(_ rect: CGRect) {

        guard let currentSolution = currentBestChromosome else {
            return
        }
        
        for city in currentSolution.cities {
            let dotPath = UIBezierPath(ovalIn: CGRect(origin: CGPoint(x: Double(city.x-5), y: Double(city.y-5)), size: CGSize.init(width: 10, height: 10)))
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = dotPath.cgPath
            shapeLayer.fillColor = UIColor.green.cgColor
            layer.addSublayer(shapeLayer)
        }
        
        for (index, city) in currentSolution.cities.enumerated() {
            if index > 0 {
                let path = UIBezierPath()
                path.move(to: currentSolution.cities[index-1].position())
                path.addLine(to: city.position())
                
                let shapeLayer = CAShapeLayer()
                shapeLayer.path = path.cgPath
                shapeLayer.strokeColor = UIColor.black.cgColor
                shapeLayer.lineWidth = 1.0

                layer.addSublayer(shapeLayer)
            }
        }
        
        //draw line from last city to first (as in TSP assumptions)
        let path = UIBezierPath()
        path.move(to: currentSolution.cities.first!.position())
        path.addLine(to: currentSolution.cities.last!.position())
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.black.cgColor
        shapeLayer.lineWidth = 1.0

        layer.addSublayer(shapeLayer)
    }
}

DispatchQueue.global(qos: .background).async {
    for index in 1...MAX_GENERATIONS_COUNT {
        population = createNextGeneration(population: population)
        currentBestChromosome = population.first
        print("\(index). \(currentBestChromosome!.summaryDistance)")
        DispatchQueue.main.async {
            PlaygroundPage.current.liveView = TSPView()
        }
    }
}
