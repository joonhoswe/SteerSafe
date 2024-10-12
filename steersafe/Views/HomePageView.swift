import SwiftUI

struct HomePageView: View {
    @ObservedObject var viewModel = HomePageModel()
    @State private var showPopup = false  // State to show/hide popup
    @State private var tokensEarned: Int = 0
    @State private var driveDuration: TimeInterval = 0
    @State private var popupScale: CGFloat = 0.1  // Scale effect for the popup
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                // Logo at the top
                HStack {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 50)
                    Spacer()
                }
                .padding(.horizontal)

                Spacer()

                // Stopwatch Text, shows elapsed time if driving, otherwise shows placeholder
                if viewModel.isDriving {
                    Text(formattedTime(viewModel.time))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .padding(.bottom, 10)
                } else {
                    Text(" ")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .padding(.bottom, 10)
                }

                // Steering Wheel Button with z-axis monitoring
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        viewModel.toggleDriving()  // Toggle driving state
                        if !viewModel.isDriving {
                            // Show popup with tokens and duration after the drive ends
                            tokensEarned = viewModel.coins
                            driveDuration = viewModel.time
                            showPopupWithAnimation()  // Show popup with bounce effect
                        }
                    }
                }) {
                    Image(viewModel.isWarningVisible ? "getoffyourphone" : (viewModel.isDriving ? "greenhomewheel" : "greysteeringwheel"))
                        .resizable()
                        .frame(width: 200, height: 200)
                        .transition(.scale)
                }
                .background(Color.gray.opacity(0.3))
                .cornerRadius(100)

                // Dynamic Text under the wheel
                Text(viewModel.isWarningVisible ? "get off your phone!" :
                     (viewModel.isStationaryVisible ? "please start moving" :
                     (viewModel.isDriving ? "stay focused" : "tap the wheel to start")))
                    .font(.system(size: 20))
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .foregroundColor(viewModel.isWarningVisible || viewModel.isStationaryVisible ? .red :
                                    (viewModel.isDriving ? Color(UIColor(red: 0.23, green: 0.86, blue: 0.57, alpha: 1.00)) : .gray))

                /*
                    // Display current speed and speed limit
                    if viewModel.isDriving {
                        Text("Current Speed: \(viewModel.currentSpeed, specifier: "%.2f") km/h")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .padding(.top, 10)

                        Text("Speed Limit: \(viewModel.speedLimit, specifier: "%.2f") km/h")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .padding(.top, 2)
                    }
                */
                Spacer()
            }
            .padding()

            // Popup overlay with bounce effect
            if showPopup {
                popupView
                    .scaleEffect(popupScale)  // Apply scale effect
                    .onAppear {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)) {
                            popupScale = 1.0  // Scale up with a bounce
                        }
                    }
                    .transition(.opacity)  // Smooth transition for opacity
            }
        }
    }

    // Function to format the elapsed time
    func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // Custom Popup View
    var popupView: some View {
        VStack(spacing: 20) {
            Text("🚘 drive summary:")
                .font(.system(size: 20))
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("⏰ duration: \(formattedTime(driveDuration))")
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.gray)
            
            Text("🤑 tokens earned: \(tokensEarned)")
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.gray)

            Text("📱 you used your phone: \(viewModel.currPickups) time(s)")
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.gray)
            
            Text("🚦 Speed Limit Violations: \(viewModel.speedLimitExceeds) time(s)")
                .font(.system(size: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.gray)

            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)) {
                    popupScale = 0.1  // Scale down with bounce effect
                    showPopup = false  // Dismiss the popup
                }
            }) {
                Text("OK")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 10)
        .frame(width: 300)
        .padding(.bottom, 50)
    }

    // Function to show popup with initial scale
    func showPopupWithAnimation() {
        popupScale = 0.1  // Start with small scale
        showPopup = true  // Show popup
    }
}

struct HomePageView_Previews: PreviewProvider {
    static var previews: some View {
        HomePageView()
    }
}
