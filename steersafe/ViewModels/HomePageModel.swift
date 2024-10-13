import Foundation
import CoreMotion
import FirebaseAuth
import FirebaseDatabase
import CoreLocation

class HomePageModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let motionManager = CMMotionManager()
    private let locationManager = CLLocationManager()
    private var initialLocation: CLLocation?
    private var lastLocation: CLLocation?
    
    @Published var isDriving: Bool = false
    @Published var time: TimeInterval = 0  // Total time in seconds
    @Published var coins: Int = 0           // Total coins earned
    @Published var netCoins: Int = 0       // Net coins after deductions
    @Published var zAccel: Double = 0.0     // Track z-axis movement
    @Published var pickups: Int = 0         // Total pickups across sessions
    @Published var currPickups: Int = 0     // Pickups during the current session
    @Published var isWarningVisible: Bool = false  // Show warning for 5 seconds
    
    @Published var initialLatitude: Double = 0.0
    @Published var initialLongitude: Double = 0.0
    @Published var currentLatitude: Double = 0.0
    @Published var currentLongitude: Double = 0.0
    @Published var speedLimit: Double? // Speed limit on the road
    @Published var speedLimitExceeds: Int = 0 // Count of speed limit exceeds
    @Published var isStationaryVisible: Bool = false
    
    private var lastPickupTime: Date?  // Track the last time a pickup was registered
    private var startTime: Date?            // Track when driving started
    private var timer: Timer?               // Timer for elapsed time tracking
    private var warningTimer: Timer?        // Timer to hide the warning after 5 seconds

    override init() {
        super.init()
        locationManager.delegate = self // Set delegate for location manager
        locationManager.requestWhenInUseAuthorization() // Request location permissions
    }
    // Toggle driving state
    func toggleDriving() {
        if isDriving {
            stopDriving()
        } else {
            startDriving()
        }
    }
    func fetchSpeedLimit() {
            guard currentLatitude != 0.0 && currentLongitude != 0.0 else {
                print("Current location is not set.")
                return
            }

            let apiKey = Keys.tomtomApiKey
            print("TomTom API Key: \(Keys.tomtomApiKey)")
            let urlString = "https://api.tomtom.com/snap-to-roads/1/snap-to-roads?points=\(initialLongitude),\(initialLatitude);\(currentLongitude),\(currentLatitude)&fields={projectedPoints{type,geometry{type,coordinates},properties{routeIndex}},route{type,geometry{type,coordinates},properties{id,speedRestrictions{maximumSpeed{value,unit}}}}}&key=\(apiKey)"


    //        print("Url \(urlString)")
            guard let url = URL(string: urlString) else {
                print("Invalid URL")
                return
            }

            let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                if let error = error {
                    print("Error fetching speed limit: \(error.localizedDescription)")
                    return
                }

                guard let data = data else {
                    print("No data received")
                    return
                }
                if let jsonString = String(data: data, encoding: .utf8) {
                            print("Raw Data: \(jsonString)")
                } else {
                    print("Failed to convert data to string")
                }

                // Parse the JSON response
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let routeArray = json["route"] as? [[String: Any]],
                       let firstRoute = routeArray.first,
                       let properties = firstRoute["properties"] as? [String: Any],
                       let speedRestrictions = properties["speedRestrictions"] as? [String: Any],
                       let maximumSpeed = speedRestrictions["maximumSpeed"] as? [String: Any],
                       let speedLimitValue = maximumSpeed["value"] as? Double {
                                            
                        DispatchQueue.main.async {
                            self?.speedLimit = speedLimitValue
                            print("Speed Limit: \(speedLimitValue) mph")
                        }
                    } else {
                        print("Could not parse speed limit information")
                    }
                } catch {
                    print("Error parsing JSON: \(error.localizedDescription)")
                }
            }

            task.resume()
        }

    // Function to start driving mode
    func startDriving() {
            print("started driving")
            isDriving = true
            time = 0
            currPickups = 0  // Reset currPickups for the current session
            startTime = Date()  // Set start time when driving begins

            if let currentLocation = lastLocation {
                initialLatitude = lastLocation?.coordinate.latitude ?? 0.0
                initialLongitude = lastLocation?.coordinate.longitude ?? 0.0
            }
            // Start a timer to update elapsed time every second
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if let startTime = self.startTime {
                    self.time = Date().timeIntervalSince(startTime)
                    if self.time >= 15 {
                        self.checkIfStationary() // Check if stationary after 15 seconds
                    }
                }
            }

            startAccelUpdates()  // Start monitoring the accelerometer when driving starts
            locationManager.startUpdatingLocation() // Start location updates
        }
    // Function to stop driving mode
    func stopDriving() {
        print("stopped driving")
        isDriving = false
        coins = Int(time) / 120  // Calculate 1 coin per 2 minutes of driving
        netCoins = coins - (currPickups / 2)  // Subtract pickups from coins
        if netCoins < 0 { netCoins = 0 }
        
        stopAccelUpdates()   // Stop monitoring the accelerometer when driving ends

        // Invalidate the timer
        timer?.invalidate()
        timer = nil

        // Update the user stats in Firebase
        updateUserStats()
    }

    // Function to start receiving accelerometer updates
    func startAccelUpdates() {
        print("started measuring accel")
        if motionManager.isAccelerometerAvailable {
            print("accel available")
            motionManager.accelerometerUpdateInterval = 0.05  // Update interval

            // Start updates for accelerometer data
            motionManager.startAccelerometerUpdates(to: OperationQueue.main) { [weak self] data, error in
                if let accelerometerData = data {
                    // Update the z-axis acceleration value
                    self?.zAccel = accelerometerData.acceleration.z

                    // Check if the phone is being moved too much (e.g., user picks up the phone)
                    let movementThreshold = 0.1  // Set a reasonable threshold for detecting a phone pickup
                    
                    if accelerometerData.acceleration.z > movementThreshold {
                        let now = Date()
                        if let lastPickup = self?.lastPickupTime {
                            // Check if 5 seconds have passed since the last pickup to debounce the input
                            if now.timeIntervalSince(lastPickup) > 5.0 {
                                self?.registerPickup(now)
                            }
                        } else {
                            // No previous pickup, register the first one
                            self?.registerPickup(now)
                        }
                    }
                } else if let error = error {
                    print("Accelerometer error: \(error.localizedDescription)")
                }
            }
        } else {
            print("Accelerometer is not available.")
        }
    }

    // Function to stop accelerometer updates
    func stopAccelUpdates() {
        motionManager.stopAccelerometerUpdates()
    }

    // Helper function to register a pickup and update the timestamp
    private func registerPickup(_ currentTime: Date) {
        pickups += 1
        currPickups += 1  // Increment the pickups for the current session
        lastPickupTime = currentTime
        print("Total Pickups: \(pickups), Current Session Pickups: \(currPickups)")
        showWarning()  // Show warning when a pickup is detected
    }

    // Function to show the "get off your phone" warning for 5 seconds
    private func showWarning() {
        isWarningVisible = true
        warningTimer?.invalidate()  // Invalidate any previous timer
        warningTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            self?.isWarningVisible = false
        }
    }

    // Function to update user's tokens and hoursDriven in Firebase
    private func updateUserStats() {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("No user is currently logged in.")
            return
        }

        let ref = Database.database().reference()

        ref.child("users").child(uid).observeSingleEvent(of: .value) { snapshot in
            var existingTokens = 0
            var existingHoursDriven = 0.0

            if let userData = snapshot.value as? [String: Any] {
                // Fetch existing tokens
                if let tokens = userData["tokens"] as? Int {
                    existingTokens = tokens
                } else if let tokensString = userData["tokens"] as? String, let tokens = Int(tokensString) {
                    existingTokens = tokens
                } else if let tokensDouble = userData["tokens"] as? Double {
                    existingTokens = Int(tokensDouble)
                } else if let tokensNumber = userData["tokens"] as? NSNumber {
                    existingTokens = tokensNumber.intValue
                } else {
                    existingTokens = 0
                }

                // Fetch existing hours driven
                if let hoursDriven = userData["hoursDriven"] as? Double {
                    existingHoursDriven = hoursDriven
                } else if let hoursDrivenString = userData["hoursDriven"] as? String, let hoursDrivenDouble = Double(hoursDrivenString) {
                    existingHoursDriven = hoursDrivenDouble
                } else if let hoursDrivenNumber = userData["hoursDriven"] as? NSNumber {
                    existingHoursDriven = hoursDrivenNumber.doubleValue
                } else {
                    existingHoursDriven = 0.0
                }
            }

            // Use netCoins calculated in stopDriving()
            let newTokens = max(0, existingTokens + self.netCoins)

            // Calculate hours driven this session
            let hoursThisSession = self.time / 3600.0  // Convert time from seconds to hours
            let newHoursDriven = existingHoursDriven + hoursThisSession

            // Prepare updated user data
            let updatedUserData: [String: Any] = [
                "tokens": newTokens,
                "hoursDriven": newHoursDriven,
                "lastTokens": self.netCoins,
                "lastHoursDriven": hoursThisSession
            ]

            // Update the user's data in Firebase Realtime Database
            ref.child("users").child(uid).updateChildValues(updatedUserData) { error, _ in
                if let error = error {
                    print("Error updating user data: \(error.localizedDescription)")
                } else {
                    print("User data updated successfully!")
                }
            }
        } withCancel: { error in
            print("Error fetching user data: \(error.localizedDescription)")
        }
    }
    // Function to check if the user has moved after 15 seconds
        private func checkIfStationary() {
            guard let currentLocation = lastLocation else {
                print("Last location is not available.")
                return
            }
            let distanceMoved = initialLocation?.distance(from: currentLocation) ?? 0
            let stationaryThreshold: CLLocationDistance = 5 // Movement less than 5 meters is considered stationary

            //User did not move
            if distanceMoved < stationaryThreshold {
                isStationaryVisible = true
                //Reset
                stopDriving()
                warningTimer?.invalidate()
                //Close please start moving display
                warningTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                    self?.isStationaryVisible = false
                }
            } else {
                isStationaryVisible = false
            }
        }
    // Location Manager Delegate methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastLocation = location  // Update the last location
        currentLatitude = location.coordinate.latitude
        currentLongitude = location.coordinate.longitude
        print("Current Location: \(currentLatitude), \(currentLongitude)")
        
        if initialLocation == nil {
            initialLocation = lastLocation
            initialLatitude = currentLatitude
            initialLongitude = currentLongitude
            print("Initial Location set to: \(initialLatitude), \(initialLongitude)")
        }
        
        fetchSpeedLimit()  // Fetch the speed limit whenever the location updates
    }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            print("Failed to find user's location: \(error.localizedDescription)")
        }
}
