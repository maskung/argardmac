# Argard — Personal Weather Station (macOS)

แอพ macOS แบบ native ด้วย **SwiftUI** แปลงจากโปรแกรม Python `argard.py` เดิม
แสดงข้อมูลสถานีอากาศส่วนตัว (PWS) + พยากรณ์อากาศ + คุณภาพอากาศ + เฟสดวงจันทร์ไทย

## ข้อมูลที่ดึง (เหมือน Python เดิม)

| แหล่ง | เนื้อหา |
|---|---|
| Weather.com PWS API | ข้อมูลสดจากสถานี `IMAKHA6` (Makham) — อุณหภูมิ ลม ฝน UV ความกดอากาศ |
| Open-Meteo Forecast | พยากรณ์**รายชั่วโมง** 24 ชม.ข้างหน้า (temp, feels, humid, pop, ฝน, ลม, กดอากาศ, ทัศนวิสัย) |
| Open-Meteo Air Quality | US AQI, PM2.5, PM10 |

## วิธี build / รัน

```bash
cd /Users/suphanutthanyaboon/ClaudProjects/macbook_argard/Argard
./build.sh          # คอมไพล์ด้วย swiftc (ใช้แค่ Command Line Tools)
open build/Argard.app
```

จะได้ `build/Argard.app` — ดับเบิลคลิกรันได้เลย ไม่ต้องขึ้น App Store
(ลากเข้า `Applications` หรือกด Keep in Dock ได้ตามชอบ)

## โครงสร้าง

```
Argard/
├── ArgardApp.swift        # entry point + เมนู/คีย์ลัด
├── ContentView.swift      # โครงหลัก + auto-refresh
├── Models/
│   ├── AppConfig.swift    # อ่าน/สร้าง config.ini + parser
│   └── WeatherModels.swift# Codable ทั้ง 3 API (null-tolerant)
├── Services/
│   ├── WeatherService.swift   # ดึงข้อมูล 3 API
│   ├── WeatherStore.swift     # state กลาง + auto-refresh
│   ├── WeatherDescriptors.swift # คำอธิบาย/สี/emoji (port จาก Python)
│   ├── MoonPhase.swift    # เฟสดวงจันทร์ + ขึ้น/แรม ค่ำ + วันพระ
│   └── SunAndSeason.swift # พระอาทิตย์ขึ้น-ตก + ฤดูกาล
├── Views/
│   ├── Components.swift   # Card / InfoRow / GaugeBar
│   ├── Cards.swift        # การ์ดทั้ง 8 ของ Dashboard
│   ├── DashboardView.swift
│   ├── ForecastView.swift # พยากรณ์ 12 ชม.
│   └── HeaderBar.swift
├── Assets.xcassets/       # ไอคอน + accent color
├── scripts/genicon.swift  # สคริปต์วาดไอคอน (CoreGraphics)
├── Info.plist
└── build.sh
```

## การตั้งค่า

ไฟล์ config อยู่ที่ (สร้างให้อัตโนมัติครั้งแรก — ค่าตั้งต้นตรงกับ config.ini เดิม):

```
~/Library/Application Support/Argard/config.ini
```

แก้ `STATION_ID`, `API_KEY`, `LATITUDE/LONGITUDE`, `REFRESH_SECONDS` ได้
แล้วปิด-เปิดแอพใหม่ (หรือกดปุ่ม refresh — ค่า refresh ต้องเปิดใหม่)

> หมายเหตุ: ตั้งแต่เวอร์ชันนี้ พยากรณ์รายชั่วโมงใช้ Open-Meteo (ไม่ต้องมี key) —
> `API_KEY` ใน section `[OpenWeather]` ไม่ถูกใช้แล้ว เหลือแค่ `LATITUDE/LONGITUDE` ที่ยังใช้อยู่

## คีย์ลัด

- `⌘R` refresh ทันที (ปกติ auto-refresh ทุก 60 วิ ตาม config)
- `⌘1` หน้า Dashboard, `⌘2` หน้าพยากรณ์ 12 ชม. (แทนการกด Enter ใน Python เดิม)

## หมายเหตุการพอร์ต

- สี/เกณฑ์ทุกอย่าง port มาจาก `argard.py` ตรง ๆ (feeling/wind/rain/UV/AQI/solar)
- เวลาพระอาทิตย์ขึ้น-ตก: สูตรเดิม + เพิ่มการแก้ timezone/longitude ให้ตรงเวลาท้องถิ่น
- เฟสดวงจันทร์ใช้ New Moon อ้างอิง 6 ม.ค. 2000 18:14 UTC แบบเดิม (แต่คิดเป็น UTC ถูกต้อง)
# argardmac
