import SwiftUI

struct HomePageView: View {
    @ObservedObject var viewModel = HomePageModel()
    @State private var showPopup = false  // State to show/hide popup
    @State private var tokensEarned: Int = 0
    @State private var driveDuration: TimeInterval = 0
    @State private var speed: Int = 0
    @State private var popupScale: CGFloat = 0.1  // Scale effect for the popup
    @State private var isPulsating = false  // New state variable to control pulsating
    @State private var isCircleAnimating = false  // Control the circle animation

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                HStack {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 50)
                    Spacer()
                }
                .padding(.horizontal, 20)
                
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

                // Pulsating button with outer circle animation
                ZStack {
                    // Expanding Circle (only animates when driving is active)
                    if viewModel.isDriving {
                        Circle()
                            .fill(Color.green.opacity(0.3))
                            .frame(width: 175, height: 175)  // Initial size of the circle
                            .scaleEffect(isCircleAnimating ? 1.8 : 1.0)  // Circle expansion
                            .opacity(isCircleAnimating ? 0.0 : 1.0)  // Fade out as it expands
                            .animation(
                                Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                                value: isCircleAnimating
                            )
                            .onAppear {
                                isCircleAnimating = true  // Start the animation when the view appears
                            }
                            .onDisappear {
                                isCircleAnimating = false  // Stop animation when it disappears
                            }
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
                            .scaleEffect(isPulsating ? 1.05 : 1.0)  // Pulsating effect
                            .animation(
                                Animation.easeInOut(duration: 1.0) // Smooth in/out transition
                                    .repeatForever(autoreverses: true), value: isPulsating // Continuous animation
                            )
                            .onAppear {
                                isPulsating = true  // Start pulsating animation when the view appears
                            }
                    }
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(100)
                }

                VStack {
                    // Dynamic Text under the wheel
                    Text(viewModel.isWarningVisible ? "Get off your phone!" :
                         (viewModel.isStationaryVisible ? "Please start moving" :
                         (viewModel.isDriving ? "Stay focused" : "Tap the wheel to start")))
                        .font(.system(size: 20))
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                        .foregroundColor(viewModel.isWarningVisible || viewModel.isStationaryVisible ? .red :
                                        (viewModel.isDriving ? Color(UIColor(red: 0.23, green: 0.86, blue: 0.57, alpha: 1.00)) : .gray))

                    if viewModel.isDriving {
                        Text("Speed Limit: \(viewModel.speedLimit != nil ? String(format: "%.0f mph", viewModel.speedLimit!) : "N/A")")
                            .font(.system(size: 20))
                            .multilineTextAlignment(.center)
                            .padding(.top, 10)
                            .foregroundColor(Color.gray)

                        Text("Your Speed: \(viewModel.speedDevice != nil ? String(format: "%.0f mph", viewModel.speedDevice!) : "N/A")")
                            .font(.system(size: 20))
                            .multilineTextAlignment(.center)
                            .padding(.top, 5)
                            .foregroundColor(Color.gray)
                    }
                }
                Spacer()
            }
            .padding(.top)  // Changed from .padding() to .padding(.top)
            
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
            
            if viewModel.speedLimitExceeds > 0 {
                Text("🛑 Times above speed limit: \(viewModel.speedLimitExceeds)")
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.gray)
            } else {
                Text("🛑  Times above speed limit: 0")
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.gray)
//            }
//            if let speedL = viewModel.speedLimit {
//                Text("🏎️ Speed limit: \(speedL) mph")
//                    .font(.system(size: 16))
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .foregroundColor(.gray)
//            } else {
//                Text("🏎️ Speed limit: 0")
//                    .font(.system(size: 16))
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .foregroundColor(.gray)
//            }
//            if let speedD = viewModel.speedDevice {
//                Text("📲 Speed of Device: \(speedD) mph")
//                    .font(.system(size: 16))
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .foregroundColor(.gray)
//            } else {
//                Text("📲 Speed of Device: 0")
//                    .font(.system(size: 16))
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .foregroundColor(.gray)
            }
            
            Text("📱 you used your phone: \(viewModel.currPickups) time(s)")
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
                    .background(Color(red: 58 / 255, green: 220 / 255, blue: 145 / 255))
                    .cornerRadius(40)
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
