# Design Language & Nuances: Project Flow

This document outlines the design language, stylistic nuances, and software design principles used in **Project Flow**. It serves as a comprehensive guide for developers to maintain and extend the software while ensuring a seamless and consistent user experience.

---

## 1. Design Philosophy
Project Flow is designed with a **Modern, Material 3, Persian-first** approach. The goal is to provide a productivity experience that feels "fluid," premium, and culturally tailored for Persian-speaking users.

- **Fluidity**: Smooth transitions, micro-animations, and soft visuals.
- **Premium Aesthetics**: High-quality iconography, purposeful use of color, and refined typography.
- **Cultural Focus**: Native support for Jalali (Shamsi) calendar, RTL (Right-to-Left) layouts, and stylistic Persian typography.

---

## 2. Visual Foundation

### Color System
The app uses a dynamic color system seeded from a primary brand color.
- **Seed Color**: Default is `Deep Purple (#6750A4)`, but users can choose from a curated palette (Indidgo, Blue, Green, Teal, Gold, Orange, Pink).
- **Brightness**: Full support for **Light** and **Dark** modes. Dark mode is prioritized for "Focus" sessions.
- **Status Colors**:
  - **Success / Done**: `Green` (specifically `Colors.greenAccent` in charts).
  - **Pending / In Progress**: Primary seed color.
  - **Failed**: `Red` (specifically `Colors.redAccent` in charts).
  - **Cancelled / Neutral**: `Grey` / `onSurfaceVariant`.
  - **Deferred**: `Orange / OrangeAccent`.
- **Priority Styles**:
  - **High**: `errorContainer` / `onErrorContainer` (Soft red/pink).
  - **Medium**: `surfaceContainerLow` / `onSurface` (Neutral).
  - **Low**: Green (alpha 0.1) / `green.shade800`.

### Typography
- **Primary Font**: `IRANSansX`.
- **Nuance - Persian Digits**: The app uses `FontFeature.enable('ss01')` to ensure stylistic Persian digits match the brand's aesthetic.
- **Nuance - Tabular Figures**: `FontFeature.tabularFigures()` is used in reports and time-related UI for vertical alignment of digits.
- **Sizing**:
  - Display titles: Bold/Extra-bold (Weight 800-900).
  - Semantic labels: Medium weight (Weight 500-600).
  - Body: Regular (Weight 400).

---

## 3. UI Components & Layout Patterns

### Cards (The Core Unit)
- **Shape**: `RoundedRectangleBorder` with a radius of **20.0**.
- **Border**: A subtle 1px border with `alpha: 0.1` of the foreground color.
- **Elevation**: Always `0` for a flat, modern "Material 3" look.
- **Interactive Nuance**: Task cards use `InkWell` with the same radius for ripple effects. Long-pressing the status icon triggers a quick-switch sheet with haptic feedback.

### Bottom Sheets
- **Radius**: Top corners use a radius of **28.0**.
- **Handle**: A consistent top handle (`40x4`, pinned center, `outlineVariant` color).
- **Behavior**: Always `isScrollControlled: true` to support expanding content and keyboard interaction.
- **Header Pattern**: Usually follows a "Handle -> Icon + Title -> Close Button" layout.

### Picker Options (Sheet Items)
- **Design**: Used in Reminder and Recurrence sheets for individual options.
- **Radius**: `16.0`.
- **Selected State**: 
  - Background: `primary.withValues(alpha: 0.08)`.
  - Border: `primary.withValues(alpha: 0.2)` with `1.5` thickness.
  - Color: `primary` for icon, text, and trailing checkmark.
- **Unselected State**: Transparent background/border, `onSurfaceVariant` icon, `onSurface` text.
- **Animation**: `AnimatedContainer` with `200ms` duration for smooth selection feedback.
- **Layout**: Leading Icon -> Spacing -> Expanded Label -> Trailing Checkmark (if selected).

