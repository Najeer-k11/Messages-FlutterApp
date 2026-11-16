# Messages

[![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Isar Database](https://img.shields.io/badge/Database-Isar-blue?style=for-the-badge)](https://isar.dev)
[![State Management](https://img.shields.io/badge/State-BLoC-29B6F6?style=for-the-badge)](https://bloclibrary.dev)

A fast, private SMS and MMS app for Android, built with Flutter in a Material 3 Expressive design.
Messages sorts your inbox on-device, surfaces one-time codes and bank transactions, and never
sends your messages anywhere.

> **Status:** in active development. SMS is complete; MMS (photo) sending and receiving is new
> and still being tested across carriers.

---

## Screenshots

<table>
  <tr>
    <td align="center"><img src="screenshots/inbox_light.png" width="240" alt="Inbox with active one-time codes"><br><b>Inbox and codes</b></td>
    <td align="center"><img src="screenshots/conversation_light.png" width="240" alt="Conversation with a photo message"><br><b>Conversation with photos</b></td>
    <td align="center"><img src="screenshots/money_light.png" width="240" alt="Money tab with bank transactions"><br><b>Money</b></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/inbox_dark.png" width="240" alt="Inbox in dark mode"><br><b>Dark mode</b></td>
    <td align="center"><img src="screenshots/conversation_dark.png" width="240" alt="Conversation in dark mode"><br><b>Conversation, dark</b></td>
    <td align="center"><img src="screenshots/settings_light.png" width="240" alt="Settings with theme and colour options"><br><b>Settings</b></td>
  </tr>
  <tr>
    <td align="center"><img src="screenshots/compose_light.png" width="240" alt="New message sheet with contacts"><br><b>New message</b></td>
    <td align="center"><img src="screenshots/search_light.png" width="240" alt="Search across all messages"><br><b>Search</b></td>
    <td align="center"><img src="screenshots/welcome_light.png" width="240" alt="First-run welcome screen"><br><b>Welcome</b></td>
  </tr>
</table>

---

## Features

**Messaging**
- Full SMS client that can be set as the default SMS app, with conversation history, read state,
  swipe-to-delete and multi-select.
- MMS: attach up to three photos from the system photo picker. Images are compressed to your
  carrier's size limit. Incoming MMS are downloaded and stored when Messages is the default app.
- Delivery state on every outgoing message ("Sending", "Not sent").
- Notifications with inline quick reply and a one-tap "Copy OTP" action. A conversation's
  notification clears when you read it.
- Search across sender names, numbers and every message body.

**Smart inbox (all on-device)**
- **Codes:** active one-time passwords appear at the top of the inbox with the service name and
  time remaining, and disappear when they expire. Tap a code to copy it.
- **Money:** amounts, debits, credits and account endings are extracted from bank texts.
- **Unread:** a dedicated tab, with a count badge on the dock.
- Promotional senders (DLT IDs ending in `-P`) are kept out of notifications.

**Design**
- Material 3 Expressive: Google Sans Flex with optical sizing, expressive shapes, spring motion,
  and a floating glass navigation dock.
- Wallpaper colours on Android 12+, read natively from the system (exact system colour roles on
  Android 14+), or one of nine preset palettes.
- Light, dark and pure-black (OLED) themes, edge to edge.

---

## Architecture

The app follows a feature-driven structure, with a shared design system and a native Android
layer for everything the SMS and MMS providers require.

```mermaid
graph TD
    App([Messages]) --> Features
    App --> UI
    Features --> Services

    subgraph UI [lib/ui: design system]
        Theme[Theme, typography, palettes]
        Components[Components, dock, shapes, motion]
    end

    subgraph Features [lib/features]
        Inbox[Inbox: shell, tabs, BLoC]
        Conversation[Conversation and composer]
        Compose[New message]
        Search[Search]
        Settings[Settings]
    end

    subgraph Services [lib/services]
        SmsRepo[SmsRepository]
        Classifier[MessageClassifier / OtpParser]
        Wallpaper[Wallpaper colours]
        Isar[(Isar local DB)]
    end

    SmsRepo --> Isar
    SmsRepo -- method channel --> Native
    Wallpaper -- method channel --> Native

    subgraph Native [android: Kotlin]
        Provider[SMS/MMS provider sync]
        Mms[MMS PDU encode/decode, send, download]
        Receivers[SMS/MMS receivers, notifications]
        Colors[Material You colours]
    end
```

### Folder structure
- `lib/ui/`: the Material 3 Expressive design system (theme, typography, palettes, shapes,
  motion, glass, dock and shared components).
- `lib/features/`: screens and widgets, one folder per feature.
- `lib/services/`: the SMS repository, Isar models, message classification and wallpaper colours.
- `android/app/src/main/kotlin/`: SMS/MMS provider access, the MMS encoder and decoder,
  broadcast receivers and the Material You colour reader.
- `test/`: unit tests for the parsers and colour-scheme building.

---

## Tech stack

- **UI:** [Flutter](https://flutter.dev) 3.50 with [`material_ui`](https://pub.dev/packages/material_ui)
- **State management:** [flutter_bloc](https://pub.dev/packages/flutter_bloc) and [provider](https://pub.dev/packages/provider)
- **Local database:** [Isar Community](https://pub.dev/packages/isar_community)
- **Colour:** [material_color_utilities](https://pub.dev/packages/material_color_utilities) with a native Material You bridge
- **Android build:** Gradle 9.5, Android Gradle Plugin 9.3, Kotlin 2.4, JDK 17

---

## Getting started

### Prerequisites
- Flutter SDK 3.50 or newer
- JDK 17 or newer
- Android SDK, and an Android device or emulator

### Install and run

1. Clone the repository:
   ```bash
   git clone https://github.com/Najeer-k11/Messages-FlutterApp.git
   cd Messages-FlutterApp
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Generate the Isar database code:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. Run the app:
   ```bash
   flutter run
   ```

5. Run the tests:
   ```bash
   flutter test
   ```

> MMS needs a SIM with mobile data and MMS enabled by the carrier. Emulators can send and
> receive SMS but not MMS.

---

## Permissions and privacy

All message processing, classification and parsing happens on the device. No message content
or financial detail leaves it.

- **SMS:** read your messages, receive new ones and send replies.
- **Contacts:** show contact names instead of numbers, and pick recipients.
- **Notifications:** alert you to new messages, with quick reply and code copying.
- **Default SMS app (optional):** needed to receive messages in the background, store sent and
  received MMS, delete messages and keep read state in sync with the system.

Photos are chosen through the system photo picker, so the app never needs storage access.

---

## Credits

- Design system adapted from [Expressive Clock](https://github.com/samuelbeckman/expressive-clock)
  by Samuel Beckman, itself based on Material Clock by Rayane Bouafia (MIT). See
  [`licenses/LICENSE-MIT-material-clock.txt`](licenses/LICENSE-MIT-material-clock.txt).
- [Google Sans Flex](https://fonts.google.com/specimen/Google+Sans+Flex), SIL Open Font License 1.1.
  See [`licenses/OFL-1.1.txt`](licenses/OFL-1.1.txt).

---

## License

See the [LICENSE](LICENSE) file for details.
