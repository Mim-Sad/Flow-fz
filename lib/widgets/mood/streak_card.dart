import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../providers/mood_provider.dart';

class StreakCard extends StatelessWidget {
  final MoodState moodState;

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
        borderRadius: BorderRadius.circular(28),
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
                'روزهای متوالی',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFamily: 'IRANSansX',
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
              const HugeIcon(
                icon: HugeIcons.strokeRoundedCalendar02,
                size: 20,
                color: Colors.amber,
              ),
              const SizedBox(width: 4),
              Text(
                'طولانی‌ترین زنجیره: ',
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
            top: 19,
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
              // In RTL, the next item (index + 1) is to the left
              final hasNextMood = index < 6 && _hasMoodOnDay(lastSeven[index + 1]);
              final showLine = index < 6;
              final isLineActive = hasMood && hasNextMood;

              return Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        if (showLine)
                          Positioned(
                            right: 20, // Center of circle
                            left: -20, // Center of next circle (approx)
                            top: 19,
                            child: Container(
                              height: 2,
                              color: isLineActive 
                                ? colorScheme.primary 
                                : Colors.transparent,
                            ),
                          ),
                        Container(
                          width: 38,
                          height: 38,
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
                                    color: theme.colorScheme.onPrimary,
                                    size: 18,
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
                      isToday ? 'امروز' : _getFormattedDate(date),
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
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCounter(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedFire03,
            color: colorScheme.primary,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            _toPersianDigit(moodState.currentStreak.toString()),
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w900,
              fontFamily: 'IRANSansX',
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'روز',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w500,
              fontFamily: 'IRANSansX',
            ),
          ),
        ],
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
