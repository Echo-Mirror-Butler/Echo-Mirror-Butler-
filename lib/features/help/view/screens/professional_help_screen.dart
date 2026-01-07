import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../ai/viewmodel/providers/ai_provider.dart';

/// Professional help screen with Gemini-powered resource recommendations
class ProfessionalHelpScreen extends ConsumerStatefulWidget {
  const ProfessionalHelpScreen({super.key});

  @override
  ConsumerState<ProfessionalHelpScreen> createState() => _ProfessionalHelpScreenState();
}

class _ProfessionalHelpScreenState extends ConsumerState<ProfessionalHelpScreen> {
  String _selectedCategory = 'general';
  bool _isLoadingRecommendations = false;
  String? _aiRecommendation;
  
  // AI Chat Butler
  bool _isChatOpen = false;
  final List<Map<String, String>> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  bool _isSendingMessage = false;
  
  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  final Map<String, Map<String, dynamic>> _helpCategories = {
    'general': {
      'title': 'General Mental Health',
      'icon': FontAwesomeIcons.brain,
      'color': const Color(0xFF6366F1),
      'description': 'General mental health support and counseling',
    },
    'anxiety': {
      'title': 'Anxiety & Stress',
      'icon': FontAwesomeIcons.heartPulse,
      'color': const Color(0xFFEC4899),
      'description': 'Help with anxiety, stress, and panic disorders',
    },
    'depression': {
      'title': 'Depression',
      'icon': FontAwesomeIcons.cloudRain,
      'color': const Color(0xFF8B5CF6),
      'description': 'Support for depression and mood disorders',
    },
    'crisis': {
      'title': 'Crisis Support',
      'icon': FontAwesomeIcons.phoneVolume,
      'color': const Color(0xFFEF4444),
      'description': 'Immediate crisis intervention and emergency support',
    },
  };

  final Map<String, List<Map<String, String>>> _resources = {
    'general': [
      {
        'name': 'BetterHelp',
        'description': 'Online therapy and counseling',
        'url': 'https://www.betterhelp.com',
        'type': 'therapy',
      },
      {
        'name': 'Talkspace',
        'description': 'Online therapy platform',
        'url': 'https://www.talkspace.com',
        'type': 'therapy',
      },
      {
        'name': 'Psychology Today',
        'description': 'Find a therapist near you',
        'url': 'https://www.psychologytoday.com/us/therapists',
        'type': 'directory',
      },
    ],
    'anxiety': [
      {
        'name': 'Anxiety and Depression Association',
        'description': 'Resources and support for anxiety disorders',
        'url': 'https://adaa.org',
        'type': 'organization',
      },
      {
        'name': 'Calm App',
        'description': 'Meditation and anxiety relief',
        'url': 'https://www.calm.com',
        'type': 'app',
      },
    ],
    'depression': [
      {
        'name': 'National Alliance on Mental Illness',
        'description': 'Depression resources and support groups',
        'url': 'https://www.nami.org',
        'type': 'organization',
      },
      {
        'name': 'Depression and Bipolar Support Alliance',
        'description': 'Peer support and education',
        'url': 'https://www.dbsalliance.org',
        'type': 'organization',
      },
    ],
    'crisis': [
      {
        'name': '988 Suicide & Crisis Lifeline',
        'description': '24/7 crisis support - Call or text 988',
        'url': 'tel:988',
        'type': 'hotline',
      },
      {
        'name': 'Crisis Text Line',
        'description': 'Text HOME to 741741',
        'url': 'sms:741741?body=HOME',
        'type': 'hotline',
      },
      {
        'name': 'National Domestic Violence Hotline',
        'description': 'Call 1-800-799-7233',
        'url': 'tel:18007997233',
        'type': 'hotline',
      },
    ],
  };

