import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/mood_provider.dart';
import '../widgets/mood/add_mood_sheet.dart';
import '../widgets/mood/mood_card.dart';
import '../widgets/mood/streak_card.dart';
import '../widgets/animations.dart';

class MoodScreen extends ConsumerStatefulWidget {
  final bool showAddSheet;
  const MoodScreen({super.key, this.showAddSheet = false});

  @override
  ConsumerState<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends ConsumerState<MoodScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.showAddSheet) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openAddMoodSheet(context);
      });
    }
  }

  void _openAddMoodSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddMoodSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moodState = ref.watch(moodProvider);
    final activityState = ref.watch(activityProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          if (!moodState.isLoading && moodState.error == null)
            SliverToBoxAdapter(
              child: StreakCard(moodState: moodState),
            ),

          if (moodState.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (moodState.error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedAlertCircle,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'خطایی رخ داده است',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      moodState.error!,
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () =>
                          ref.read(moodProvider.notifier).loadMoods(),
                      child: const Text('تلاش مجدد'),
                    ),
                  ],
                ),
              ),
            )
          else if (moodState.entries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedSmileDizzy,
                      size: 64,
                      color: theme.colorScheme.primary.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'هنوز هیچ مودی ثبت نشده!',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'همین الان اولین مود خودت رو ثبت کن',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= moodState.entries.length) return null;
                  final entry = moodState.entries[index];

                  final card = MoodCard(
                    entry: entry,
                    allActivities: activityState.activities,
                  );

                  return FadeInOnce(
                    key: ValueKey('mood_${entry.id}_$index'),
                    delay: (index * 50).ms,
                    child: card,
                  );
                },
                childCount: moodState.entries.length,
              ),
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddMoodSheet(context),
        label: const Text(
          'ثبت مود',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedAdd01,
          color: theme.colorScheme.onPrimaryContainer,
        ),
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}
