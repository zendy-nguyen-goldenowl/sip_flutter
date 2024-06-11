# sip_flutter

This repository provides a Flutter integration for the Baresip VoIP library, enabling you to develop real-time voice and video calling applications within your Flutter projects. By leveraging Baresip's robust functionality, you can seamlessly incorporate VoIP features into your mobile apps.

## Installation
1. Add dependency to your pubspec.yaml
```
dependencies:
  sip_flutter:
    git:
     url: https://github.com/zendy-nguyen-goldenowl/sip_flutter.git
```
2. Setup Android
- Navigate to `android/app/build.gradle`: Locate the build.gradle file within the `android/app` directory of your Flutter project.
- Add `packagingOptions` block: Within the android block, add the following code snippet to specify which native libraries to include in your APK:
```
android {
    defaultConfig {
        // ... other configuration
    }

    packagingOptions {
        pickFirst 'lib/x86/libc++_shared.so'
        pickFirst 'lib/x86_64/libc++_shared.so'
        pickFirst 'lib/armeabi-v7a/libc++_shared.so'
        pickFirst 'lib/arm64-v8a/libc++_shared.so'
    }
}
```
3. Setup IOS
- Navigate to `ios/Runner/Podfile`: Locate the Podfile file within the `ios/Runner` directory of your Flutter project. This file manages dependencies for your iOS project.
- Add `baresip` pod dependency: Within the target 'Runner' do block, add the following line to include the Baresip library as a dependency:
```
pod 'baresip', :git => 'https://github.com/Catelt/baresip-ios.git'
```
4. Don't forget to `flutter pub get`.

## Usage
1. Initialize Baresip:
```dart
Future<void> initializeBaresip() async {
    var sipConfiguration = SipConfiguration(
      username: abc,
      domain: sip.antisip.com,
      password: 123,
    );
    SipFlutter.callModule.initSipModule(sipConfiguration);
}
```
2. Making a Call:
```dart
Future<void> makeCall(String sipUri) async {
  await SipFlutter.callModule.call(sipUri);
}
```
3. Answering a Call:
```dart
void answerCall() {
  SipFlutter.callModule.answer();
}
```
4. Hanging Up a Call:
```dart
void hangupCall() {
  SipFlutter.callModule.hangup();
}
```
5. Pausing a Call:
```dart
void pauseCall() {
  SipFlutter.callModule.pause();
}
```
6. Resuming a Call:
```dart
void resumeCall() {
  SipFlutter.callModule.resume();
}
```
7. Listen for call event:
```dart
Future<void> listenForCallEvents() async {
  SipFlutter.callModule.eventCallStreamController.stream.listen((event) {
    switch (event.type) {
      case SipEvent.ring: // Ringing
        sipEvent = event.type;
        caller = event.caller ?? ""; // Store caller information if available

        switch (event.callType) {
          case CallType.inbound: // Incoming call
            break;
          case CallType.outbound: // Outgoing call
            break;
          case null:
            break;
        }
        break;
      case SipEvent.up: 
        // Call established
        break;
      case SipEvent.hangup: 
        // Call ended
        break;
      case SipEvent.paused: 
        // Call paused
        break;
      case SipEvent.resuming: 
        // Call resumed
        break;
      case SipEvent.missed: 
        // Missed call
        break;
      case SipEvent.error: 
        // Call error
        break;
    }
  });
}
```
8. Listen for account event:
```dart
SipFlutter.callModule.eventAccountStreamController.stream.listen((event) {
  switch (event.type) {
    case SipAccountEventType.ok: 
      print('Account registration successful');
      break;
    case SipAccountEventType.failed: 
      print('Account registration failed');
      break;
    case SipAccountEventType.none:
      print('No account');
      break;  
    case SipAccountEventType.progress: 
      print('Account registration in progress');
      break;
    case SipAccountEventType.cleared: 
      print('Account deregistered');
      break;
    case SipAccountEventType.refreshing:
      print('Account refreshing');
      break;
  }
});
```
## License
This project is licensed under the MIT License (see LICENSE.md for details).

