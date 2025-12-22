import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../data/models/mood_pin_model.dart';
import '../../viewmodel/providers/global_mirror_provider.dart';
import '../widgets/privacy_info_sheet.dart';
import '../widgets/globe_3d_widget.dart';
import '../widgets/mood_pin_widget.dart';
import '../widgets/mood_pin_comment_dialog.dart';
import '../../viewmodel/providers/mood_comment_notification_provider.dart';
import 'package:go_router/go_router.dart';

/// Globe screen showing anonymous mood pins on a 3D world globe
class GlobeScreen extends ConsumerStatefulWidget {
  const GlobeScreen({super.key});

  @override
  ConsumerState<GlobeScreen> createState() => _GlobeScreenState();
}

class _GlobeScreenState extends ConsumerState<GlobeScreen> {
  final MapController _mapController = MapController();
  // Default to 2D map on iOS until WebView is properly registered after rebuild
  bool _use3DGlobe = defaultTargetPlatform != TargetPlatform.iOS;
  bool _has3DError = false;

  @override
  void initState() {
    super.initState();
    // Check location permission on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
      ref.read(globalMirrorProvider.notifier).checkLocationPermission();
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Color _getSentimentColor(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positive':
      case 'happy':
      case 'excited':
        return Colors.green;
      case 'calm':
      case 'grateful':
        return Colors.blue;
      case 'neutral':
      case 'reflective':
        return Colors.amber;
      case 'negative':
      case 'sad':
        return Colors.red;
      case 'anxious':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showPrivacyInfo() {
    showModalBottomSheet(
      context: context,
      builder: (context) => const PrivacyInfoSheet(),
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moodPinsAsync = ref.watch(moodPinsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Global Mirror',
          style: theme.textTheme.headlineSmall,
        ),
        actions: [
          // Notifications button with badge
          Consumer(
            builder: (context, ref, child) {
              final unreadCount = ref.watch(moodCommentNotificationProvider.notifier).unreadCount;
              return Stack(
                children: [
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.heart),
                    onPressed: () {
                      context.push('/notifications');
                    },
                    tooltip: 'Mood Support Notifications',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // Toggle between 3D and 2D
          IconButton(
            icon: FaIcon(_use3DGlobe && !_has3DError ? FontAwesomeIcons.map : FontAwesomeIcons.globe),
            onPressed: () {
              setState(() {
                _use3DGlobe = !_use3DGlobe;
                _has3DError = false; // Reset error when toggling
              });
            },
            tooltip: _use3DGlobe && !_has3DError ? 'Switch to 2D Map' : 'Switch to 3D Globe',
          ),
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.circleInfo),
            onPressed: _showPrivacyInfo,
            tooltip: 'Privacy Info',
          ),
        ],
      ),
      body: moodPinsAsync.when(
        data: (pins) {
          return Stack(
            children: [
              // Show 3D Globe or 2D Map based on toggle
              // Note: On iOS, WebView requires app rebuild after adding webview_flutter
              if (_use3DGlobe && !_has3DError)
                Globe3DWidget(
                  pins: pins,
                  onPinTap: (pin) {
                    showDialog(
                      context: context,
                      builder: (context) => MoodPinCommentDialog(pin: pin),
                    );
                  },
                )
              else
                // 2D Map (default on iOS until rebuild, or fallback)
                _build2DMap(pins, theme),

              // Stats overlay
              Positioned(
                top: 16,
                left: 16,
                child: FadeInDown(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: pins.isNotEmpty ? Colors.green : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Active Moods',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      Text(
                        '${pins.length} worldwide',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      if (pins.length > 50) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Showing first 50 pins',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.orange,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                        if (pins.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Share a mood to see it here!',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          Text(
                            'Stream connected',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Legend
              Positioned(
                bottom: 16,
                right: 16,
                child: FadeInUp(
                  child: _buildLegend(theme),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: ShimmerLoading(
            width: 40,
            height: 40,
          ),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FaIcon(
                  FontAwesomeIcons.triangleExclamation,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading mood pins',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Refresh the stream
                    ref.invalidate(moodPinsStreamProvider);
                  },
                  icon: const FaIcon(FontAwesomeIcons.arrowRotateRight),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _build2DMap(List<MoodPinModel> pins, ThemeData theme) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(0.0, 0.0),
        initialZoom: 0.5, // Very zoomed out to see entire world
        minZoom: 0.0,
        maxZoom: 18.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        // OpenStreetMap tile layer
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.echomirror',
          maxZoom: 19,
        ),
        
        // Mood pins layer
        MarkerLayer(
          markers: pins.map((pin) {
            return Marker(
              point: LatLng(pin.gridLat, pin.gridLon),
              width: 30,
              height: 30,
              child: MoodPinWidget(
                pin: pin,
                color: _getSentimentColor(pin.sentiment),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLegend(ThemeData theme) {
    final sentiments = [
      {'name': 'Positive', 'color': Colors.green},
      {'name': 'Calm', 'color': Colors.blue},
      {'name': 'Neutral', 'color': Colors.amber},
      {'name': 'Negative', 'color': Colors.red},
      {'name': 'Anxious', 'color': Colors.red},
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Mood Legend',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...sentiments.map((sentiment) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: sentiment['color'] as Color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      sentiment['name'] as String,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
