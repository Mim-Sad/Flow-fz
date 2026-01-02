import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:intl/intl.dart' as intl;
import '../../models/mood_entry.dart';
import '../../models/activity.dart';
import 'mood_options_sheet.dart';

class MoodCard extends StatelessWidget {
  final MoodEntry entry;
  final List<Activity> allActivities;

  const MoodCard({
    super.key,
    required this.entry,
    required this.allActivities,
  });

  Widget _buildIconOrEmoji(dynamic iconData, {required double size, Color? color}) {
    if (iconData is String) {
      return Text(iconData, style: TextStyle(fontSize: size));
    }
    return HugeIcon(icon: iconData, size: size, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moodInfo = _getMoodInfo(entry.moodLevel);
    final jalali = Jalali.fromDateTime(entry.dateTime);
    final f = jalali.formatter;

    // Filter activities for this entry
    final entryActivities = allActivities.where((a) => entry.activityIds.contains(a.id)).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Icon, Mood Name, Time, and More Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (moodInfo['color'] as Color).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: _buildIconOrEmoji(
                    moodInfo['icon'],
                    color: moodInfo['color'] as Color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        moodInfo['label'] as String,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: moodInfo['color'] as Color,
                        ),
                      ),
                      Text(
                        '${f.wN} ${f.d} ${f.mN} • ${intl.DateFormat('HH:mm').format(entry.dateTime)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => MoodOptionsSheet(
                        entry: entry,
                        allActivities: allActivities,
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.more_vert,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            
            // Note
            if (entry.note != null && entry.note!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                entry.note!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],

            // Activities Chips
            if (entryActivities.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: entryActivities.map((activity) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Display activity icon if available
                        _buildIconOrEmoji(
                          _getIconData(activity.iconName),
                          color: theme.colorScheme.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          activity.name,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            // Attachments Indicator
            if (entry.attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  HugeIcon(icon: HugeIcons.strokeRoundedAttachment01, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.attachments.length} فایل ضمیمه',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper to map string names to HugeIcons data
  dynamic _getIconData(String name) {
    if (name.length <= 2) return name;
    switch (name) {
      case 'strokeRoundedFavourite':
        return HugeIcons.strokeRoundedFavourite;
      case 'strokeRoundedGameController02':
        return HugeIcons.strokeRoundedGameController02;
      case 'strokeRoundedSleep':
        return HugeIcons.strokeRoundedTick02; // Fallback
      case 'strokeRoundedHealth':
        return HugeIcons.strokeRoundedHealth;
      case 'strokeRoundedHappy':
        return HugeIcons.strokeRoundedSent; // Fallback
      case 'strokeRoundedEnergy':
        return HugeIcons.strokeRoundedFlash;
      case 'strokeRoundedGiveLove':
        return HugeIcons.strokeRoundedFavourite; // Fallback
      case 'strokeRoundedMoon02':
        return HugeIcons.strokeRoundedMoon02;
      case 'strokeRoundedBored':
        return HugeIcons.strokeRoundedNote01; // Fallback
      case 'strokeRoundedBubbleChatDelay':
        return HugeIcons.strokeRoundedBubbleChatDelay;
      case 'strokeRoundedAngry':
        return HugeIcons.strokeRoundedAlertCircle; // Fallback
      case 'strokeRoundedSad01':
        return HugeIcons.strokeRoundedSent; // Fallback
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
        return HugeIcons.strokeRoundedApple; // Fallback
      case 'strokeRoundedWaterDrop':
        return HugeIcons.strokeRoundedDroplet;
      case 'strokeRoundedWalking':
        return HugeIcons.strokeRoundedUser; // Fallback
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
