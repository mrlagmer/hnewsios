# HN Reader - Native Swift iOS App

A native Swift iOS application for reading Hacker News stories and comments, converted from the React Native/Expo version.

## Project Setup

### Requirements
- Xcode 14.0 or later
- iOS 15.0 or later (minimum deployment target)
- macOS 12.0 or later

### Frameworks
The project uses the following iOS frameworks:
- **UIKit**: Core UI framework
- **WebKit**: For displaying article content
- **Foundation**: Core data types and utilities
- **Combine**: Reactive data binding

### Project Structure

```
HNReader/
├── Models/           # Data models (Story, Comment)
├── Services/         # API and caching services
├── ViewModels/       # MVVM ViewModels
├── Views/            # View controllers and custom views
├── Tests/            # Unit and property-based tests
├── Assets.xcassets/  # App icons and images
└── Base.lproj/       # Storyboards
```

### Configuration

#### Info.plist
The Info.plist is configured with:
- **Network Access**: `NSAppTransportSecurity` allows arbitrary loads for fetching HN content
- **Display Name**: "HN Reader"
- **Launch Screen**: LaunchScreen storyboard
- **Supported Orientations**: 
  - iPhone: Portrait, Landscape Left, Landscape Right
  - iPad: All orientations including Portrait Upside Down

#### App Icon
App icon assets are located in `Assets.xcassets/AppIcon.appiconset/`

#### Launch Screen
Launch screen is configured in `Base.lproj/LaunchScreen.storyboard`

### Building the Project

1. Open `HNReader.xcodeproj` in Xcode
2. Select a target device or simulator (iOS 15.0+)
3. Press Cmd+R to build and run

### Architecture

The app follows the **MVVM (Model-View-ViewModel)** architecture pattern:
- **Models**: Codable structs for Story and Comment
- **Services**: HackerNewsAPI, CacheManager, WebViewPreloader, SocialImageExtractor
- **ViewModels**: StoryFeedViewModel, CommentsViewModel (using Combine)
- **Views**: UIKit view controllers with UICollectionView and UITableView

### Key Features

- Fetch and display top stories from Hacker News
- Pagination with "Load more stories" button
- Pull-to-refresh functionality
- WebView for article content with preloading
- Threaded comments with collapse/expand
- Offline mode with full content download
- Social image extraction and display
- Adaptive layouts for iPhone and iPad
- Accessibility support (VoiceOver, Dynamic Type)

### Testing

The project includes both unit tests and property-based tests:
- **Unit Tests**: Located in `Tests/UnitTests/`
- **Property Tests**: Located in `Tests/PropertyTests/`
- **Testing Framework**: XCTest + SwiftCheck for property-based testing

Run tests with Cmd+U in Xcode.

### Next Steps

1. Implement Model structs (Story, Comment)
2. Implement Services (HackerNewsAPI, CacheManager)
3. Implement ViewModels with Combine
4. Implement Views and UI components
5. Add comprehensive tests
6. Configure app icon and launch screen assets
