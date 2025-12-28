# Indoor Navigation App 🗺️

BLE (Bluetooth Low Energy) tabanlı iç mekan navigasyon uygulaması. ESP32-C3 beacon cihazları kullanarak konum tespiti yapar ve WebSocket üzerinden Spring Boot backend ile iletişim kurar.

## 🏗️ Proje Yapısı

```
lib/
├── main.dart                          # Ana giriş noktası
├── core/
│   ├── config/
│   │   └── env_config.dart            # Environment değişkenleri
│   ├── constants/
│   │   └── app_constants.dart         # Sabit değerler
│   └── theme/
│       └── app_theme.dart             # Tema ve renkler
├── models/
│   ├── models.dart                    # Export dosyası
│   ├── beacon_model.dart              # Beacon veri modeli
│   ├── user_location.dart             # Kullanıcı konum modeli
│   └── navigation_route.dart          # Navigasyon rota modeli
├── services/
│   ├── services.dart                  # Export dosyası
│   ├── ble/
│   │   ├── ble.dart
│   │   └── ble_service.dart           # BLE tarama servisi
│   └── websocket/
│       ├── websocket.dart
│       ├── websocket_helper.dart      # WebSocket bağlantı yönetimi
│       └── websocket_service.dart     # WebSocket iş mantığı
├── widgets/
│   ├── widgets.dart                   # Export dosyası
│   ├── map/
│   │   └── indoor_map_widget.dart     # Harita widget'ı
│   ├── status/
│   │   └── connection_status_widget.dart
│   ├── cards/
│   │   └── location_info_card.dart
│   └── search/
│       └── destination_search_sheet.dart
└── screens/
    ├── screens.dart                   # Export dosyası
    └── navigation/
        └── navigation_screen.dart     # Ana navigasyon ekranı
```

## ⚙️ Konfigürasyon

`.env` dosyasında aşağıdaki ayarları yapabilirsiniz:

```env
# WebSocket Backend
WEBSOCKET_URL=ws://192.168.1.100:8080/ws/navigation

# BLE Ayarları
BEACON_MAC_PREFIX=A4:C1:38      # ESP32 MAC prefix filtresi
BLE_SCAN_DURATION=2000           # Tarama süresi (ms)
MIN_RSSI_THRESHOLD=-90           # Minimum sinyal gücü
TOP_BEACONS_COUNT=3              # Backend'e gönderilecek beacon sayısı
```

## 🔌 WebSocket Protokolü

### Mobil → Backend (Beacon Verileri)
```json
{
  "type": "BEACON_DATA",
  "data": {
    "deviceId": "flutter_device_xxx",
    "beacons": [
      {
        "macAddress": "A4:C1:38:XX:XX:XX",
        "rssi": -45,
        "lastSeen": "2024-01-01T12:00:00Z"
      }
    ]
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

### Backend → Mobil (Konum Güncellemesi)
```json
{
  "type": "LOCATION_UPDATE",
  "data": {
    "position": { "x": 150.5, "y": 200.3, "floor": 0 },
    "accuracy": 1.5,
    "currentRoom": "Sınıf 101",
    "confidence": 0.85
  }
}
```

### Backend → Mobil (Navigasyon Rotası)
```json
{
  "type": "NAVIGATION_PATH",
  "data": {
    "waypoints": [
      { "x": 100, "y": 100 },
      { "x": 150, "y": 150 },
      { "x": 200, "y": 200 }
    ],
    "totalDistance": 15.5,
    "estimatedTime": 45,
    "destinationName": "Kütüphane"
  }
}
```

## 🧭 Navigasyon Algoritmaları (Backend Tarafı)

Navigasyon algoritmaları **backend'de** olmalıdır. Nedenler:

1. **Trilateration/Triangulation**: 3 beacon'dan gelen RSSI değerleri ile konum hesaplaması yapılır
2. **Pathfinding (A\* veya Dijkstra)**: En kısa yol hesaplaması
3. **Duvar/Engel Tanımları**: Sadece backend'de tutulması yeterli

### Backend'de Tutulması Gerekenler:
- Harita grafı (düğümler ve kenarlar)
- Duvar/engel koordinatları
- Beacon konumları
- Oda tanımları

### Mobil'de Tutulması Gerekenler:
- Harita SVG görüntüsü (görsel)
- Backend'den gelen rota verisi
- Kullanıcı konumu (backend'den)

## 📱 Özellikler

- ✅ BLE beacon tarama ve filtreleme
- ✅ WebSocket ile gerçek zamanlı iletişim
- ✅ SVG harita görüntüleme (zoom/pan)
- ✅ Kullanıcı konumu animasyonu
- ✅ Navigasyon rotası çizimi
- ✅ Hedef arama ve seçimi
- ✅ Bağlantı durumu göstergesi
- ✅ Modern Material 3 tasarım

## 🚀 Kurulum

```bash
# Bağımlılıkları yükle
flutter pub get

# Android için çalıştır
flutter run

# iOS için çalıştır (macOS gerekli)
flutter run -d ios
```

## 📋 Gereksinimler

- Flutter 3.7+
- Dart 3.0+
- Android: API 21+ (BLE desteği)
- iOS: iOS 12+

## 🔒 İzinler

### Android (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

### iOS (ios/Runner/Info.plist)
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Konum tespiti için Bluetooth kullanılmaktadır</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>BLE beacon'larını taramak için gereklidir</string>
```

