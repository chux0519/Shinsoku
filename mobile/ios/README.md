## iOS

This directory now contains a usable first iOS implementation for Shinsoku.

### Current shape

- `App/`: SwiftUI host app
- `Keyboard/`: keyboard extension
- `Shared/`: shared profile and draft persistence layer
- `project.yml`: XcodeGen manifest

### What works now

- native SwiftUI app shell
- on-device speech dictation in the app using `Speech` + `AVAudioEngine`
- shared App Group storage for drafts and selected profile
- a drafts list with editing and deletion
- a keyboard extension that can:
  - show the active profile
  - browse recent drafts
  - insert the selected draft into the current text field
  - switch to the next keyboard

### Product shape on iOS

The iOS direction is intentionally different from Android:

- recording happens in the app
- insertion happens in the keyboard extension

That is the most practical shape while keeping the implementation aligned with
iOS platform constraints.

### Generate the project

```bash
brew install xcodegen
cd mobile/ios
xcodegen generate
open ShinsokuMobile.xcodeproj
```

### Build check

```bash
cd mobile/ios
xcodegen generate
xcodebuild -project ShinsokuMobile.xcodeproj \
  -scheme ShinsokuMobile \
  -destination 'generic/platform=iOS Simulator' \
  build
```

### Near-term direction

- move more prompt/profile/runtime logic toward shared native core
- replace simple app-owned dictation with reusable backend abstractions
- improve keyboard UX and app-to-keyboard continuity
