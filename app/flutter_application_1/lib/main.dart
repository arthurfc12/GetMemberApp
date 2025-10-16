import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;


// <-- flutterfire configure generated this file
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';




void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SplashApp());
  await dotenv.load(fileName: ".env");


  String? initError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ✅ For quick demo: anonymous auth (must be enabled in Firebase Console)
    await FirebaseAuth.instance.signInAnonymously();

  } catch (e, st) {
    // Print to console and show on screen
    // ignore: avoid_print
    print('INIT ERROR: $e\n$st');
    initError = e.toString();
  }

  if (initError != null) {
    runApp(ErrorApp(message: initError!));
  } else {
    runApp(const MyApp());
  }
}

class ErrorApp extends StatelessWidget {
  final String message;
  const ErrorApp({super.key, required this.message});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              'Startup error:\n\n$message\n\n'
              'Open the browser console (F12) for details.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimal splash (prevents blank page during async init)
class SplashApp extends StatelessWidget {
  const SplashApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Loading…')),
      ),
    );
  }
}

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Member-Get-Member',
//       theme: ThemeData(
//         useMaterial3: true,
//         colorSchemeSeed: const Color(0xFF5B8DEF), // primary palette
//         scaffoldBackgroundColor: const Color(0xFFF7F8FB),
//         cardTheme: CardThemeData(
//           elevation: 1,
//           surfaceTintColor: Colors.white,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//           margin: EdgeInsets.zero,
//         ),
//         inputDecorationTheme: const InputDecorationTheme(
//           filled: true,
//           fillColor: Colors.white,
//           border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
//           contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//         ),
//         elevatedButtonTheme: ElevatedButtonThemeData(
//           style: ElevatedButton.styleFrom(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           ),
//         ),
//         outlinedButtonTheme: OutlinedButtonThemeData(
//           style: OutlinedButton.styleFrom(
//             padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           ),
//         ),
//       ),
//       home: const HomePage(),
//     );
//   }
// }

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _mode = ThemeMode.system; // start with system; you can default to light/dark

  void _toggleTheme() {
    setState(() {
      _mode = (_mode == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    });
  }

  bool get _isDark => _mode == ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Member-Get-Member',
      themeMode: _mode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF5B8DEF),
        scaffoldBackgroundColor: const Color(0xFFF7F8FB),
        cardTheme: CardThemeData(
          elevation: 1,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF5B8DEF),
        scaffoldBackgroundColor: const Color(0xFF0F1115),
        cardTheme: CardThemeData(
          elevation: 1,
          surfaceTintColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF1A1D24),
          border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      home: HomePage(
        onToggleTheme: _toggleTheme,
        isDark: _isDark,
      ),
    );
  }
}


class HomePage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;
  const HomePage({super.key, required this.onToggleTheme, required this.isDark});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int invites = 0;
  int conversions = 0;
  String? referralCodeStatus;
  String? insight;
  final TextEditingController _codeController = TextEditingController();
  
  int get points => conversions * 100;
  // Tier: 1 tier per referral (i.e., per 100 points)
  int get tier => points ~/ 200;

// How many badges to show on the homepage
  static const int _maxBadgesToShow = 10;

// Emoji for visual rewards (cycles if you exceed this list)
  static const List<String> _rewardEmojis = [
    '🎟️','🎖️','🎁','🏅','🎯','🏆','💎','🚀','👑','🌟'
  ];
  int _lastShownTier = 0;

  final TextEditingController _nlqController = TextEditingController();
  String? nlqAnswer;
  bool _nlqLoading = false;

  @override
  void dispose() {
    _nlqController.dispose();
    _codeController.dispose();
    super.dispose();
  }



  // If you deployed the function to a non-default region, change here.
  late final FirebaseFunctions functions =
      FirebaseFunctions.instanceFor(region: 'southamerica-east1');
  
  bool hasReferrer = false;

  Future<void> _checkHasReferrer() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() => hasReferrer = (doc.data()?['referrerId'] as String?) != null);
  }

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    _checkHasReferrer();
    _loadInsight(); // optional FastAPI agent call (web-safe if CORS enabled)
  }



  Future<void> _loadMetrics() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snap = await FirebaseFirestore.instance
        .collection('referrals')
        .where('referrerId', isEqualTo: uid)
        .get();
    setState(() {
      invites = snap.size;
      conversions = snap.docs
          .where((d) => d['status'] == 'signed_up' || d['status'] == 'active')
          .length;
      if (tier > _lastShownTier) {
        _lastShownTier = tier;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('🎉 Tier $tier unlocked!')),
            );
          }
      }

    });
  }

  Future<void> _applyReferralCode() async {
    final referrerId = _codeController.text.trim();
    if (referrerId.isEmpty) return;
    try {
      final callable = functions.httpsCallable('creditReferral');
      final result = await callable.call({'referrerId': referrerId});
      final data = Map<String, dynamic>.from(result.data);
      if (data['ok'] == true) {
        setState(() => referralCodeStatus = '✅ Referral applied successfully!');
        await _loadMetrics();
        await _checkHasReferrer();
      } else {
        setState(() =>
            referralCodeStatus = '⚠️ Error: ${data['error'] ?? 'Unknown'}');
      }
    } catch (e) {
      setState(() => referralCodeStatus = '❌ Error applying referral: $e');
    }
  }

  // Optional: FastAPI agent (enable CORS in the agent if calling from web)
  Future<void> _loadInsight() async {
    try {
      // Change to your agent URL (and ensure CORS allows your origin)
      final resp = await http.get(Uri.parse('http://localhost:8000/insights'
      '?avg_ltv=120&incentive_cost_per_conversion=15&baseline_cac=5'),
          headers: {'Authorization': 'Bearer dev-token'});
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() => insight = body['insight'] as String?);
      } else {
        setState(() => insight = 'Agent unavailable (${resp.statusCode}).');
      }
    
    } catch (_) {
      setState(() => insight = 'Agent not reachable (CORS/network).');
    }
  }

