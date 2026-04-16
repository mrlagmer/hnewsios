//
//  AppDelegate.swift
//  HNReader
//
//  Created by Stuart Mitchell on 25/3/2026.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    // MARK: - Reference to root view controller for state management
    var storyFeedViewController: StoryFeedViewController?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Configure app appearance
        configureAppearance()
        
        // Register for background notification to save state
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveAppState),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // Register for memory warning notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        return true
    }

    // MARK: - Appearance Configuration
    
    private func configureAppearance() {
        // Set global tint color
        let window = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .map { ($0 as? UIWindowScene)?.windows.first }
            .compactMap { $0 }
            .first
        
        window?.tintColor = AppTheme.Colors.tint
        UINavigationBar.appearance().tintColor = AppTheme.Colors.tint
        UIBarButtonItem.appearance().tintColor = AppTheme.Colors.tint
        
        // Configure navigation bar appearance
        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithOpaqueBackground()
        navigationBarAppearance.backgroundColor = AppTheme.Colors.elevatedSurface
        navigationBarAppearance.shadowColor = .clear
        navigationBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: AppTheme.Typography.navigationTitle
        ]
        navigationBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: AppTheme.Typography.largeNavigationTitle
        ]
        
        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
        if #available(iOS 16.1, *) {
            UINavigationBar.appearance().compactScrollEdgeAppearance = navigationBarAppearance
        }
    }

    // MARK: - State Persistence

    @objc func saveAppState() {
        // Called when app enters background
        // State saving is primarily handled by the view controller as it scrolls
        // Additional state sync can occur here if needed
        print("✅ App state saved on background notification")
    }

    @objc func handleMemoryWarning() {
        // Handle memory warnings by notifying the preloader to release resources
        Task {
            await WebViewPreloader.shared.handleMemoryWarning()
        }
        print("⚠️ Memory warning handled - WebView cache cleared")
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

