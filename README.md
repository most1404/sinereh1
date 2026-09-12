# V2Ray Smart App

اپلیکیشن اندروید (Flutter) برای مدیریت کانفیگ‌های V2Ray/Xray:
- پشتیبانی **چند ساب‌اسکریپشن** همزمان (افزودن/حذف/بروزرسانی هرکدام جدا)
- دریافت خودکار و دوره‌ای هر ساب‌اسکریپشن (vmess/vless/trojan/ss)
- **تفکیک برنامه‌ها**: انتخاب اینکه کدام اپ‌های نصب‌شده از تونل VPN رد نشوند
- تست پینگ همه‌ی سرورها و اتصال به سریع‌ترین با یک دکمه‌ی پاور بزرگ
- حین اتصال، هر چند ثانیه (قابل‌تنظیم، پیش‌فرض ۱ دقیقه) دوباره پینگ می‌گیرد و
  در صورت پیدا شدن سرور سریع‌تر، خودکار به آن جابجا می‌شود
- ظاهر تیره با فونت وزیرمتن و لوگوی اختصاصی

از پکیج فعال و به‌روز [`flutter_v2ray_client`](https://pub.dev/packages/flutter_v2ray_client)
استفاده شده که هسته‌ی واقعی Xray را داخل خودش دارد — نیازی به کامپایل
جداگانه‌ی Go/gomobile نیست.

## اگر دکمه‌ی اتصال کار نکرد یا سرور انتخاب نشد

روی نسخه‌ی جدید، اگر اتصال به هر دلیلی شکست بخورد، یک پنجره‌ی خطا با متن
دقیق مشکل باز می‌شود (نه فقط یک پیام کوتاه پایین صفحه). لطفاً همان متن
دقیق خطا را برام بفرست تا مشکل را پیدا کنم — بدون آن متن، حدس زدن علت
تقریباً غیرممکنه.


## پیش‌نیازها

- نصب [Flutter SDK](https://docs.flutter.dev/get-started/install) (کانال stable)
- Android Studio یا حداقل Android SDK + یک دستگاه/شبیه‌ساز اندروید 7 (API 24) به بالا

## راه‌اندازی

```bash
# 1) وارد پوشه‌ی پروژه شو
cd v2ray_smart_app

# 2) وابستگی‌ها را نصب کن (این مرحله نیاز به اینترنت دارد)
flutter pub get

# 3) روی گوشی/شبیه‌ساز وصل‌شده اجرا کن
flutter run

# یا برای گرفتن apk نهایی:
flutter build apk --release
```

فایل خروجی در مسیر `build/app/outputs/flutter-apk/app-release.apk` قرار می‌گیرد.

## تنظیمات مهم Android قبل از انتشار در Google Play

طبق مستندات خودِ پکیج، این دو مورد را قبل از ریلیز رعایت کن:

**`android/gradle.properties`** — این خط را اضافه کن:
```
android.bundle.enableUncompressedNativeLibs=false
```

**`android/app/build.gradle`** — بلاک `buildTypes` را با این جایگزین کن تا
حجم apk کمتر شود و با چند معماری CPU سازگار بماند:
```gradle
splits {
    abi {
        enable true
        reset()
        include "x86_64", "armeabi-v7a", "arm64-v8a"
        universalApk true
    }
}

buildTypes {
    release {
        signingConfig signingConfigs.release
        ndk {
            abiFilters "x86_64", "armeabi-v7a", "arm64-v8a"
            debugSymbolLevel 'FULL'
        }
    }
}
```

## نحوه‌ی استفاده در اپ

1. روی آیکون 🔗 (بالای صفحه) بزن و از «افزودن ساب» یک یا چند لینک
   ساب‌اسکریپشن اضافه کن. هرکدام را می‌توانی جدا حذف یا بروزرسانی کنی.
2. در صفحه‌ی اصلی، روی دکمه‌ی پاور بزرگ بزن تا به سریع‌ترین سرور وصل شوی،
   یا از «همه» دستی یکی را انتخاب کن.
3. حین اتصال، برنامه خودش **هر ۱ دقیقه (پیش‌فرض، قابل‌تنظیم در تنظیمات از
   ۱۰ ثانیه تا ۲ دقیقه)** پینگ می‌گیرد و اگر سرور سریع‌تری پیدا کند و
   «سوییچ خودکار» روشن باشد، بدون نیاز به دخالت تو جابجا می‌شود.
4. از تنظیمات ⚙️ → «تفکیک برنامه‌ها» می‌توانی مشخص کنی کدام اپ‌های نصب‌شده
   (مثلاً بانک یا اپ‌های داخلی) از تونل VPN رد نشوند و مستقیم به اینترنت
   گوشی وصل بمانند.

## نکته‌ی مهم درباره‌ی «تفکیک برنامه‌ها» روی گیت‌هاب اکشن

فایل لوگو (`assets/images/logo.png`) و پوشه‌ی `assets/` باید حتماً روی
گیت‌هاب آپلود شوند، وگرنه بیلد خطای «فایل asset پیدا نشد» می‌دهد. موقع
آپلود دستی از مرورگر، مسیر زیر را باز کن و فایل `logo.png` را در همان‌جا
بارگذاری کن:
```
github.com/USERNAME/REPO/upload/main/assets/images
```


## نکات فنی / محدودیت‌ها

- **پینگ زنده حین اتصال** با یک تایمر داخل اپ اجرا می‌شود، پس اگر
  اپلیکیشن به‌طور کامل کشته شود (Force Stop)، این چرخه متوقف می‌شود —
  هرچند خودِ اتصال VPN توسط سرویس اندرویدی پکیج (foreground service با
  نوتیفیکیشن) پابرجا می‌ماند. برای بیشتر کاربردها همین کافی است چون اپ
  در پس‌زمینه‌ی معمولی (نه kill شده) باز می‌ماند.
- برای صرفه‌جویی در باتری/داده، حین اتصال فقط سرور فعلی + چند سرور برتر
  (تعداد قابل‌تنظیم در Settings) پینگ می‌شوند، نه کل لیست.
- شناسه‌ی هر سرور همان لینک خام آن است؛ اگر لینک یک سرور در ساب‌اسکریپشن
  عوض شود، به‌عنوان سرور جدید شناخته می‌شود (تاریخچه‌ی پینگ قبلی‌اش از
  بین می‌رود، ولی مشکلی در عملکرد ایجاد نمی‌کند).
- کد برای پروتکل‌های vmess / vless / trojan / ss تست شده (بر اساس
  پارسر خودِ پکیج). اگر ساب‌اسکریپشنت شامل لینک‌های دیگری (مثل
  hysteria2 با فرمت خاص) است، ممکن است نیاز به گسترش لیست
  `_kSupportedSchemes` در `lib/services/subscription_service.dart` باشد.

## بروزرسانی فایل build.yml (برای اسم برنامه و آیکون نصب)

چون آیکون نصب‌شده روی گوشی (launcher icon) و اسم برنامه توی لیست
اپ‌های گوشی از یه فایل تنظیمات اندرویدی میان که موقع بیلد به‌صورت
خودکار ساخته می‌شه، باید محتوای فایل `.github/workflows/build.yml`
رو با این نسخه جایگزین کنی (مستقیم روی گیت‌هاب، با آیکون مداد ویرایشش کن):

```yaml
name: Build APK

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          channel: 'stable'

      - name: Add Android platform files
        run: flutter create --platforms=android .

      - name: Get dependencies
        run: flutter pub get

      - name: Set app display name
        run: sed -i 's/android:label="[^"]*"/android:label="Sinereh VPN"/' android/app/src/main/AndroidManifest.xml

      - name: Generate launcher icon from logo
        run: dart run flutter_launcher_icons

      - name: Build APK
        run: flutter build apk --release

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: app-release-apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

بعد از Commit، دوباره از تب Actions یه بیلد تازه بگیر (Run workflow).
