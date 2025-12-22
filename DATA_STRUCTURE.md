# مستندات ساختار داده‌ها (Data Structure Documentation)

این سند ساختار پایگاه داده، فرمت فایل‌های پشتیبان و استراتژی مدیریت تغییرات (Migration) در اپلیکیشن Flow را توضیح می‌دهد.

## 1. ساختار پایگاه داده (Database Schema)

اپلیکیشن از SQLite برای ذخیره‌سازی داده‌ها استفاده می‌کند. جداول اصلی عبارتند از:

### جدول `tasks` (وظایف)
اطلاعات مربوط به وظایف و کارهای برنامه‌ریزی شده.

| ستون | نوع داده | توضیحات |
| --- | --- | --- |
| `id` | INTEGER | شناسه یکتا (Primary Key, Auto Increment) |
| `title` | TEXT | عنوان وظیفه |
| `description` | TEXT | توضیحات تکمیلی |
| `dueDate` | TEXT | تاریخ سررسید (ISO 8601 String) |
| `status` | INTEGER | وضعیت (0: Pending, 1: Success, ...) |
| `priority` | INTEGER | اولویت (0: Low, 1: Medium, 2: High) |
| `categories` | TEXT | لیست دسته‌بندی‌ها (JSON String) |
| `taskEmoji` | TEXT | ایموجی اختصاصی وظیفه |
| `attachments` | TEXT | مسیر فایل‌های پیوست شده (JSON String) |
| `recurrence` | TEXT | تنظیمات تکرار وظیفه (JSON String) |
| `createdAt` | TEXT | تاریخ ایجاد |
| `position` | INTEGER | موقعیت برای مرتب‌سازی |

### جدول `categories` (دسته‌بندی‌ها)
اطلاعات دسته‌بندی‌های وظایف.

| ستون | نوع داده | توضیحات |
| --- | --- | --- |
| `id` | TEXT | شناسه متنی یکتا (Primary Key) |
| `label` | TEXT | نام نمایش داده شده |
| `emoji` | TEXT | ایموجی دسته‌بندی |
| `color` | INTEGER | کد رنگ (ARGB Integer) |
| `position` | INTEGER | موقعیت برای مرتب‌سازی |

### جدول `task_completions` (تکمیل وظایف)
تاریخچه وضعیت وظایف تکرار شونده در روزهای مختلف.

| ستون | نوع داده | توضیحات |
| --- | --- | --- |
| `id` | INTEGER | شناسه یکتا |
| `taskId` | INTEGER | شناسه وظیفه مربوطه (Foreign Key) |
| `date` | TEXT | تاریخ وضعیت (YYYY-MM-DD) |
| `status` | INTEGER | وضعیت در آن تاریخ |

---

## 2. استراتژی نسخه‌بندی و تغییرات (Versioning & Migration)

برای اطمینان از اینکه آپدیت‌های آینده باعث از دست رفتن اطلاعات نمی‌شوند، از سیستم نسخه‌بندی داخلی SQLite استفاده می‌شود.

### قوانین توسعه:
1. **هرگز** ستون‌های موجود را حذف یا تغییر نام ندهید مگر اینکه کاملاً ضروری باشد و اسکریپت انتقال (Migration Script) دقیقی بنویسید.
2. برای اضافه کردن ویژگی جدید، همیشه ستون جدید اضافه کنید و مقدار پیش‌فرض (Default Value) مناسب داشته باشید.
3. در فایل `database_service.dart`، متغیر `version` را افزایش دهید و منطق تغییرات را در متد `_onUpgrade` اضافه کنید.

### نمونه کد Migration:
```dart
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    // اضافه کردن ستون جدید بدون حذف داده‌های قبلی
    await db.execute('ALTER TABLE tasks ADD COLUMN new_column TEXT');
  }
  // ... سایر نسخه‌ها
}
```

---

## 3. فرمت فایل پشتیبان (Export/Import Format)

فایل‌های پشتیبان با فرمت JSON ذخیره می‌شوند و شامل تمام جداول هستند. این ساختار مستقل از نسخه دیتابیس طراحی شده تا قابلیت جابجایی داشته باشد.

### ساختار JSON:
```json
{
  "version": 1,
  "timestamp": "2023-10-27T10:00:00.000Z",
  "tasks": [
    {
      "id": 1,
      "title": "Task Title",
      ...
    }
  ],
  "categories": [
    {
      "id": "work",
      "label": "Work",
      ...
    }
  ],
  "completions": [
    {
      "taskId": 1,
      "date": "2023-10-27",
      "status": 1
    }
  ]
}
```

هنگام وارد کردن اطلاعات (Import)، داده‌های فعلی پاک شده و داده‌های موجود در فایل JSON جایگزین می‌شوند.
