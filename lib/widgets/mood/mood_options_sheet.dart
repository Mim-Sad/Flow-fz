import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:intl/intl.dart' as intl;
import '../../models/mood_entry.dart';
import '../../models/activity.dart';
import '../../providers/mood_provider.dart';
import 'add_mood_sheet.dart';

class MoodOptionsSheet extends ConsumerWidget {
  final MoodEntry entry;
  final List<Activity> allActivities;

  const MoodOptionsSheet({
    super.key,
    required this.entry,
    required this.allActivities,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final moodInfo = _getMoodInfo(entry.moodLevel);
    
    final entryActivities = allActivities.where((a) => entry.activityIds.contains(a.id)).toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle Line
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mood Info Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: (moodInfo['color'] as Color).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                moodInfo['icon'] as String,
                                style: const TextStyle(fontSize: 26),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'مود ثبت شده: ${moodInfo['label']}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textDirection: TextDirection.rtl,
                                  ),
                                  const SizedBox(height: 4),
                                  _buildParenthesesStyledText(
                                    _formatDate(entry.dateTime),
                                    theme.textTheme.bodySmall!.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        if (entry.note != null && entry.note!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(height: 1, thickness: 0.5),
                          const SizedBox(height: 16),
                          Text(
                            entry.note!,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                              height: 1.6,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ],

                        if (entryActivities.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Divider(height: 1, thickness: 0.5),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            textDirection: TextDirection.rtl,
                            children: entryActivities.map((activity) {
                              final color = moodInfo['color'] as Color;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    _buildIconOrEmoji(
                                      _getIconData(activity.iconName),
                                      color: color,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      activity.name,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Actions List
                  Column(
                    children: [
                      _buildActionTile(
                        context,
                        icon: HugeIcons.strokeRoundedEdit02,
                        label: 'ویرایش مود',
                        onTap: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            useSafeArea: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => AddMoodSheet(entry: entry),
                          );
                        },
                      ),
                      _buildActionTile(
                        context,
                        icon: HugeIcons.strokeRoundedDelete02,
                        label: 'حذف مود',
                        isDestructive: true,
                        onTap: () {
                          _showDeleteConfirmation(context, ref);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف مود', textAlign: TextAlign.right),
        content: const Text(
          'آیا از حذف این مود اطمینان دارید؟ این عمل قابل بازگشت نیست.',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              ref.read(moodProvider.notifier).deleteMood(entry.id!);
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close sheet
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Widget _buildParenthesesStyledText(
    String text,
    TextStyle baseStyle, {
    TextAlign textAlign = TextAlign.right,
    TextDirection textDirection = TextDirection.rtl,
  }) {
    final List<TextSpan> spans = [];
    final RegExp regExp = RegExp(r'(^.*?:)|\((.*?)\)');
    int lastIndex = 0;

    for (final Match match in regExp.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      final labelMatch = match.group(1);
      final parenContentMatch = match.group(2);

      if (labelMatch != null) {
        spans.add(
          TextSpan(
            text: labelMatch,
            style: baseStyle.copyWith(
              color: baseStyle.color?.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      } else if (match.group(0)!.startsWith('(')) {
        final styledParenStyle = baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 13) * 0.85,
          color: baseStyle.color?.withValues(alpha: 0.5),
          fontWeight: FontWeight.w400,
        );

        spans.add(TextSpan(text: '(', style: styledParenStyle));
        spans.add(TextSpan(text: parenContentMatch, style: styledParenStyle));
        spans.add(TextSpan(text: ')', style: styledParenStyle));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }

    if (spans.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        textAlign: textAlign,
        textDirection: textDirection,
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
      textDirection: textDirection,
    );
  }

  String _toPersianDigit(String input) {
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    String result = input;
    for (int i = 0; i < englishDigits.length; i++) {
      result = result.replaceAll(englishDigits[i], persianDigits[i]);
    }
    return result;
  }

  String _formatJalali(Jalali j) {
    String weekday = j.formatter.wN;
    if (weekday == 'یک شنبه') weekday = 'یک‌شنبه';
    if (weekday == 'دو شنبه') weekday = 'دو‌شنبه';
    if (weekday == 'سه شنبه') weekday = 'سه‌شنبه';
    if (weekday == 'چهار شنبه') weekday = 'چهار‌شنبه';
    if (weekday == 'پنج شنبه') weekday = 'پنج‌شنبه';
    return _toPersianDigit('$weekday ${j.day} ${j.formatter.mN} ${j.year}');
  }

  String _formatDate(DateTime date) {
    final jDate = Jalali.fromDateTime(date);
    final now = Jalali.now();
    final timeStr = _toPersianDigit(intl.DateFormat('HH:mm').format(date));

    if (jDate.year == now.year &&
        jDate.month == now.month &&
        jDate.day == now.day) {
      return 'امروز (${_formatJalali(jDate)}) • ساعت $timeStr';
    }

    final tomorrow = now.addDays(1);
    if (jDate.year == tomorrow.year &&
        jDate.month == tomorrow.month &&
        jDate.day == tomorrow.day) {
      return 'فردا (${_formatJalali(jDate)}) • ساعت $timeStr';
    }

    return '${_formatJalali(jDate)} • ساعت $timeStr';
  }

  Widget _buildActionTile(
    BuildContext context, {
    required dynamic icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final color = isDestructive ? Colors.red : theme.colorScheme.onSurface;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: HugeIcon(icon: icon, size: 20, color: color),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        textAlign: TextAlign.right,
      ),
      trailing: Icon(
        Icons.chevron_left,
        size: 18,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _buildIconOrEmoji(dynamic iconData, {required double size, Color? color}) {
    if (iconData is String) {
      return Text(iconData, style: TextStyle(fontSize: size));
    }
    return HugeIcon(icon: iconData, size: size, color: color);
  }

  dynamic _getIconData(String name) {
    if (!name.startsWith('strokeRounded')) return name;
    switch (name) {
      case 'strokeRoundedFavourite':
        return HugeIcons.strokeRoundedFavourite;
      case 'strokeRoundedGameController02':
        return HugeIcons.strokeRoundedGameController02;
      case 'strokeRoundedSleep':
        return HugeIcons.strokeRoundedTick02;
      case 'strokeRoundedHealth':
        return HugeIcons.strokeRoundedHealth;
      case 'strokeRoundedHappy':
        return HugeIcons.strokeRoundedSent;
      case 'strokeRoundedEnergy':
        return HugeIcons.strokeRoundedFlash;
      case 'strokeRoundedGiveLove':
        return HugeIcons.strokeRoundedFavourite;
      case 'strokeRoundedMoon02':
        return HugeIcons.strokeRoundedMoon02;
      case 'strokeRoundedBored':
        return HugeIcons.strokeRoundedNote01;
      case 'strokeRoundedBubbleChatDelay':
        return HugeIcons.strokeRoundedBubbleChatDelay;
      case 'strokeRoundedAngry':
        return HugeIcons.strokeRoundedAlertCircle;
      case 'strokeRoundedSad01':
        return HugeIcons.strokeRoundedSent;
      case 'strokeRoundedGameController03':
        return HugeIcons.strokeRoundedGameController03;
      case 'strokeRoundedClapperboard':
        return HugeIcons.strokeRoundedPlay;
      case 'strokeRoundedBookOpen01':
        return HugeIcons.strokeRoundedBookOpen01;
      case 'strokeRoundedAirplane01':
        return HugeIcons.strokeRoundedAirplane01;
      case 'strokeRoundedMusicNote01':
        return HugeIcons.strokeRoundedMusicNote01;
      case 'strokeRoundedCheers':
        return HugeIcons.strokeRoundedStar;
      case 'strokeRoundedAlert02':
        return HugeIcons.strokeRoundedAlert02;
      case 'strokeRoundedRunning':
        return HugeIcons.strokeRoundedStar;
      case 'strokeRoundedOrganicFood':
        return HugeIcons.strokeRoundedApple;
      case 'strokeRoundedWaterDrop':
        return HugeIcons.strokeRoundedDroplet;
      case 'strokeRoundedWalking':
        return HugeIcons.strokeRoundedUser;
      default:
        return HugeIcons.strokeRoundedStar;
    }
  }

  Map<String, dynamic> _getMoodInfo(MoodLevel level) {
    switch (level) {
      case MoodLevel.rad:
        return {'label': 'عالی', 'color': Colors.green, 'icon': '🤩'};
      case MoodLevel.good:
        return {'label': 'خوب', 'color': Colors.lightGreen, 'icon': '😊'};
      case MoodLevel.meh:
        return {'label': 'معمولی', 'color': Colors.amber, 'icon': '😐'};
      case MoodLevel.bad:
        return {'label': 'بد', 'color': Colors.orange, 'icon': '☹️'};
      case MoodLevel.awful:
        return {'label': 'خیلی بد', 'color': Colors.red, 'icon': '😫'};
    }
  }
}