### Action Items (Sheet Buttons)
- **Design**: Used for "Custom" or "Manual" selection entries in sheets.
- **Layout**: Similar to Picker Options but usually with a `secondary` or `primary` icon container (0.1 alpha) and a trailing arrow (`strokeRoundedArrowLeft01`).
- **Padding**: Consistent `12px` vertical and horizontal padding.
- **Radius**: `16.0`.

### Capsules & Badges
- Used for Categories and Priorities.
- **Design**: Pill-shaped with a background alpha of `0.15` and a 1.5px border of `0.5` alpha.
- **Auto-Scroll**: Long labels or multiple categories in cards auto-scroll horizontally using a linear animation to prevent UI breakage.

### Category Progress Capsules (Reports)
- **Purpose**: To show progress per category in the reports screen with high visual consistency.
- **Design**: Pill-shaped (radius 14) to match the category selection style in the task creation screen.
- **Background System**: 
  - Base: `surfaceContainerHighest` with `0.3` alpha.
  - Progress Layer: A `FractionallySizedBox` inside a `Stack` that fills from right to left (RTL) using the category color at `0.15` alpha, acting as a background progress bar.
- **Border**: 1.5px thickness with the category color at `0.5` alpha.
- **Components**:
  - **Leading**: `LottieCategoryIcon` (size 22, non-animated).
  - **Center**: Category label (size 12, bold, category color).
  - **Trailing**: Progress percentage using Persian digits (size 12, extra-bold weight 900, category color).
- **Interaction**: `InkWell` (radius 14) redirects to the search screen filtered by category and current report range.

### Active Links (Streak Visualization)
- **Purpose**: To visually connect consecutive active days (tasks completed or mood logged) in a vertical timeline.
- **Sizes**:
  - **Active Link**: `4.0` width.
  - **Chain Link (Large)**: `12.0` height (used for top/bottom caps).
  - **Chain Link (Small)**: `8.0` height (used for connecting nodes).
- **Theming**: Uses `Theme.of(context).colorScheme.primary` with various alpha levels:
  - Full link: `primary.withValues(alpha: 0.5)`.
  - Cap dots: `primary.withValues(alpha: 0.8)`.
- **Accessibility**: Wrapped in `Semantics` with Persian labels (e.g., "روز فعال", "شروع زنجیره") to describe the continuity of the user's activity.

### FlowToast (Smart Notifications)
- **Purpose**: To provide non-intrusive feedback for actions or errors.
- **Design**: 
  - **Shape**: Rounded corners with a radius of **20.0**.
  - **Background**: `surfaceContainerHighest` with `0.95` alpha and a subtle `0.8` alpha border.
  - **Elevation**: Shadow with `0.1` alpha black, 20 blur, and (0, 8) offset.
- **Animations**: 
  - **Entrance**: Sequential animation using `FadeIn`, `SlideY` (from bottom), and a subtle `Shimmer`.
  - **Micro-interaction**: Icons use an `ElasticOut` scale animation to feel "alive."
- **Behavior**: Global usage via `FlowToast.show(context, message: '...', type: FlowToastType.info)`.

### Navigation
- **Top Bar**:
  - Height: `60.0`.
  - Centered title with extra bold weight (`w800`).
  - Uses `flow-prm.svg` as a brand identifier.
- **Bottom Bar**:
  - Height: `70.0`.
  - Simple, clean labels (`fontSize: 9`).
  - Active state uses `theme.colorScheme.primary`.

---

## 4. Iconography & Assets

### HugeIcons
The app standardizes on the **HugeIcons** set (Stroke Rounded style).
- Standard icon size: `24.0`.
- Small/Internal icon size: `18.0` or `20.0`.

### Lottie Animations
- **Category Icons**: Every category is represented by a Lottie animation (`lottie_category_icon.dart`).
- **Empty States**: High-quality "The Soul" series Lottie animations (e.g., `24 news b.json`).
- **Micro-interactions**: Subtle triggers when checking off tasks.

---

## 5. Motion & Transitions