Future<void> _sendQuestion() async {
  final q = _nlqController.text.trim();
  if (q.isEmpty || _nlqLoading) return;

  setState(() { _nlqLoading = true; nlqAnswer = null; });

  try {
    final uri = Uri.parse('http://127.0.0.1:8000/ask'); // <= not localhost
    final resp = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer dev-token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'question': q,
        'avg_ltv': 120.0,
        'incentive_cost_per_conversion': 15.0,
        'baseline_cac': 5.0,
      }),
    );

    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      setState(() => nlqAnswer = (body['answer'] as String?) ?? '—');
    } else {
      setState(() => nlqAnswer = 'Agent error (${resp.statusCode}).');
    }
  } catch (e) {
    setState(() => nlqAnswer = 'Agent not reachable: $e');
  } finally {
    if (mounted) setState(() => _nlqLoading = false);
  }
}

Widget _statCard(BuildContext context, String label, int value, IconData icon) {
  return SizedBox(
    width: 210,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 4),
                  Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}



  Widget _rewardBadge(int n) {
    final unlocked = tier >= n;
    final emoji = _rewardEmojis[(n - 1) % _rewardEmojis.length];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: unlocked ? Colors.amber.shade600 : Colors.grey.shade300,
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(height: 6),
        Text(
          'T$n',
          style: TextStyle(
            fontSize: 10,
            color: unlocked ? Colors.black87 : Colors.black38,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'Unknown';
    return Scaffold(
      appBar: AppBar(
      centerTitle: true,
      title: const Text('Member-Get-Member'),
      elevation: 0.5,
      actions: [
        IconButton(
          tooltip: widget.isDark ? 'Switch to light mode' : 'Switch to dark mode',
          icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
          onPressed: widget.onToggleTheme,
        ),

        IconButton(
          tooltip: 'Sign out & switch user',
          icon: const Icon(Icons.switch_account),
          onPressed: () async {
            try {
              await FirebaseAuth.instance.signOut();
              await FirebaseAuth.instance.signInAnonymously();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signed in as a new user')),
              );
              await _loadMetrics();
              await _checkHasReferrer(); // if you added this earlier
              setState(() {}); // refresh UID display
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sign out failed: $e')),
              );
            }
          },
        ),
      ],
    ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),

        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your referral code:',
              style: Theme.of(context).textTheme.titleMedium),
          SelectableText(
            uid,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.blueGrey,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Share.share('Use my referral code: $uid'),
            child: const Text('Invite a friend'),
          ),
        
          const Divider(height: 32),
          const SizedBox(height: 8),

          OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy referral code'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: uid));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Referral code copied')),
              );
            },
          ),

            // --- Metrics ---------------------------------------------------------------
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _statCard(context, 'Invites', invites, Icons.mail_outline),
                _statCard(context, 'Conversions', conversions, Icons.check_circle),
                _statCard(context, 'Tier', tier, Icons.military_tech),
                _statCard(context, 'Points', points, Icons.stars),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  await _loadMetrics();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Metrics refreshed')),
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ),
            const Divider(height: 32),
            // --------------------------------------------------------------------------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rewards', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),

                  // Summary: 200 pts per tier
                  Text('Tier $tier · Points: $points · Next tier at ${(tier + 1) * 200}'),

                  const SizedBox(height: 8),

                  // Progress within current 200-point tier + labels
                  Builder(builder: (context) {
                    final progressToNextTier = (points % 200) / 200.0;
                    final startPts = (tier) * 200;
                    final nextPts  = (tier + 1) * 200;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progressToNextTier,
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$startPts', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                            Text('$nextPts',  style: const TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                      ],
                    );
                  }),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      const Icon(Icons.emoji_events, size: 18),
                      const SizedBox(width: 8),
                      Text('Rewards', style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(_maxBadgesToShow, (i) => _rewardBadge(i + 1)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 32),

                  Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.key, size: 18),
                    const SizedBox(width: 8),
                    Text('Apply a referral code', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _codeController,
                  decoration: const InputDecoration(labelText: 'Enter friend UID'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: hasReferrer ? null : _applyReferralCode,
                  child: const Text('Apply referral code'),
                  
                ),
                const SizedBox(height: 6),
                if (referralCodeStatus != null) ...[
                  const SizedBox(height: 10),
                  Text(referralCodeStatus!),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Divider(height: 32),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const Icon(Icons.chat_bubble_outline, size: 18),
                    const SizedBox(width: 8),
                    Text('Ask the agent', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nlqController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendQuestion(),
                    decoration: const InputDecoration(
                      hintText: 'Type a question',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: _nlqLoading ? null : _sendQuestion,
                        child: _nlqLoading
                            ? const SizedBox(
                                height: 16, width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Send'),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: _nlqLoading ? null : () {
                          _nlqController.clear();
                          setState(() => nlqAnswer = null);
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Text('Answer', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(nlqAnswer ?? '—'),
                  ),
                ],
              ),
            ),
          ),

        ]),
      ),
          ),
        )
    );
  }



  Widget _metricCard(String label, int value) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                Text('$value',
                    style: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
}


