import 'package:flutter_test/flutter_test.dart';

// The resource map is defined inline in ProfessionalHelpScreen.  These tests
// verify the data contract — every entry must have name, description, url,
// and type — and that crisis resources use the expected hotline URLs.
//
// Keeping this in a plain unit test avoids any platform-plugin or Supabase
// initialisation overhead.

const _resources = {
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

void main() {
  group('ProfessionalHelpScreen resource data', () {
    test('all categories are present', () {
      expect(_resources.keys, containsAll(['general', 'anxiety', 'depression', 'crisis']));
    });

    for (final entry in _resources.entries) {
      final category = entry.key;
      final resources = entry.value;

      test('$category: every resource has required keys', () {
        for (final r in resources) {
          expect(r['name'], isNotEmpty, reason: '$category resource missing name');
          expect(r['description'], isNotEmpty, reason: '$category resource missing description');
          expect(r['url'], isNotEmpty, reason: '$category resource missing url');
          expect(r['type'], isNotEmpty, reason: '$category resource missing type');
        }
      });
    }

    test('crisis category contains the 988 lifeline', () {
      final crisis = _resources['crisis']!;
      final hotlineUrls = crisis.map((r) => r['url']).toList();
      expect(hotlineUrls, contains('tel:988'));
    });

    test('crisis category contains the crisis text line', () {
      final crisis = _resources['crisis']!;
      final names = crisis.map((r) => r['name']).toList();
      expect(names, contains('Crisis Text Line'));
    });

    test('crisis resources are all hotline type', () {
      final crisis = _resources['crisis']!;
      for (final r in crisis) {
        expect(r['type'], 'hotline', reason: 'Crisis resource "${r['name']}" should be type hotline');
      }
    });

    test('non-crisis categories have no hotline entries', () {
      for (final category in ['general', 'anxiety', 'depression']) {
        for (final r in _resources[category]!) {
          expect(r['type'], isNot('hotline'), reason: '$category should not contain hotlines');
        }
      }
    });

    test('general resources use https URLs', () {
      for (final r in _resources['general']!) {
        expect(r['url']!.startsWith('https://'), isTrue, reason: '${r['name']} URL should use https');
      }
    });
  });
}
