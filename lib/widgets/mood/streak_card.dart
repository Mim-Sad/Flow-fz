import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../providers/mood_provider.dart';

class StreakCard extends StatelessWidget {
  final MoodState moodState;

  static const double _kTimelineCircleSize = 38.0;
  static const double _kTimelineIconSize = 18.0;
  static const double _kStreakIconSize = 16.0;

  const StreakCard({super.key, required this.moodState});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'روزهای متوالی ثبت مود',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFamily: 'IRANSansX',
                  fontSize: 14,
                ),
              ),
              _buildStreakCounter(context),
            ],
          ),
          const SizedBox(height: 16),
          _buildTimeline(context),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCalendar02,
                size: 20,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 4),
              Text(
                'طولانی‌ترین زنجیره ثبت مود: ',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              Text(
                _toPersianDigit(moodState.longestStreak.toString()),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lastSeven = moodState.lastSevenDays;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Background Line
          Positioned(
            top: _kTimelineCircleSize / 2,
            left: 20,
            right: 20,
            child: Container(
              height: 2,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final date = lastSeven[index];
              final isToday = _isSameDay(date, DateTime.now());
              final hasMood = _hasMoodOnDay(date);
              
              // Connecting line colored if both days have mood
              final hasNextMood = index < 6 && _hasMoodOnDay(lastSeven[index + 1]);
              final showLine = index < 6;
              final isLineActive = hasMood && hasNextMood;

              final dayLabel = isToday ? 'امروز' : _getFormattedDate(date);
              final statusLabel = hasMood ? 'ثبت شده' : 'ثبت نشده';

              return Expanded(
                child: Semantics(
                  label: 'روز $dayLabel: $statusLabel',
                  selected: hasMood,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          if (showLine)
                            Positioned(
                              right: 20,
                              left: -20,
                              top: _kTimelineCircleSize / 2,
                              child: Container(
                                height: 2,
                                color: isLineActive 
                                  ? colorScheme.primary 
                                  : Colors.transparent,
                              ),
                            ),
                          Container(
                            width: _kTimelineCircleSize,
                            height: _kTimelineCircleSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasMood 
                                ? colorScheme.primary 
                                : (colorScheme.surface),
                              border: hasMood 
                                ? null 
                                : Border.all(
                                    color: isToday 
                                      ? colorScheme.primary 
                                      : colorScheme.outlineVariant,
                                    width: 1.5,
                                  ),
                            ),
                            child: Center(
                              child: hasMood
                                  ? HugeIcon(
                                      icon: HugeIcons.strokeRoundedTick02,
                                      color: colorScheme.onPrimary,
                                      size: _kTimelineIconSize,
                                    )
                                  : (isToday
                                      ? Text(
                                          '؟',
                                          style: TextStyle(
                                            color: colorScheme.primary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        dayLabel,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isToday 
                            ? colorScheme.primary 
                            : colorScheme.onSurfaceVariant,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCounter(BuildContext context) {
    final theme = Theme.of(context);
    final streakCount = _toPersianDigit(moodState.currentStreak.toString());

    return Semantics(
      label: 'زنجیره فعلی: $streakCount روز',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedFire03,
              color: Colors.redAccent,
              size: _kStreakIconSize,
            ),
            const SizedBox(width: 6),
            Text(
              streakCount,
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.redAccent,
                fontWeight: FontWeight.w900,
                fontFamily: 'IRANSansX',
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'روز',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.redAccent,
                fontWeight: FontWeight.w500,
                fontFamily: 'IRANSansX',
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  bool _hasMoodOnDay(DateTime date) {
    return moodState.entries.any((e) => _isSameDay(e.dateTime, date));
  }

  String _getFormattedDate(DateTime date) {
    final jalali = Jalali.fromDateTime(date);
    final month = _toPersianDigit(jalali.month.toString());
    final day = _toPersianDigit(jalali.day.toString());
    return '$month/$day';
  }

  String _toPersianDigit(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], persian[i]);
    }
    return input;
  }
}
