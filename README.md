# ble_agent

Flutter SDK for BLE device management and translation services.

## Installation

Add this to your package's pubspec.yaml file:

```yaml
dependencies:
  ble_agent: ^1.0.0
```

## iOS Setup

### 1. Configure Permissions

Add the following permissions to your `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Bluetooth permission is required to connect to BLE devices</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Bluetooth permission is required to connect to BLE devices</string>
```

### 2. Run pod install

```bash
cd ios
pod install
```

## Android Setup

### 1. Configure Permissions

Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

### 2. Runtime Permission Request

On Android 12+, you need to request the following runtime permissions:

- `BLUETOOTH_SCAN`
- `BLUETOOTH_CONNECT`
- `ACCESS_FINE_LOCATION`

On iOS, you need to request Bluetooth permission at runtime.

## Usage

### Import

```dart
import 'package:ble_agent/ble_agent.dart';
```

### Initialize the SDK

```dart
final bleAgent = BleAgentFlutter();

await bleAgent.initialize(
  userId: 'your_user_id',
  organizationId: 'your_organization_id',
  secret: 'your_secret',
  appPackageName: 'your_app_package_name',
  country: 'your_country', // ISO 3166-1 alpha-2，example "CN"、"US"
);
```

### Set Up Listeners

Before scanning or translating, set up listeners to receive device and translation events:

```dart
// Device listener
bleAgent.addDeviceListener(_DeviceListener(
  onDeviceFoundCallback: (BleDevice device) {
    print('Found device: ${device.deviceName} (${device.mac})');
  },
  onConnectedCallback: (BleDevice device) {
    print('Connected: ${device.deviceName}');
  },
  onDisconnectedCallback: (BleDevice device) {
    print('Disconnected: ${device.deviceName}');
  },
  onErrorCallback: (String error) {
    print('Error: $error');
  },
  onAudioModeUpdatedCallback: (int errorCode, String errorMessage) {
    print('Audio mode updated: $errorCode - $errorMessage');
  },
  onAudioStreamDataCallback: (List<int> audioData) {
    // Handle audio stream data (PCM format)
  },
));

// Translation listener
bleAgent.addTranslationListener(_TranslationListener(
  onRecognitionResultCallback: (String id, String text, bool isFinal, bool isLeft) {
    print('Recognition: $text (final: $isFinal, left: $isLeft)');
  },
  onTranslationCallback: (String id, String sourceText, String translatedText, bool isLeft) {
    print('Translation: $sourceText -> $translatedText');
  },
  onErrorCallback: (int errorCode, String error) {
    print('Translation error: [$errorCode] $error');
  },
  onTtsFileCallback: (String id, String filePath, bool isLeft) {
    print('TTS file: $filePath');
  },
  onConsumeTokensCallback: (String tokenType, int tokens) {
    print('Token consumed: $tokenType - $tokens');
  },
));
```

### Scan for Devices

```dart
// Start scanning
await bleAgent.scanDevices();

// Stop scanning
await bleAgent.stopScan();
```

### Connect to Device

```dart
await bleAgent.connectDevice(device.deviceId);
```

### Fetch Supported Languages

```dart
final languages = await bleAgent.fetchLanguages();
for (var lang in languages) {
  print('${lang.key}: ${lang.value}');
}
```

### Translation

```dart
// Start translation
await bleAgent.startTranslation(
  workMode: WorkMode.callTranslation,  // telephoneSubtitle, callTranslation, bidirectionalTranslation
  sourceLang: 'zh',
  targetLang: 'en',
  stepMode: StepMode.tts,  // asr, translation, tts
);

// Stop translation (also stops recording)
await bleAgent.stopRecordingAndTranslation();
```

**WorkMode enum values:**
- `WorkMode.telephoneSubtitle` - Telephone subtitle
- `WorkMode.callTranslation` - Call translation
- `WorkMode.bidirectionalTranslation` - Bidirectional translation

**StepMode enum values:**
- `StepMode.asr` - Speech recognition only
- `StepMode.translation` - Recognition + translation
- `StepMode.tts` - Recognition + translation + TTS

### Call Recording

```dart
// Start call recording
await bleAgent.startCallRecording();

// Audio stream data is received via the onAudioStreamData callback
// The data is in PCM format (16kHz, dual channel, 16-bit)

// Stop call recording
await bleAgent.stopRecordingAndTranslation();
```

### TTS Cache Management

```dart
// Enable TTS cache
await bleAgent.setTtsCacheEnabled(true);

// Disable TTS cache
await bleAgent.setTtsCacheEnabled(false);

// Check cache status
final isEnabled = await bleAgent.isTtsCacheEnabled();

// Delete all TTS cache files
await bleAgent.deleteAllTtsCacheFiles();
```

### Check Status

```dart
// Check if SDK is initialized
final initialized = await bleAgent.isInitialized();

// Check if device is connected
final connected = await bleAgent.isDeviceConnected();
```

### Disconnect Device

```dart
await bleAgent.disconnectDevice();
```

### Release SDK

```dart
await bleAgent.release();
```

## API Reference

### BleDevice

| Property | Type | Description |
|---|---|---|
| `deviceId` | `String` | Device ID |
| `deviceName` | `String` | Device name |
| `mac` | `String` | MAC address |
| `rssi` | `int` | Signal strength |

### Language

| Property | Type | Description |
|---|---|---|
| `key` | `String` | Language display name |
| `value` | `String` | Language code |

### BleDeviceListener

| Method | Description |
|---|---|
| `onDeviceFound(BleDevice)` | Device found during scan |
| `onConnected(BleDevice)` | Device connected |
| `onDisconnected(BleDevice)` | Device disconnected |
| `onError(String)` | Error occurred |
| `onAudioModeUpdated(int, String)` | Audio mode updated (errorCode != 0 means error) |
| `onAudioStreamData(List<int>)` | Audio stream data received (PCM) |

### TranslationListener

| Method | Description |
|---|---|
| `onRecognitionResult(String id, String text, bool isFinal, bool isLeft)` | Speech recognition result |
| `onTranslation(String id, String sourceText, String translatedText, bool isLeft)` | Translation result |
| `onError(int errorCode, String error)` | Translation error |
| `onTtsFile(String id, String filePath, bool isLeft)` | TTS audio file generated |
| `onConsumeTokens(String tokenType, int tokens)` | Token consumption |

## Example

See the [example](example/) directory for a complete sample app.

## Troubleshooting

### Android Build Errors

If you encounter NDK errors:

1. Open Android Studio
2. Go to Preferences → Appearance & Behavior → System Settings → Android SDK
3. Select SDK Tools tab
4. Install NDK (Side by side)
5. Set the NDK version in `android/gradle.properties`:
   ```properties
   android.ndkVersion=28.2.13676358
   ```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