### Sequential Animations
Elements in reports and lists enter the screen sequentially using `FadeInOnce`.
- **Default Delay**: Increases by `100ms` per item (capped at `200ms` for performance).
- **Custom Effects**: Combines `Fade`, `SlideY` (0.08 offset), and `Blur`.

### Power Saving Mode
A unique UX nuance: if "Power Saving" is enabled in settings, advanced animations (Slide, Blur, Scale) are disabled, leaving only a simple `FadeIn` for performance and battery efficiency.

### Page Transitions
The app uses `NoTransitionPage` via GoRouter for most routes to provide an "instant" web-like speed feel, while relying on internal widget animations for visual interest.

---

## 6. Software Design Nuances

### Persian / RTL Support
- **Directionality**: Forced `TextDirection.rtl` in many custom layouts like task headers and option sheets.
- **Jalali Calendar**: Native integration of `persian_datetime_picker` and Jalali formatting strings.
- **Persian Digits Utility**: A shared `_toPersianDigit` helper is used across screens to ensure consistency.

### Haptic Feedback
- **Medium/Heavy Impact**: Used during critical actions like status changes, long-presses, and deletions.

### Glassmorphism & Gradients
- **Gradients**: Linear gradients with `stops: [0, 0.6, 1.0]` are used at the top and bottom of reports to create a "floating" content effect over the navigation elements.
- **Surface Tints**: Surfaces use `surfaceTint` at elevation `3` to distinguish layers without hard shadows.

---

## 7. Development Rules
- **Radius Rule**: Use `12.0` for sub-components (buttons, chips), `20.0` for cards, and `28.0` for containers/sheets.
- **Padding Rule**: Standard padding is `16.0`. Large headers use `24.0`.
- **Divider Rule**: Use `thickness: 0.5` for a sharp, clean look.
- **Icon Rule**: Always use `HugeIcons.strokeRounded...` versions.
- **Text Rule**: Always wrap digits displayed to the user with the Persian digit conversion logic.

---

## 8. Software Architecture Nuances

### Temporal State Management
Unlike traditional apps that have a single `status` field, Project Flow treats status as **temporal**.
- **`statusHistory`**: A Map (`{ "YYYY-MM-DD": statusIndex }`) that tracks the state of a task on any given day.
- **Nuance**: A single task ID can have different statuses (e.g., "Done" on Monday, "Failed" on Tuesday) if it is a recurring task.

### Soft Delete & Persistence
- **Soft Delete**: Tasks are never immediately removed from the database; they are marked with `isDeleted: 1` and `deletedAt`. This allows for "Reports" to accurately reflect historical data even for deleted tasks.
- **Midnight Updates**: A background service (`MidnightTaskUpdater`) runs at 00:00 to refresh task providers and mark yesterday's pending tasks as "Failed" if they weren't completed.

### Event Logging
- **Immutable History**: Every significant action (status change, postpone, duplicate) is logged in the `task_events` table with a human-readable Persian message. This ensures the app's history is auditable and recoverable.

### Notifications & Reminders
- **Service**: Powered by `flutter_local_notifications` with timezone-aware scheduling.
- **Behavior**:
  - Reminders are automatically scheduled when a task is created or updated with a `reminderDateTime`.
  - Notifications are automatically cancelled when a task is marked as "Done" or "Cancelled".
  - If a task is uncompleted, the reminder is automatically rescheduled.
  - Notifications are cancelled when a task is soft-deleted.
- **Visuals**:
  - Uses the app icon for notification small icon.
  - Channels are categorized for importance (e.g., Task Reminders).

### Localization Strategy
- **Centralized Logic**: Persian digit conversion and Jalali formatting are centralized in `string_utils.dart` and `reports_screen.dart` to ensure the entire UI remains consistent. Avoid hardcoding English digits in user-facing strings.
- **RTL Integrity**: Layouts are tested specifically for RTL overflow. Avoid using `Padding.left/right`; always use `Padding.start/end` (or `paddingDirectional`).
