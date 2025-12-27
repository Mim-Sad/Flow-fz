import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hugeicons/hugeicons.dart';
import 'dart:async';
import 'dart:math';

class AudioWaveformPlayer extends StatefulWidget {
  final String audioPath;
  final VoidCallback? onDelete;
  final Color? waveColor;
  final Color? activeWaveColor;

  const AudioWaveformPlayer({
    super.key,
    required this.audioPath,
    this.onDelete,
    this.waveColor,
    this.activeWaveColor,
  });

  @override
  State<AudioWaveformPlayer> createState() => _AudioWaveformPlayerState();
}

class _AudioWaveformPlayerState extends State<AudioWaveformPlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  List<double> _waveformData = [];
  bool _isDragging = false;
  double _dragPosition = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
    _generateWaveform();
  }

  Future<void> _initializeAudio() async {
    try {
      await _audioPlayer.setSource(DeviceFileSource(widget.audioPath));
      _duration = await _audioPlayer.getDuration() ?? Duration.zero;
      
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state == PlayerState.playing;
          });
        }
      });

      _audioPlayer.onPositionChanged.listen((position) {
        if (mounted && !_isDragging) {
          setState(() {
            _position = position;
            _dragPosition = _duration.inMilliseconds > 0
                ? position.inMilliseconds / _duration.inMilliseconds
                : 0.0;
          });
        }
      });

      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
            _dragPosition = 0.0;
          });
          // Reset source for next play
          _audioPlayer.setSource(DeviceFileSource(widget.audioPath));
        }
      });
    } catch (e) {
      debugPrint('Error initializing audio: $e');
    }
  }

  void _generateWaveform() {
    // Generate random waveform data (in real app, you'd extract this from audio file)
    // Less bars for minimal look with more spacing
    final random = Random();
    _waveformData = List.generate(25, (index) => random.nextDouble() * 0.4 + 0.15);
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        // Check current state
        final currentState = _audioPlayer.state;
        
        // If stopped or completed, set source and play from beginning
        if (currentState == PlayerState.stopped || 
            (_position >= _duration && _duration.inMilliseconds > 0)) {
          await _audioPlayer.setSource(DeviceFileSource(widget.audioPath));
          await _audioPlayer.seek(Duration.zero);
          await _audioPlayer.resume();
          if (mounted) {
            setState(() {
              _position = Duration.zero;
              _dragPosition = 0.0;
            });
          }
        } else {
          // Otherwise just resume
          await _audioPlayer.resume();
        }
      }
    } catch (e) {
      debugPrint('Error toggling play/pause: $e');
      // If resume fails, try setting source and playing from start
      try {
        await _audioPlayer.setSource(DeviceFileSource(widget.audioPath));
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.resume();
        if (mounted) {
          setState(() {
            _position = Duration.zero;
            _dragPosition = 0.0;
          });
        }
      } catch (e2) {
        debugPrint('Error retrying play: $e2');
      }
    }
  }

  Future<void> _seekToPosition(double position) async {
    try {
      final newPosition = Duration(
        milliseconds: (_duration.inMilliseconds * position).round(),
      );
      await _audioPlayer.seek(newPosition);
      if (mounted) {
        setState(() {
          _position = newPosition;
          _dragPosition = position;
        });
      }
    } catch (e) {
      debugPrint('Error seeking: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waveColor = widget.waveColor ?? theme.colorScheme.primary.withValues(alpha: 0.3);
    final activeWaveColor = widget.activeWaveColor ?? theme.colorScheme.primary;

    return Container(
      height: 48, // Fixed height for consistency
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
              // Play/Pause Button
              GestureDetector(
                onTap: _togglePlayPause,
                child: HugeIcon(
                  icon: _isPlaying 
                      ? HugeIcons.strokeRoundedPause 
                      : HugeIcons.strokeRoundedPlay,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              
              // Waveform
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate available width with side padding
                    final sidePadding = 12.0;
                    final availableWidth = constraints.maxWidth - (sidePadding * 2);
                    
                    return GestureDetector(
                      onHorizontalDragStart: (details) {
                        setState(() {
                          _isDragging = true;
                        });
                      },
                      onHorizontalDragUpdate: (details) {
                        final RenderBox? box = context.findRenderObject() as RenderBox?;
                        if (box != null) {
                          final localPosition = box.globalToLocal(details.globalPosition);
                          // Account for side padding
                          final adjustedX = (localPosition.dx - sidePadding).clamp(0.0, availableWidth);
                          final newPosition = availableWidth > 0 ? (adjustedX / availableWidth).clamp(0.0, 1.0) : 0.0;
                          setState(() {
                            _dragPosition = newPosition;
                          });
                        }
                      },
                      onHorizontalDragEnd: (details) {
                        _seekToPosition(_dragPosition);
                        setState(() {
                          _isDragging = false;
                        });
                      },
                      onTapDown: (details) {
                        final RenderBox? box = context.findRenderObject() as RenderBox?;
                        if (box != null) {
                          final localPosition = box.globalToLocal(details.globalPosition);
                          // Account for side padding
                          final adjustedX = (localPosition.dx - sidePadding).clamp(0.0, availableWidth);
                          final newPosition = availableWidth > 0 ? (adjustedX / availableWidth).clamp(0.0, 1.0) : 0.0;
                          _seekToPosition(newPosition);
                        }
                      },
                      child: Container(
                        height: 32,
                        width: constraints.maxWidth,
                        padding: EdgeInsets.symmetric(horizontal: sidePadding),
                        child: SizedBox(
                          width: availableWidth,
                          height: 32,
                          child: CustomPaint(
                            painter: WaveformPainter(
                              waveformData: _waveformData,
                              progress: _dragPosition,
                              waveColor: waveColor,
                              activeWaveColor: activeWaveColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Time Display
              Text(
                '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'IRANSansX',
                ),
              ),
              
              // Delete Button
              if (widget.onDelete != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    _audioPlayer.stop();
                    widget.onDelete?.call();
                  },
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;
  final Color waveColor;
  final Color activeWaveColor;

  WaveformPainter({
    required this.waveformData,
    required this.progress,
    required this.waveColor,
    required this.activeWaveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    // More spacing between bars for minimal look
    final totalBars = waveformData.length;
    final spacing = 4.0; // Space between bars
    final barWidth = 2.5; // Width of each bar
    final totalWidth = (totalBars * barWidth) + ((totalBars - 1) * spacing);
    final startX = (size.width - totalWidth) / 2; // Center the waveform
    final centerY = size.height / 2;

    for (int i = 0; i < waveformData.length; i++) {
      final barHeight = waveformData[i] * size.height;
      final x = startX + (i * (barWidth + spacing)) + barWidth / 2;
      final isActive = (i / waveformData.length) <= progress;

      final paint = Paint()
        ..color = isActive ? activeWaveColor : waveColor
        ..strokeWidth = barWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.waveformData != waveformData;
  }
}
