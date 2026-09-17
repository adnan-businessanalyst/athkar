# أذكار

تطبيق عربي لمواقيت الصلاة، الأذان، الأذكار، وعداد التسبيح — لسطح المكتب (Windows و macOS) والجوال.

**الموقع:** https://athkar.ghurabi.com  
**واجهة البرمجة:** https://api.athkar.ghurabi.com  
**سياسة الخصوصية:** https://athkar.ghurabi.com/privacy

## التشغيل

**Windows**

```bash
flutter pub get
flutter run -d windows
```

**macOS** (على جهاز Mac)

```bash
flutter pub get
flutter run -d macos
```

**بناء نسخة للتوزيع**

```bash
flutter build windows
flutter build macos
```

- Windows: `build/windows/x64/runner/Release/athkar.exe`
- macOS: `build/macos/Build/Products/Release/Athkar.app`

بناء macOS يحتاج Xcode على جهاز Mac. بناء Windows يحتاج Visual Studio مع عبء **Desktop development with C++**.

## المميزات

- مواقيت الصلاة حسب الموقع (جهاز أو مدينة أو إحداثيات)
- أذان عند دخول الوقت
- عدّادات مسماة متعددة يُحفظ عددها
- قوائم أذكار أساسية فارغة يمكن تعبئتها، أو قوائم مخصصة مع تذكير يومي

## ملف الأذان

1. داخل التطبيق: **الإعدادات → ملف الأذان**
2. أو انسخ الملف إلى `assets/audio/adhan.mp3` ثم أعد التشغيل

مصدر عام: [Wikimedia Commons — Audio files of Adhan](https://commons.wikimedia.org/wiki/Category:Audio_files_of_Adhan)
