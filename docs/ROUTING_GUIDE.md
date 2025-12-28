# راهنمای مسیریابی صفحه جستجو

این راهنما نحوه استفاده از سیستم مسیریابی برای دسترسی به صفحه جستجو با فیلترها و پارامترهای مختلف را توضیح می‌دهد.

## فرمت کلی URL

```
/search?[پارامترها]
```

## پارامترهای موجود

### پارامترهای جستجو

| پارامتر | نوع | توضیحات | مثال |
|---------|-----|---------|------|
| `q` | string | متن جستجو (در title، description، tags و categories) | `q=خواب` |
| `cat` | string (comma-separated) | ID دسته‌بندی‌ها (چند انتخابی) | `cat=cat1,cat2` |
| `tag` | string (comma-separated) | تگ‌ها (چند انتخابی) | `tag=مهم,فوری` |
| `dateFrom` | date (YYYY-MM-DD) | تاریخ شروع بازه | `dateFrom=2024-01-01` |
| `dateTo` | date (YYYY-MM-DD) | تاریخ پایان بازه | `dateTo=2024-12-31` |
| `priority` | enum | اولویت (low, medium, high) | `priority=high` |
| `status` | enum | وضعیت (pending, success, failed, cancelled, deferred) | `status=pending` |
| `recurring` | boolean | تسک‌های تکرار شونده (true/false) | `recurring=true` |
| `sort` | enum | مرتب‌سازی (dateAsc, dateDesc, priorityAsc, priorityDesc, createdAtAsc, createdAtDesc, titleAsc, titleDesc, manual) | `sort=dateDesc` |
| `view` | enum | استایل نمایش (list, card) | `view=list` |

## مثال‌های استفاده

### مثال ۱: جستجوی ساده
```
/search?q=خواب
```
جستجوی تسک‌هایی که کلمه "خواب" در عنوان، توضیحات، تگ‌ها یا دسته‌بندی‌هایشان وجود دارد.

### مثال ۲: جستجو با دسته‌بندی
```
/search?q=خواب&cat=cat-development
```
جستجوی تسک‌هایی با کلمه "خواب" در دسته‌بندی "توسعه فردی" (با ID: cat-development).

### مثال ۳: جستجو با چند دسته‌بندی و تگ
```
/search?q=خواب&cat=cat-development,cat-health&tag=مهم
```
جستجوی تسک‌هایی با کلمه "خواب" در دسته‌بندی‌های "توسعه فردی" یا "سلامت" و دارای تگ "مهم".

### مثال ۴: فیلتر بر اساس بازه تاریخی
```
/search?dateFrom=2024-01-01&dateTo=2024-12-31&priority=high
```
تسک‌های با اولویت بالا در بازه زمانی مشخص شده.

### مثال ۵: فیلتر بر اساس وضعیت و نوع
```
/search?status=pending&recurring=false&sort=dateAsc
```
تسک‌های در جریان و غیر تکرار شونده، مرتب شده بر اساس تاریخ (قدیمی به جدید).

### مثال ۶: ترکیب کامل
```
/search?q=خواب&cat=cat-development&tag=مهم&dateFrom=2024-01-01&dateTo=2024-12-31&priority=high&status=pending&sort=dateDesc&view=card
```
ترکیب کامل همه فیلترها با نمایش به صورت کارت.

## استفاده در کد Dart/Flutter

### ساخت URL با استفاده از RouteBuilder

```dart
import 'package:go_router/go_router.dart';
import 'package:your_app/utils/route_builder.dart';
import 'package:your_app/models/task.dart';
import 'package:your_app/services/search_service.dart';

// مثال ۱: جستجوی ساده
final url1 = SearchRouteBuilder.buildSearchUrl(
  query: 'خواب',
);

// مثال ۲: جستجو با فیلترها
final url2 = SearchRouteBuilder.buildSearchUrl(
  query: 'خواب',
  categories: ['cat-development'],
  tags: ['مهم'],
  priority: TaskPriority.high,
  status: TaskStatus.pending,
  sortOption: SortOption.dateDesc,
  viewStyle: ViewStyle.list,
);

// مثال ۳: فقط فیلتر بدون جستجو
final url3 = SearchRouteBuilder.buildSearchUrl(
  categories: ['cat-development', 'cat-health'],
  dateFrom: DateTime(2024, 1, 1),
  dateTo: DateTime(2024, 12, 31),
);

// استفاده در navigation
context.go(url1);
// یا
context.push(url2);
```

