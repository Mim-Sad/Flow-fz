import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:intl/intl.dart' as intl;
import '../../models/mood_entry.dart';
import '../../models/activity.dart';
import '../../providers/task_provider.dart';
import 'mood_options_sheet.dart';

class MoodCard extends ConsumerWidget {
  final MoodEntry entry;
  final List<Activity> allActivities;

  const MoodCard({super.key, required this.entry, required this.allActivities});

  Widget _buildIconOrEmoji(
    dynamic iconData, {
    required double size,
    Color? color,
  }) {
    if (iconData is String) {
      if (iconData.endsWith('.svg')) {
        return SvgPicture.asset(
          iconData,
          width: size,
          height: size,
          colorFilter:
              color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
        );
      } else if (iconData.endsWith('.png') || iconData.endsWith('.jpg')) {
        return Image.asset(iconData, width: size, height: size);
      }
      return Text(iconData, style: TextStyle(fontSize: size, color: color));
    }
    return HugeIcon(icon: iconData, size: size, color: color);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final moodInfo = _getMoodInfo(entry.moodLevel);
    final displayLabel = moodInfo['label'] as String;
    final displayIcon = moodInfo['icon'];

    final jalali = Jalali.fromDateTime(entry.dateTime);
    final f = jalali.formatter;

    // Filter activities for this entry
    final entryActivities = allActivities
        .where((a) => entry.activityIds.contains(a.id))
        .toList();

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
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: () {
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
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.only(
              left: 6,
              right: 12,
              top: 12,
              bottom: 12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Header: Icon, Mood Name, Time, and More Button
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (moodInfo['color'] as Color).withValues(
                        alpha: 0.1,
                      ),
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: _buildIconOrEmoji(
                      displayIcon,
                      color: moodInfo['color'] as Color,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayLabel,
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
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedMoreVertical,
                      size: 22,
                      color: Colors.grey,
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    constraints: const BoxConstraints(),
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
                  ),
                ],
              ),

              // Note
              if (entry.note != null && entry.note!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  entry.note!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
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
                    final color = moodInfo['color'] as Color;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Display activity icon if available
                          _buildIconOrEmoji(
                            _getIconData(activity.iconName),
                            color: color,
                            size: 10,
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

              // Linked Task
              if (entry.taskId != null) ...[
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, child) {
                    final tasks = ref.watch(tasksProvider);
                    final linkedTask = tasks.where((t) => t.id == entry.taskId).firstOrNull;
                    if (linkedTask == null) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedTask01,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            linkedTask.title,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],

              // Attachments Indicator
              if (entry.attachments.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('📎', style: TextStyle(fontSize: 14)),
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
      ),
    ),
  );
}

  // Helper to map string names to HugeIcons data
  dynamic _getIconData(String name) {
    if (!name.startsWith('strokeRounded')) {
      return name;
    }
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
    return {
      'label': level.label,
      'color': level.color,
      'icon': level.iconPath,
      'emoji': level.emoji,
    };
  }
}
