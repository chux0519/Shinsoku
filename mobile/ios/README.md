## iOS

This directory now contains the first native iOS scaffold for Shinsoku.

The structure mirrors the Android side:

- `App/`: SwiftUI app shell
- `Keyboard/`: keyboard extension shell
- `Shared/`: small reusable model layer for the iOS targets
- `project.yml`: XcodeGen manifest for generating an Xcode project

### Current direction

- native SwiftUI app shell
- native keyboard extension
- room for future Objective-C++ / C++ bridge work
- shared prompt/profile/runtime concepts aligned with the rest of the repo

### Generate the Xcode project

This scaffold uses XcodeGen to avoid committing a bulky generated `.xcodeproj`.

```bash
brew install xcodegen
cd mobile/ios
xcodegen generate
open ShinsokuMobile.xcodeproj
```

### What is already included

- app home screen
- profile picker shell
- keyboard extension shell
- shared profile model
- shared draft entry model

This is not yet a complete voice-input implementation. It is the maintainable
starting point for building the iOS app and keyboard extension without pushing
iOS-specific project files into the repository root.
