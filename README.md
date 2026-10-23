# AirSense 🎮

> Turn your smartphone (Android & iOS) into an ultra-low-latency PlayStation DualSense / PC controller over local Wi-Fi.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Android%20%7C%20iOS-brightgreen)
![Client](https://img.shields.io/badge/client-Flutter-02569B?logo=flutter)
![Server](https://img.shields.io/badge/server-.NET%209-512BD4?logo=dotnet)

---

## Overview

**AirSense** is a low-latency, cross-platform virtual gamepad system. It streams multi-touch controls, 6-axis gyroscope motion, trackpad inputs, and haptic feedback between your mobile phone and Windows PC over your local network (LAN) without requiring Bluetooth.

### Why AirSense?
- **No Bluetooth Required**: Works over standard 5GHz home Wi-Fi via UDP with sub-3ms latency.
- **Genuine PlayStation Emulation**: Uses the **ViGEmBus** driver to emulate an authentic Sony DualShock 4 / DualSense controller on Windows. PC games and Steam recognize native PlayStation button glyphs ($\triangle$, $\bigcirc$, $\times$, $\square$), touchpad navigation, and motion controls.
- **Cross-Platform**: Built with **Flutter** for a single codebase across Android and iOS.
- **Auto-Discovery**: No need to manually type IP addresses—the client and host discover each other automatically via LAN broadcast.
- **Zero-Lag USB Fallback**: Supports wired USB connection via port forwarding for tournament-grade `< 0.5ms` response.

---

## Architecture

```
┌───────────────────────────────────────────────┐
│           AirSense Mobile Client              │
│  (Flutter - Android / iPhone 12)             │
│  - Virtual Thumbsticks & Triggers             │
│  - DualSense Touchpad Surface                 │
│  - 6-Axis Gyroscope Aiming                    │
│  - Haptic Feedback (Vibration Motor)          │
└───────────────────────┬───────────────────────┘
                        │ Low-latency UDP Stream (120 Hz)
                        ▼
┌───────────────────────────────────────────────┐
│            AirSense Windows Host              │
│  (C# / .NET 9)                                │
│  - UDP Listener & Auto-Discovery Beacon       │
│  - ViGEmBus Virtual Gamepad Bridge            │
│  - DualSense / DualShock 4 Emulation          │
└───────────────────────┬───────────────────────┘
                        │ Native Controller Feed
                        ▼
┌───────────────────────────────────────────────┐
│             Windows Games / Steam             │
│  (DirectInput, XInput, Steam Input)           │
└───────────────────────────────────────────────┘
```

---

## Project Structure

```
AirSense/
├── AirSense.Server/        # Windows host service (.NET 9 + ViGEmClient)
└── AirSense.Client/        # Mobile client application (Flutter)
```

---

## Getting Started

### Prerequisites

#### Windows Host
- Windows 10/11 (64-bit)
- [.NET 9.0 SDK](https://dotnet.microsoft.com/download/dotnet/9.0)
- [ViGEmBus Driver](https://github.com/nefarius/ViGEmBus/releases) installed on Windows

#### Mobile Client
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x+)
- Android device or iPhone connected to the same Wi-Fi network as the PC

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.