### پارس کردن پارامترها از URL

```dart
import 'package:go_router/go_router.dart';
import 'package:your_app/utils/route_builder.dart';

// دریافت پارامترها از route
final queryParams = GoRouterState.of(context).uri.queryParameters;
final params = SearchRouteBuilder.parseSearchParams(queryParams);

// استفاده از پارامترها
if (params.query != null) {
  print('Query: ${params.query}');
}
if (params.categories != null) {
  print('Categories: ${params.categories}');
}
```

## استفاده در Notifications

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:your_app/utils/route_builder.dart';

// ساخت notification با deep link
final notificationDetails = NotificationDetails(
  // ... سایر تنظیمات
);

final url = SearchRouteBuilder.buildSearchUrl(
  query: 'خواب',
  categories: ['cat-development'],
);

await flutterLocalNotificationsPlugin.show(
  0,
  'تسک‌های مرتبط با خواب',
  'برای مشاهده کلیک کنید',
  notificationDetails,
  payload: url, // URL به عنوان payload
);

// در handler notification:
void onNotificationTap(String? payload) {
  if (payload != null) {
    context.go(payload);
  }
}
```

## استفاده در دکمه‌ها

```dart
import 'package:go_router/go_router.dart';
import 'package:your_app/utils/route_builder.dart';

ElevatedButton(
  onPressed: () {
    final url = SearchRouteBuilder.buildSearchUrl(
      query: 'خواب',
      categories: ['cat-development'],
    );
    context.go(url);
  },
  child: Text('مشاهده تسک‌های خواب'),
)
```

## استفاده از خارج از اپ

### Android (Deep Links)

در `android/app/src/main/AndroidManifest.xml`:

```xml
<activity
    android:name=".MainActivity"
    ...>
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data
            android:scheme="flow"
            android:host="search" />
    </intent-filter>
</activity>
```

سپس می‌توانید از URL های زیر استفاده کنید:
```
flow://search?q=خواب&cat=cat-development
```

### iOS (Universal Links)

در `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>flow</string>
        </array>
    </dict>
</array>
```

### Web

برای استفاده در وب، می‌توانید از URL های کامل استفاده کنید:
```
https://your-app.com/search?q=خواب&cat=cat-development
```

## نکات مهم

1. **Encoding**: پارامترهای فارسی به صورت خودکار encode می‌شوند. نیازی به encode دستی نیست.

2. **مقادیر پیش‌فرض**: اگر پارامتری ارسال نشود، از مقادیر پیش‌فرض استفاده می‌شود:
   - `sort`: `dateDesc`
   - `view`: `list`

3. **چند انتخابی**: برای دسته‌بندی و تگ‌ها، می‌توانید چند مقدار را با کاما جدا کنید.

4. **تاریخ**: فرمت تاریخ باید `YYYY-MM-DD` باشد (میلادی).

5. **مقادیر enum**: مقادیر enum باید دقیقاً مطابق با مقادیر تعریف شده باشند (case-sensitive).

## مثال کامل: استفاده در یک صفحه

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:your_app/utils/route_builder.dart';
import 'package:your_app/models/task.dart';
import 'package:your_app/services/search_service.dart';

class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // جستجوی تسک‌های خواب در دسته‌بندی توسعه فردی
                final url = SearchRouteBuilder.buildSearchUrl(
                  query: 'خواب',
                  categories: ['cat-development'],
                  sortOption: SortOption.dateDesc,
                  viewStyle: ViewStyle.list,
                );
                context.go(url);
              },
              child: Text('مشاهده تسک‌های خواب'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // فیلتر تسک‌های فوری در جریان
                final url = SearchRouteBuilder.buildSearchUrl(
                  priority: TaskPriority.high,
                  status: TaskStatus.pending,
                );
                context.go(url);
              },
              child: Text('تسک‌های فوری در جریان'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## پشتیبانی

برای سوالات یا مشکلات، لطفاً با تیم توسعه تماس بگیرید.