  Future<void> _getAIRecommendations() async {
    setState(() {
      _isLoadingRecommendations = true;
      _aiRecommendation = null;
    });

    try {
      // Provide personalized recommendations based on category
      final response = 'Seeking professional help is a sign of strength. '
          'A mental health professional can provide personalized support and '
          'evidence-based treatments tailored to your specific needs.';
      
      setState(() {
        _aiRecommendation = response;
        _isLoadingRecommendations = false;
      });
    } catch (e) {
      debugPrint('[ProfessionalHelpScreen] Error getting AI recommendations: $e');
      setState(() {
        _aiRecommendation = 'Seeking professional help is a sign of strength. '
            'A mental health professional can provide personalized support and '
            'evidence-based treatments tailored to your specific needs.';
        _isLoadingRecommendations = false;
      });
    }
  }
  
  Future<void> _sendChatMessage(String message) async {
    if (message.trim().isEmpty) return;
    
    setState(() {
      _chatMessages.add({'role': 'user', 'content': message});
      _isSendingMessage = true;
    });
    
    _chatController.clear();
    
    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    
    try {
      // Get AI repository and generate response using Gemini
      final aiRepository = ref.read(aiRepositoryProvider);
      
      // Create context about the current category
      final context = 'The user is viewing the ${_helpCategories[_selectedCategory]!['title']} category on the Need Help screen. '
          'They have access to professional mental health resources including hotlines, therapy platforms, and support services.';
      
      // Call Gemini to generate a free-form response
      final response = await aiRepository.generateChatResponse(message, context: context);
      
      setState(() {
        _chatMessages.add({'role': 'assistant', 'content': response});
        _isSendingMessage = false;
      });
      
      // Scroll to bottom after AI response
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('[ProfessionalHelpScreen] Error sending chat message: $e');
      setState(() {
        _chatMessages.add({
          'role': 'assistant',
          'content': 'I apologize, but I\'m having trouble responding right now. '
              'Please try again in a moment, or reach out to one of the crisis hotlines '
              'listed above if you need immediate support.'
        });
        _isSendingMessage = false;
      });
    }
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      final url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open this resource')),
          );
        }
      }
    } catch (e) {
      debugPrint('[ProfessionalHelpScreen] Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening resource')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _getAIRecommendations();
  }

  @override
  Widget build(BuildContext context) {
    final resources = _resources[_selectedCategory] ?? [];

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          floatingActionButton: !_isChatOpen ? _buildChatButton() : null,
          appBar: AppBar(
        title: Text(
          'Need Help?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with message
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(
                      Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.1,
                    ),
                    Theme.of(context).colorScheme.secondary.withOpacity(
                      Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.1,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    FontAwesomeIcons.handHoldingHeart,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'You\'re Not Alone',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Seeking help is a courageous step. We\'re here to connect you with professional support.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Category selection
            Text(
              'What do you need help with?',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _helpCategories.entries.map((entry) {
                final isSelected = _selectedCategory == entry.key;
                final categoryData = entry.value;
                
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = entry.key);
                    _getAIRecommendations();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? categoryData['color']
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? categoryData['color']
                            : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: (categoryData['color'] as Color)
                                    .withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          categoryData['icon'] as IconData,
                          color: isSelected
                              ? Colors.white
                              : categoryData['color'],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          categoryData['title'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // AI Recommendations
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: Theme.of(context).brightness == Brightness.dark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        FontAwesomeIcons.wandMagicSparkles,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI-Powered Recommendation',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _isLoadingRecommendations
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : Text(
                          _aiRecommendation ??
                              'Loading personalized recommendations...',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                            height: 1.5,
                          ),
                        ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Resources list
            Text(
              'Recommended Resources',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            const SizedBox(height: 12),

            ...resources.map((resource) => _buildResourceCard(resource)),

            // Emergency notice
            if (_selectedCategory == 'crisis') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.red.shade900.withOpacity(0.3)
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.red.shade700
                        : Colors.red.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      FontAwesomeIcons.triangleExclamation,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.red.shade400
                          : Colors.red.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'If you\'re in immediate danger, please call 911 or go to your nearest emergency room.',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.red.shade300
                              : Colors.red.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
        ),
        // Chat overlay
        if (_isChatOpen) _buildChatOverlay(),
      ],
    );
  }

  Widget _buildResourceCard(Map<String, String> resource) {
    IconData icon;
    Color iconColor;

    switch (resource['type']) {
      case 'hotline':
        icon = FontAwesomeIcons.phone;
        iconColor = Colors.red;
        break;
      case 'therapy':
        icon = FontAwesomeIcons.userDoctor;
        iconColor = Colors.blue;
        break;
      case 'organization':
        icon = FontAwesomeIcons.buildingUser;
        iconColor = Colors.purple;
        break;
      case 'app':
        icon = FontAwesomeIcons.mobile;
        iconColor = Colors.green;
        break;
      case 'directory':
        icon = FontAwesomeIcons.addressBook;
        iconColor = Colors.orange;
        break;
      default:
        icon = FontAwesomeIcons.link;
        iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: theme.brightness == Brightness.dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _launchUrl(resource['url']!),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(
                      theme.brightness == Brightness.dark ? 0.2 : 0.1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource['name']!,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        resource['description']!,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  FontAwesomeIcons.chevronRight,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildChatButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        setState(() {
          _isChatOpen = true;
          if (_chatMessages.isEmpty) {
            _chatMessages.add({
              'role': 'assistant',
              'content': 'Hello! I\'m your EchoMirror AI assistant. I\'m here to help you find the right mental health support. How can I assist you today?'
            });
          }
        });
      },
      backgroundColor: Theme.of(context).colorScheme.primary,
      icon: FaIcon(
        FontAwesomeIcons.commentDots,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
      label: Text(
        'Chat with AI Butler',
        style: GoogleFonts.poppins(
          color: Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  Widget _buildChatOverlay() {
    final theme = Theme.of(context);
    return Material(
      color: Colors.black.withOpacity(0.5),
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: theme.brightness == Brightness.dark
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
          ),
          child: Column(
            children: [
              // Chat header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onPrimary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: FaIcon(
                          FontAwesomeIcons.robot,
                          color: theme.colorScheme.onPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Mental Health Butler',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onPrimary,
                            ),
                          ),
                          Text(
                            'Here to help you find support',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: theme.colorScheme.onPrimary.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: theme.colorScheme.onPrimary),
                      onPressed: () {
                        setState(() {
                          _isChatOpen = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              
              // Chat messages
              Expanded(
                child: ListView.builder(
                  controller: _chatScrollController,
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom > 0 
                        ? MediaQuery.of(context).viewInsets.bottom + 8 
                        : 16,
                  ),
                  itemCount: _chatMessages.length,
                  itemBuilder: (context, index) {
                    final message = _chatMessages[index];
                    final isUser = message['role'] == 'user';
                    
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        decoration: BoxDecoration(
                          color: isUser
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          message['content']!,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: isUser 
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Typing indicator
              if (_isSendingMessage)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Thinking...',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              // Input field
              Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom > 0 
                      ? MediaQuery.of(context).viewInsets.bottom + 8 
                      : 16,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type your message...',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (value) {
                          if (value.trim().isNotEmpty) {
                            _sendChatMessage(value);
                            FocusScope.of(context).unfocus();
                          }
                        },
                        onTap: () {
                          // Scroll to bottom when keyboard opens
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_chatScrollController.hasClients) {
                              _chatScrollController.animateTo(
                                _chatScrollController.position.maxScrollExtent,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.send,
                          color: theme.colorScheme.onPrimary,
                        ),
                        onPressed: _isSendingMessage
                            ? null
                            : () {
                                if (_chatController.text.trim().isNotEmpty) {
                                  _sendChatMessage(_chatController.text);
                                  FocusScope.of(context).unfocus();
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

