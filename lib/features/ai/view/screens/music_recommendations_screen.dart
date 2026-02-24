import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/themes/app_theme.dart';

/// Screen showing music recommendations for relaxation
class MusicRecommendationsScreen extends StatelessWidget {
  const MusicRecommendationsScreen({super.key});

  final List<Map<String, String>> _relaxingPlaylists = const [
    {
      'title': 'Peaceful Piano',
      'artist': 'Spotify',
      'spotifyUrl': 'https://open.spotify.com/playlist/37i9dQZF1DX4sWSpwq3LiO',
      'appleUrl':
          'https://music.apple.com/us/playlist/peaceful-piano/pl.u-06oNlJt2a1vX',
    },
    {
      'title': 'Deep Focus',
      'artist': 'Spotify',
      'spotifyUrl': 'https://open.spotify.com/playlist/37i9dQZF1DWZeKCadgRdKQ',
      'appleUrl':
          'https://music.apple.com/us/playlist/deep-focus/pl.u-06oNlJt2a1vX',
    },
    {
      'title': 'Nature Sounds',
      'artist': 'Spotify',
      'spotifyUrl': 'https://open.spotify.com/playlist/37i9dQZF1DWZd79rJ6a7lp',
      'appleUrl':
          'https://music.apple.com/us/playlist/nature-sounds/pl.u-06oNlJt2a1vX',
    },
    {
      'title': 'Calm Meditation',
      'artist': 'Spotify',
      'spotifyUrl': 'https://open.spotify.com/playlist/37i9dQZF1DWZqd5JICL0u3',
      'appleUrl':
          'https://music.apple.com/us/playlist/calm-meditation/pl.u-06oNlJt2a1vX',
    },
    {
      'title': 'Sleep Sounds',
      'artist': 'Spotify',
      'spotifyUrl': 'https://open.spotify.com/playlist/37i9dQZF1DWZd79rJ6a7lp',
      'appleUrl':
          'https://music.apple.com/us/playlist/sleep-sounds/pl.u-06oNlJt2a1vX',
    },
  ];

  Future<void> _openSpotify(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openAppleMusic(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.05),
      appBar: AppBar(
        title: Text(
          'Relaxing Music',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    FontAwesomeIcons.music,
                    size: 48,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Recommended Playlists',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Continue your relaxation with these calming playlists',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _relaxingPlaylists.length,
                itemBuilder: (context, index) {
                  final playlist = _relaxingPlaylists[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primaryColor,
                                      AppTheme.secondaryColor,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  FontAwesomeIcons.music,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      playlist['title']!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      playlist['artist']!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(
                                    FontAwesomeIcons.spotify,
                                    size: 16,
                                  ),
                                  label: const Text('Spotify'),
                                  onPressed: () =>
                                      _openSpotify(playlist['spotifyUrl']!),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.green,
                                    side: const BorderSide(color: Colors.green),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(
                                    FontAwesomeIcons.apple,
                                    size: 16,
                                  ),
                                  label: const Text('Apple Music'),
                                  onPressed: () =>
                                      _openAppleMusic(playlist['appleUrl']!),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
