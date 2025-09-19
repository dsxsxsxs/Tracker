# Tracking

A sample Swift package that demonstrates a compact yet fully functional tracking solution for iOS applications. This implementation provides comprehensive tracking and analytics capabilities with local data persistence and reliable network delivery.

## Features

- 🚀 **Asynchronous tracking** - Non-blocking log dispatch with actor-based concurrency
- 💾 **SQLite persistence** - Local storage for reliable data retention
- 🔄 **Automatic retry** - Configurable retry mechanism for network failures
- 🛡️ **Error handling** - Comprehensive error handling and reporting
- 📦 **Batch processing** - Efficient batch sending of multiple events
- 🔧 **Configurable** - Flexible configuration for different environments
- 🧵 **Thread-safe** - Built with Swift's modern concurrency features

## Requirements

- iOS 16.0+
- Swift 6.1+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/your-username/Tracking.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select version requirements

## Quick Start

### Basic Setup

**Important:** Before using this package, you'll need to update the hardcoded URLs in `TrackingNetworkClient.swift` to point to your own tracking endpoints. The current implementation uses placeholder URLs (`tracker.hoge.jp`) that should be replaced with your actual server endpoints.

```swift
import Tracking

// Create a data store
let dataStore = try TrackingSQLiteDataStore()

// Configure the system
let systemConfig = TrackingSystemConfiguration(
    networkClientConfiguration: TrackingNetworkClientConfiguration(
        maxRetryCount: 3,
        suspend: { seconds in
            // Custom retry delay logic
            try await Task.sleep(for: .seconds(seconds))
        },
        networking: TrackingNetworkClient.DefaultNetworking()
    ),
    errorHandler: { error in
        print("Tracking error: \(error)")
    }
)

// Configure logging
let logConfig = TrackingConfiguration(
    environment: .production,
    headers: ["Content-Type": "application/json"],
    sharedParameters: ["app_version": "1.0.0", "platform": "iOS"]
)

// Initialize tracker
let tracker = Tracker(
    dataStore: dataStore,
    configuration: systemConfig,
    logConfiguration: logConfig
)
```

### Sending Events

```swift
// Send a single event
tracker.sendLog(name: "user_action", payload: [
    "action": "button_tap",
    "screen": "home",
    "timestamp": Date().timeIntervalSince1970
])

// Send multiple events at once
tracker.sendLogs(name: "user_events", payloads: [
    ["event": "page_view", "page": "home"],
    ["event": "scroll", "position": 100],
    ["event": "click", "element": "menu"]
])
```

## Architecture

This package is built around several key components:

### Core Components

- **`Tracker`** - Main interface for sending tracking events
- **`TrackingDispatcher`** - Actor-based dispatcher for handling event processing
- **`TrackingDataStore`** - SQLite-based local persistence layer
- **`TrackingNetworkClient`** - Network layer for sending data to remote endpoints

### Key Features

#### Local Persistence
Events are stored locally using SQLite, ensuring no data loss even when the network is unavailable.

#### Batch Processing
The system automatically batches events for efficient network transmission and processes them asynchronously.

#### Retry Mechanism
Failed network requests are automatically retried with configurable delays and maximum retry counts. The system supports exponential backoff strategies to prevent overwhelming servers during retry attempts.

#### Thread Safety
Built using Swift's modern concurrency features, including actors and `Sendable` types, for complete thread safety.

## Configuration

### Environment Support
Configure for different environments:

```swift
let config = TrackingConfiguration(
    environment: .development, // or .production
    headers: ["Authorization": "Bearer your-token"],
    sharedParameters: ["user_id": "12345"]
)
```

### Network Configuration
Customize retry behavior and networking:

```swift
let networkConfig = TrackingNetworkClientConfiguration(
    maxRetryCount: 5,
    suspend: { seconds in
        // Exponential backoff with maximum delay
        try await Task.sleep(for: .seconds(seconds))
    },
    networking: yourCustomNetworkingImplementation
)
```

**Note:** You'll need to implement your own networking layer that conforms to the `TrackingNetworkClientNetworking` protocol, including specifying the host URLs for your tracking endpoints.

## Testing

The package includes comprehensive unit tests covering:

- Data encoding and serialization
- SQLite data store operations
- Network client functionality
- Dispatcher behavior and error handling

Run tests using:
```bash
swift test
```

## License

This project is licensed under the MIT License. See the LICENSE file for details.
