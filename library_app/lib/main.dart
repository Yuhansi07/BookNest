import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

int correctLoanDays(dynamic loan) {
  final shownDate = formatDate(loan['due_date']);

  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(shownDate)) {
    return toInt(loan['days_remaining']);
  }

  const demo = String.fromEnvironment('DEMO_TODAY');

  final now = demo.isNotEmpty ? DateTime.parse(demo) : DateTime.now();

  final today = DateTime.utc(now.year, now.month, now.day);

  final due = DateTime.utc(
    int.parse(shownDate.substring(0, 4)),
    int.parse(shownDate.substring(5, 7)),
    int.parse(shownDate.substring(8, 10)),
  );

  return due.difference(today).inDays;
}

double correctLoanFine(dynamic loan) {
  if (loan['status']?.toString().toLowerCase() != 'issued') {
    return toDouble(loan['fine'] ?? 0);
  }

  if (loan['calculated_fine'] != null) {
    return toDouble(loan['calculated_fine']);
  }

  final days = correctLoanDays(loan);

  return days < 0 ? (-days * 25.0) : 0.0;
}

// ============================================================
// API CONFIG
// ============================================================

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:5000/api',
);

void main() {
  runApp(const LibraryApp());
}

// ============================================================
// HELPERS
// ============================================================

int toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();

  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String formatMoney(dynamic value) {
  return toDouble(value).toStringAsFixed(2);
}

String formatDate(dynamic value) {
  if (value == null) return '-';

  try {
    final date = DateTime.parse(value.toString()).toLocal();

    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return value.toString();
  }
}

String cleanError(Object error) {
  return error.toString().replaceFirst('Exception: ', '');
}

class AppColors {
  static const ink = Color(0xFF151826);
  static const text = Color(0xFF334155);
  static const muted = Color(0xFF7B8498);
  static const line = Color(0xFFE6E8EF);
  static const canvas = Color(0xFFF4F6FA);
  static const surface = Colors.white;

  static const sidebar = Color(0xFF171925);
  static const sidebarSoft = Color(0xFF222534);
  static const sidebarLine = Color(0xFF2D3142);

  static const primary = Color(0xFF7367F0);
  static const primaryDark = Color(0xFF5B50D6);
  static const primarySoft = Color(0xFFECEAFF);
  static const primaryFaint = Color(0xFFF7F6FF);

  static const navy = sidebar;
  static const navySoft = sidebarSoft;
  static const green = primary;
  static const greenDark = primaryDark;
  static const greenSoft = primarySoft;

  static const blue = Color(0xFF3B82F6);
  static const violet = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF21C7F2);
  static const pink = Color(0xFFFF76A8);
  static const amber = Color(0xFFFFB547);
  static const red = Color(0xFFFF5C6C);
  static const mint = Color(0xFF62D6B4);
}

class BookCoverArt extends StatelessWidget {
  final Map<String, dynamic> book;
  final double width;
  final double height;
  final double radius;

  const BookCoverArt({
    super.key,
    required this.book,
    this.width = 72,
    this.height = 98,
    this.radius = 12,
  });

  List<Color> _palette(String category) {
    final c = category.toLowerCase();
    if (c.contains('artificial') ||
        c.contains('machine') ||
        c.contains('data science')) {
      return const [Color(0xFF4F46E5), Color(0xFF8B5CF6)];
    }
    if (c.contains('program') ||
        c.contains('software') ||
        c.contains('web') ||
        c.contains('mobile')) {
      return const [Color(0xFF0F766E), Color(0xFF14B8A6)];
    }
    if (c.contains('network') || c.contains('cyber')) {
      return const [Color(0xFF1D4ED8), Color(0xFF38BDF8)];
    }
    if (c.contains('database')) {
      return const [Color(0xFF7C3AED), Color(0xFFEC4899)];
    }
    if (c.contains('embedded') ||
        c.contains('digital') ||
        c.contains('electronic') ||
        c.contains('iot')) {
      return const [Color(0xFFB45309), Color(0xFFF59E0B)];
    }
    if (c.contains('math')) {
      return const [Color(0xFFBE123C), Color(0xFFFB7185)];
    }
    if (c.contains('cloud') || c.contains('devops')) {
      return const [Color(0xFF0369A1), Color(0xFF22D3EE)];
    }
    if (c.contains('management') || c.contains('business')) {
      return const [Color(0xFF334155), Color(0xFF64748B)];
    }
    return const [Color(0xFF5B50D6), Color(0xFF8B7CF6)];
  }

  Widget _generatedCover() {
    final title = book['title']?.toString().trim() ?? 'Book';
    final author = book['author']?.toString().trim() ?? '';
    final category = book['category']?.toString().trim() ?? 'Library';
    final colors = _palette(category);
    final tiny = width <= 52 || height <= 72;
    final compact = !tiny && (width < 70 || height < 96);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -18,
            top: -18,
            child: Container(
              width: width * 0.9,
              height: width * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(
              tiny
                  ? 4
                  : compact
                  ? 6
                  : 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: width - (tiny ? 8 : 12),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: tiny
                        ? 3
                        : compact
                        ? 4
                        : 5,
                    vertical: tiny
                        ? 1.5
                        : compact
                        ? 2
                        : 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(tiny ? 4 : 6),
                  ),
                  child: Text(
                    category.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: tiny
                          ? 4.2
                          : compact
                          ? 5.2
                          : 6.5,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: tiny ? 0 : 0.2,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white.withOpacity(0.95),
                  size: tiny
                      ? 12
                      : compact
                      ? 15
                      : 20,
                ),
                SizedBox(
                  height: tiny
                      ? 2
                      : compact
                      ? 3
                      : 6,
                ),
                Text(
                  title,
                  maxLines: tiny
                      ? 2
                      : compact
                      ? 2
                      : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.0,
                    fontSize: tiny
                        ? 5.4
                        : compact
                        ? 6.8
                        : 8.4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (!tiny && author.isNotEmpty) ...[
                  SizedBox(height: compact ? 1.5 : 3),
                  Text(
                    author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      fontSize: compact ? 5.0 : 6.5,
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = book['cover_url']?.toString().trim() ?? '';
    final isbn = book['isbn']?.toString().replaceAll('-', '').trim() ?? '';
    final seededDemoIsbn =
        isbn.startsWith('978100000') || isbn == '9781111111111';
    final openLibraryUrl = isbn.isEmpty || seededDemoIsbn
        ? ''
        : 'https://covers.openlibrary.org/b/isbn/$isbn-M.jpg?default=false';

    Widget content;
    if (coverUrl.isNotEmpty) {
      content = Image.network(
        coverUrl,
        fit: BoxFit.cover,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => _generatedCover(),
      );
    } else if (openLibraryUrl.isNotEmpty) {
      content = Image.network(
        openLibraryUrl,
        fit: BoxFit.cover,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) => _generatedCover(),
      );
    } else {
      content = _generatedCover();
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF252A3A).withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }
}

// ============================================================
// API SERVICE
// ============================================================

class _FinalLoanDateFix {
  static dynamic fix(dynamic data) {
    const demo = String.fromEnvironment('DEMO_TODAY');

    final now = demo.isNotEmpty ? DateTime.parse(demo) : DateTime.now();

    final today = DateTime.utc(now.year, now.month, now.day);

    void update(dynamic record) {
      if (record is! Map) return;

      if ((record['status']?.toString().toLowerCase() ?? '') != 'issued')
        return;

      final raw = record['due_date']?.toString() ?? '';
      if (raw.length < 10) return;

      final parsed = DateTime.tryParse(raw)?.toLocal();
      if (parsed == null) return;

      final due = DateTime.utc(parsed.year, parsed.month, parsed.day);

      final remaining = due.difference(today).inDays;
      final overdue = remaining < 0 ? -remaining : 0;
      final fine = overdue * 25.0;

      record['days_remaining'] = remaining;
      record['daysRemaining'] = remaining;
      record['days_overdue'] = overdue;
      record['overdue_days'] = overdue;
      record['overdueDays'] = overdue;
      record['display_status'] = overdue > 0 ? 'Overdue' : 'Issued';
      if (demo.isNotEmpty || record['calculated_fine'] == null) {
        record['calculated_fine'] = fine;
        record['estimated_fine'] = fine;
      }
    }

    if (data is List) {
      for (final item in data) {
        update(item);
      }
    } else if (data is Map) {
      update(data);

      for (final value in data.values) {
        if (value is List) {
          for (final item in value) {
            update(item);
          }
        }
      }
    }

    return data;
  }
}

class ApiService {
  static dynamic _fixLoanDates(String path, dynamic data) {
    if (!path.startsWith('/loans') || data is! List) return data;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final loan in data) {
      if (loan is! Map) continue;

      final raw = loan['due_date']?.toString() ?? '';
      if (raw.length < 10) continue;

      final parsed = DateTime.tryParse(raw)?.toLocal();
      if (parsed == null) continue;

      final due = DateTime(parsed.year, parsed.month, parsed.day);
      final days = due.difference(today).inDays;

      loan['days_remaining'] = days;

      if (loan['status']?.toString().toLowerCase() == 'issued') {
        loan['display_status'] = days < 0 ? 'Overdue' : 'Issued';
      }
    }

    return data;
  }

  static String? token;
  static String? userName;
  static String? role;
  static String? email;
  static int? memberId;

  static const Duration requestTimeout = Duration(seconds: 12);

  static Map<String, String> get headers {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static dynamic _correctLoanSnapshot(String path, dynamic data) {
    const double finePerDay = 25.0;

    const demoDay = String.fromEnvironment('DEMO_TODAY');
    final now = demoDay.isEmpty ? DateTime.now() : DateTime.parse(demoDay);
    final today = DateTime.utc(now.year, now.month, now.day);

    void correct(Map loan, {bool receipt = false}) {
      if (loan['status']?.toString().toLowerCase() != 'issued') {
        return;
      }

      final raw = loan['due_date']?.toString() ?? '';
      if (raw.length < 10) return;

      final parsed = DateTime.tryParse(raw)?.toLocal();
      if (parsed == null) return;

      final due = DateTime.utc(parsed.year, parsed.month, parsed.day);

      final days = due.difference(today).inDays;
      final overdueDays = days < 0 ? -days : 0;
      final estimatedFine = overdueDays * finePerDay;

      loan['days_remaining'] = days;
      loan['display_status'] = overdueDays > 0 ? 'Overdue' : 'Issued';

      if (demoDay.isNotEmpty || loan['calculated_fine'] == null) {
        loan['calculated_fine'] = estimatedFine;
      }

      if (receipt) {
        loan['estimated_fine'] = estimatedFine;
      }
    }

    if (path.startsWith('/loans') && data is List) {
      for (final loan in data) {
        if (loan is Map) correct(loan);
      }
    }

    if (path.startsWith('/loans/') &&
        path.endsWith('/receipt') &&
        data is Map) {
      correct(data, receipt: true);
    }

    return data;
  }

  static Future<dynamic> get(String path) async {
    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl$path'), headers: headers)
          .timeout(const Duration(seconds: 12));

      return _correctLoanSnapshot(path, _handleResponse(response));
    } on TimeoutException {
      throw Exception(
        'Backend did not respond. Check whether the Node.js server is running.',
      );
    }
  }

  static Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl$path'),
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));

      return _handleResponse(response);
    } on TimeoutException {
      throw Exception(
        'Backend did not respond. Check whether the Node.js server is running.',
      );
    }
  }

  static Future<dynamic> put(String path, [Map<String, dynamic>? body]) async {
    try {
      final response = await http
          .put(
            Uri.parse('$apiBaseUrl$path'),
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(requestTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw Exception(
        'Backend did not respond. Check whether the Node.js server is running.',
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Unable to connect to backend');
    }
  }

  static Future<dynamic> delete(String path) async {
    try {
      final response = await http
          .delete(Uri.parse('$apiBaseUrl$path'), headers: headers)
          .timeout(requestTimeout);

      return _handleResponse(response);
    } on TimeoutException {
      throw Exception(
        'Backend did not respond. Check whether the Node.js server is running.',
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Unable to connect to backend');
    }
  }

  static dynamic _handleResponse(http.Response response) {
    dynamic data;

    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        data = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _FinalLoanDateFix.fix(data);
    }

    String message = 'Request failed (${response.statusCode})';

    if (data is Map && data['message'] != null) {
      message = data['message'].toString();
    }

    throw Exception(message);
  }

  static Future<http.Response> getRaw(String path) async {
    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl$path'), headers: headers)
          .timeout(requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _handleResponse(response);
      }

      return response;
    } on TimeoutException {
      throw Exception(
        'Backend did not respond. Check whether the Node.js server is running.',
      );
    }
  }

  static void downloadWebFile({
    required String path,
    required String filename,
  }) {
    final authToken = token?.trim() ?? '';
    if (authToken.isEmpty) {
      throw Exception('Your login session is missing. Please sign in again.');
    }

    final uri = Uri.parse('$apiBaseUrl$path');
    final downloadUri = uri.replace(
      queryParameters: {...uri.queryParameters, 'token': authToken},
    );
    final anchor = html.AnchorElement(href: downloadUri.toString())
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
  }

  static Future<void> _applyAuthResponse(dynamic data) async {
    if (data is! Map) {
      throw Exception('Invalid authentication response');
    }

    final newToken = data['token']?.toString();
    if (newToken == null || newToken.isEmpty) {
      throw Exception('Authentication token was not returned');
    }

    final rawUser = data['user'];
    if (rawUser is! Map) {
      throw Exception('User information was not returned');
    }

    token = newToken;
    final user = Map<String, dynamic>.from(rawUser);
    userName = user['name']?.toString();
    email = user['email']?.toString();
    role = user['role']?.toString();
    memberId = toInt(user['memberId'] ?? user['member_id']);
    if (memberId == 0) memberId = null;

    await saveSession();
  }

  static Future<void> login(String identifier, String password) async {
    final cleanedIdentifier = identifier.trim();

    if (cleanedIdentifier.isEmpty || password.isEmpty) {
      throw Exception('Email / Member ID and password are required');
    }

    final data = await post('/auth/login', {
      'identifier': cleanedIdentifier,
      'password': password,
    });

    await _applyAuthResponse(data);
  }

  static Future<void> activateMemberAccount({
    required String memberCode,
    required String registeredContact,
    required String password,
  }) async {
    final data = await post('/auth/member-register', {
      'memberCode': memberCode.trim(),
      'registeredContact': registeredContact.trim(),
      'password': password,
    });

    await _applyAuthResponse(data);
  }

  static Future<void> saveSession() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('token', token ?? '');
    await prefs.setString('userName', userName ?? '');
    await prefs.setString('email', email ?? '');
    await prefs.setString('role', role ?? '');

    if (memberId != null) {
      await prefs.setInt('memberId', memberId!);
    } else {
      await prefs.remove('memberId');
    }
  }

  static Future<bool> restoreLogin() async {
    final prefs = await SharedPreferences.getInstance();

    token = prefs.getString('token');
    userName = prefs.getString('userName');
    email = prefs.getString('email');
    role = prefs.getString('role');
    memberId = prefs.getInt('memberId');

    if (token == null || token!.isEmpty) {
      return false;
    }

    try {
      final data = await get('/auth/me');
      userName = data['name']?.toString();
      email = data['email']?.toString();
      role = data['role']?.toString();
      memberId = toInt(data['memberId'] ?? data['member_id']);
      if (memberId == 0) memberId = null;

      await saveSession();
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  static Future<void> logout() async {
    token = null;
    userName = null;
    email = null;
    role = null;
    memberId = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

// ============================================================
// APP
// ============================================================

class LibraryApp extends StatelessWidget {
  const LibraryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Library Management System',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Segoe UI Variable',
        scaffoldBackgroundColor: AppColors.canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
          ),
          headlineMedium: TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
          titleLarge: TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w700,
          ),
          bodyMedium: TextStyle(color: AppColors.text, height: 1.45),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.ink,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.line),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF9FAFF),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 17,
          ),
          hintStyle: const TextStyle(color: AppColors.muted),
          labelStyle: const TextStyle(color: AppColors.text),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.ink,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        // LIBRARY_UI_POLISH_20261101_V1
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.ink,
            side: const BorderSide(color: AppColors.line),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryDark,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          elevation: 3,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.line,
          thickness: 1,
        ),
      ),
      home: const StartupPage(),
    );
  }
}

// ============================================================
// STARTUP
// ============================================================

class StartupPage extends StatefulWidget {
  const StartupPage({super.key});

  @override
  State<StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<StartupPage> {
  @override
  void initState() {
    super.initState();

    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final logged = await ApiService.restoreLogin();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => logged ? const HomePage() : const LoginPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// ============================================================
// LOGIN
// ============================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool hidden = true;
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  Future<void> login() async {
    if (loading) return;
    setState(() => loading = true);

    try {
      await ApiService.login(emailController.text, passwordController.text);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (_, animation, __) => const HomePage(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showAppMessage(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _activateMemberAccount() async {
    final memberCode = TextEditingController();
    final contact = TextEditingController();
    final password = TextEditingController();
    final confirm = TextEditingController();

    bool hidePassword = true;
    bool hideConfirm = true;
    bool saving = false;
    String? errorText;

    final activated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            void setError(String message) {
              if (!dialogContext.mounted) return;

              setLocal(() {
                errorText = message;
                saving = false;
              });
            }

            Future<void> submit() async {
              if (saving) return;

              final code = memberCode.text.trim();
              final registered = contact.text.trim();
              final pass = password.text;
              final pass2 = confirm.text;

              setLocal(() {
                errorText = null;
              });

              if (code.isEmpty) {
                setError('Member ID is required.');
                return;
              }

              if (registered.isEmpty) {
                setError('Registered email or phone number is required.');
                return;
              }

              if (pass.isEmpty) {
                setError('Password is required.');
                return;
              }

              if (pass.length < 6) {
                setError('Password must contain at least 6 characters.');
                return;
              }

              if (pass != pass2) {
                setError('Passwords do not match.');
                return;
              }

              setLocal(() {
                saving = true;
                errorText = null;
              });

              try {
                await ApiService.activateMemberAccount(
                  memberCode: code,
                  registeredContact: registered,
                  password: pass,
                );

                if (!dialogContext.mounted) return;

                Navigator.of(dialogContext).pop(true);
              } catch (e) {
                setError(cleanError(e));
              }
            }

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),

              contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 8),

              actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),

              title: const Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primarySoft,
                    child: Icon(Icons.badge_outlined, color: AppColors.primary),
                  ),

                  SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Activate member account',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),

                        SizedBox(height: 3),

                        Text(
                          'For members already created by library staff.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              content: SizedBox(
                width: 500,

                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      Container(
                        width: double.infinity,

                        padding: const EdgeInsets.all(14),

                        decoration: BoxDecoration(
                          color: AppColors.primaryFaint,

                          borderRadius: BorderRadius.circular(14),

                          border: Border.all(color: const Color(0xFFE6E3FF)),
                        ),

                        child: const Text(
                          'Enter the exact Member ID and registered email or phone. If you registered using Create an account and Admin already approved you, use the normal Sign in form instead.',
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 11.5,
                            height: 1.45,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: memberCode,

                        textCapitalization: TextCapitalization.characters,

                        textInputAction: TextInputAction.next,

                        decoration: const InputDecoration(
                          labelText: 'Member ID',
                          hintText: 'MEM002',

                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: contact,

                        textInputAction: TextInputAction.next,

                        decoration: const InputDecoration(
                          labelText: 'Registered email or phone',

                          hintText: 'name@example.com or 0771234567',

                          prefixIcon: Icon(Icons.person_search_outlined),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: password,
                        obscureText: hidePassword,

                        textInputAction: TextInputAction.next,

                        decoration: InputDecoration(
                          labelText: 'Create password',

                          prefixIcon: const Icon(Icons.lock_outline_rounded),

                          suffixIcon: IconButton(
                            tooltip: hidePassword
                                ? 'Show password'
                                : 'Hide password',

                            onPressed: () {
                              setLocal(() {
                                hidePassword = !hidePassword;
                              });
                            },

                            icon: Icon(
                              hidePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextField(
                        controller: confirm,
                        obscureText: hideConfirm,

                        onSubmitted: (_) => submit(),

                        decoration: InputDecoration(
                          labelText: 'Confirm password',

                          prefixIcon: const Icon(Icons.lock_reset_rounded),

                          suffixIcon: IconButton(
                            tooltip: hideConfirm
                                ? 'Show password'
                                : 'Hide password',

                            onPressed: () {
                              setLocal(() {
                                hideConfirm = !hideConfirm;
                              });
                            },

                            icon: Icon(
                              hideConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),

                      if (errorText != null) ...[
                        const SizedBox(height: 14),

                        Container(
                          width: double.infinity,

                          padding: const EdgeInsets.all(12),

                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),

                            borderRadius: BorderRadius.circular(12),

                            border: Border.all(color: const Color(0xFFFFCDD2)),
                          ),

                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.red,
                                size: 20,
                              ),

                              const SizedBox(width: 9),

                              Expanded(
                                child: Text(
                                  errorText!,

                                  style: const TextStyle(
                                    color: AppColors.red,
                                    fontSize: 11,
                                    height: 1.35,

                                    fontWeight: FontWeight.w700,
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

              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop(false);
                        },

                  child: const Text('Cancel'),
                ),

                FilledButton.icon(
                  onPressed: saving ? null : submit,

                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,

                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.login_rounded),

                  label: Text(saving ? 'Activating...' : 'Activate & sign in'),
                ),
              ],
            );
          },
        );
      },
    );

    memberCode.dispose();
    contact.dispose();
    password.dispose();
    confirm.dispose();

    if (activated == true && mounted) {
      showAppMessage(context, 'Member account activated successfully');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Widget _brand() {
    return const Row(
      children: [
        ContainerLibraryLogo(size: 50),
        SizedBox(width: 13),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LIBRARY',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
                fontSize: 21,
                letterSpacing: 0.4,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Digital management suite',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _heroPanel() {
    return ColoredBox(
      color: const Color(0xFFF4F5FA),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(54, 34, 46, 30),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 64,
              ),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _brand(),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 15,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 7),
                            Text(
                              'MODERN LIBRARY EXPERIENCE',
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Discover more.\nManage less.',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 48,
                          height: 1.02,
                          letterSpacing: -1.8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 575),
                        child: const Text(
                          'A calm, intelligent workspace for books, members, circulation, reservations and library insights.',
                          style: TextStyle(
                            color: AppColors.muted,
                            height: 1.55,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _LoginHeroImageCard(),
                      const SizedBox(height: 18),
                      const Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children: [
                          _LoginFeature(
                            icon: Icons.auto_stories_outlined,
                            text: 'Smart catalogue',
                          ),
                          _LoginFeature(
                            icon: Icons.people_outline,
                            text: 'Member services',
                          ),
                          _LoginFeature(
                            icon: Icons.analytics_outlined,
                            text: 'Live insights',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _formPanel() {
    return Container(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 38),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Sign in to continue to your personalized library workspace.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 36),
                    const Text(
                      'Email or Member ID',
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        hintText: 'name@library.com or MEM002',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Password',
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: hidden,
                      onSubmitted: (_) => login(),
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => hidden = !hidden),
                          icon: Icon(
                            hidden
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.ink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: loading ? null : login,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: loading
                              ? const SizedBox(
                                  key: ValueKey('loader'),
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Row(
                                  key: ValueKey('label'),
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Sign in',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Icon(Icons.arrow_forward_rounded, size: 18),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: loading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterPage(),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text(
                          'Create an account',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          side: const BorderSide(color: Color(0xFFDCD8FF)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: loading ? null : _activateMemberAccount,
                        child: const Text(
                          'Already registered by the library? Activate with Member ID',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        'New public registrations require administrator approval before sign-in.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFaint,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE7E6FF)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              'Role-based secure access for administrators, librarians and members.',
                              style: TextStyle(
                                color: AppColors.text,
                                height: 1.45,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        'Library Management System  -  Secure local workspace',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 940;

    return Scaffold(
      backgroundColor: Colors.white,
      body: wide
          ? Row(
              children: [
                Expanded(flex: 11, child: _heroPanel()),
                Expanded(flex: 9, child: _formPanel()),
              ],
            )
          : _formPanel(),
    );
  }
}

// ============================================================
// PUBLIC REGISTRATION REQUEST
// ============================================================

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  bool loading = false;
  bool hidePassword = true;
  bool hideConfirm = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (loading) return;

    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final address = addressController.text.trim();
    final password = passwordController.text;
    final confirm = confirmController.text;

    if (name.isEmpty) {
      showAppMessage(context, 'Full name is required');
      return;
    }

    if (email.isEmpty) {
      showAppMessage(context, 'Email address is required');
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      showAppMessage(context, 'Enter a valid email address');
      return;
    }

    if (password.isEmpty) {
      showAppMessage(context, 'Password is required');
      return;
    }

    if (password.length < 6) {
      showAppMessage(context, 'Password must contain at least 6 characters');
      return;
    }

    if (password != confirm) {
      showAppMessage(context, 'Passwords do not match');
      return;
    }

    setState(() => loading = true);

    try {
      final data = await ApiService.post('/registration-requests', {
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'password': password,
      });

      if (!mounted) return;

      final message = data is Map && data['message'] != null
          ? data['message'].toString()
          : 'Registration submitted successfully. Please wait for administrator approval.';

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Row(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFFEAFBF5),
                  child: Icon(
                    Icons.mark_email_read_outlined,
                    color: AppColors.mint,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Request submitted',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(color: AppColors.text, height: 1.5),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Back to sign in'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showAppMessage(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 980;

    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 34),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to sign in'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Join the library',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 39,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Create a membership request. An administrator will review it before your account becomes active.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              _fieldLabel('Full name'),
              TextField(
                controller: nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Enter your full name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 16),
              _fieldLabel('Email address'),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'name@example.com',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
              const SizedBox(height: 16),
              _fieldLabel('Phone number'),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '0771234567',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 16),
              _fieldLabel('Address'),
              TextField(
                controller: addressController,
                textInputAction: TextInputAction.next,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Enter your address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 16),
              _fieldLabel('Password'),
              TextField(
                controller: passwordController,
                obscureText: hidePassword,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Minimum 6 characters',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: hidePassword ? 'Show password' : 'Hide password',
                    onPressed: () {
                      setState(() => hidePassword = !hidePassword);
                    },
                    icon: Icon(
                      hidePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _fieldLabel('Confirm password'),
              TextField(
                controller: confirmController,
                obscureText: hideConfirm,
                onSubmitted: (_) => submit(),
                decoration: InputDecoration(
                  hintText: 'Enter the password again',
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                  suffixIcon: IconButton(
                    tooltip: hideConfirm ? 'Show password' : 'Hide password',
                    onPressed: () {
                      setState(() => hideConfirm = !hideConfirm);
                    },
                    icon: Icon(
                      hideConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: loading ? null : submit,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    loading
                        ? 'Submitting request...'
                        : 'Submit registration request',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryFaint,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFFE2DFFF)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      color: AppColors.primary,
                      size: 19,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You cannot sign in immediately. After Admin approval, a Member ID is created and you can sign in with your email and password.',
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 11,
                          height: 1.45,
                        ),
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

    final information = Container(
      color: const Color(0xFFF4F5FA),
      padding: const EdgeInsets.all(52),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  ContainerLibraryLogo(size: 52),
                  SizedBox(width: 13),
                  Text(
                    'LIBRARY',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 38),
              const Text(
                'Your membership starts\nwith a simple request.',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 43,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.3,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Submit your details securely. Library administration reviews new applications before granting member access.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),
              ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: SizedBox(
                  height: 310,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/library_reader.png',
                        fit: BoxFit.cover,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x12000000), Color(0xB5151826)],
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 22,
                        bottom: 22,
                        child: Text(
                          'REQUEST   -   APPROVE   -   READ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: wide
          ? Row(
              children: [
                Expanded(flex: 10, child: information),
                Expanded(flex: 9, child: form),
              ],
            )
          : form,
    );
  }
}

class _LoginHeroImageCard extends StatefulWidget {
  const _LoginHeroImageCard();

  @override
  State<_LoginHeroImageCard> createState() => _LoginHeroImageCardState();
}

class _LoginHeroImageCardState extends State<_LoginHeroImageCard> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        height: 355,
        transform: hover
            ? Matrix4.translationValues(0, -4, 0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(hover ? 0.14 : 0.08),
              blurRadius: hover ? 34 : 22,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/library_login_main.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0.0, -0.08),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x16000000),
                    Color(0x26000000),
                    Color(0xD6101014),
                  ],
                  stops: [0.0, 0.52, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 18,
              right: 18,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                  child: Container(
                    width: 178,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.76),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.75)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/library_reader.png',
                            width: 48,
                            height: 58,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Curated discovery',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 11,
                                  height: 1.15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Find your next read',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'BROWSE   -   CHOOSE   -   READ',
                          style: TextStyle(
                            color: Color(0xFFDADBE5),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'A library experience\nthat feels effortless.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            height: 1.04,
                            letterSpacing: -0.7,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'SMART',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginFeature extends StatelessWidget {
  final IconData icon;
  final String text;

  const _LoginFeature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class LibrarySceneBanner extends StatelessWidget {
  final String imagePath;
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final double height;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const LibrarySceneBanner({
    super.key,
    required this.imagePath,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.height = 158,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(imagePath, fit: BoxFit.cover),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 1.15, sigmaY: 1.15),
              child: const SizedBox.expand(),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xE5101014),
                    Color(0xB6101014),
                    Color(0x40101014),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eyebrow.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFC8C6FF),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFD2D4DE),
                            fontSize: 11.5,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.14),
                          ),
                        ),
                        child: Icon(icon, color: Colors.white, size: 26),
                      ),
                      if (actionLabel != null && onAction != null) ...[
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: onAction,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.ink,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            minimumSize: const Size(0, 38),
                          ),
                          icon: Icon(
                            actionIcon ?? Icons.arrow_forward_rounded,
                            size: 16,
                          ),
                          label: Text(
                            actionLabel!,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PageStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color accent;

  const PageStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.11),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: accent, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 10.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 8.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardSceneHero extends StatelessWidget {
  final String greeting;
  final String userName;
  final double availability;
  final int activeLoans;
  final int overdueLoans;

  const DashboardSceneHero({
    super.key,
    required this.greeting,
    required this.userName,
    required this.availability,
    required this.activeLoans,
    required this.overdueLoans,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: SizedBox(
        height: 320,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/library_modern.png', fit: BoxFit.cover),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
              child: const SizedBox.expand(),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xF1161827),
                    Color(0xDB232744),
                    Color(0x8F20243B),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  final info = Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.12),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: Color(0xFFD5D2FF),
                              size: 13,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'LIVE LIBRARY WORKSPACE',
                              style: TextStyle(
                                color: Color(0xFFD5D2FF),
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 17),
                      Text(
                        '$greeting, $userName',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 9),
                      const Text(
                        'A visual command center for collection health, circulation, members and operational performance.',
                        style: TextStyle(
                          color: Color(0xFFD0D3DF),
                          fontSize: 11.3,
                          height: 1.45,
                        ),
                      ),
                    ],
                  );

                  final health = Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171A29).withOpacity(0.68),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 76,
                          height: 76,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: availability,
                                strokeWidth: 8,
                                backgroundColor: Colors.white.withOpacity(0.10),
                                color: AppColors.mint,
                              ),
                              Center(
                                child: Text(
                                  '${(availability * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Collection readiness',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '$activeLoans active loans  -  $overdueLoans overdue',
                                style: const TextStyle(
                                  color: Color(0xFFB9C0D2),
                                  fontSize: 9.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _HeroMiniPill(
                                    icon: Icons.swap_horiz_rounded,
                                    text: '$activeLoans active',
                                  ),
                                  const SizedBox(width: 7),
                                  _HeroMiniPill(
                                    icon: Icons.warning_amber_rounded,
                                    text: '$overdueLoans overdue',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: info),
                        const SizedBox(height: 12),
                        health,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(flex: 7, child: info),
                      const SizedBox(width: 28),
                      Expanded(flex: 4, child: health),
                    ],
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

class _HeroMiniPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroMiniPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 12),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// NAV ITEM
// ============================================================

class NavigationItem {
  final String title;
  final IconData icon;
  final Widget page;

  NavigationItem({required this.title, required this.icon, required this.page});
}

// ============================================================
// INTERACTIVE UI HELPERS
// ============================================================

class HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double radius;

  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.radius = 22,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: hover ? 1.004 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: hover
                ? Matrix4.translationValues(0, -2, 0)
                : Matrix4.identity(),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(widget.radius),
              border: Border.all(
                color: hover ? const Color(0xFFDAD7FF) : AppColors.line,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(hover ? 0.065 : 0.018),
                  blurRadius: hover ? 28 : 14,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class Reveal extends StatelessWidget {
  final Widget child;
  final int delayMs;

  const Reveal({super.key, required this.child, this.delayMs = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 520 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;

    switch (status.toLowerCase()) {
      case 'active':
      case 'returned':
      case 'paid':
      case 'completed':
        background = const Color(0xFFEFFBF4);
        foreground = const Color(0xFF16794B);
        break;
      case 'admin':
        background = AppColors.primarySoft;
        foreground = AppColors.primaryDark;
        break;
      case 'issued':
      case 'pending':
      case 'librarian':
        background = const Color(0xFFFFF5E9);
        foreground = const Color(0xFFA15C08);
        break;
      case 'overdue':
      case 'unpaid':
      case 'cancelled':
      case 'inactive':
        background = const Color(0xFFFFEEEE);
        foreground = AppColors.red;
        break;
      default:
        background = const Color(0xFFF1F1F4);
        foreground = AppColors.text;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}

class SidebarButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const SidebarButton({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        child: Ink(
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF6E63F6), Color(0xFF8D75FF)],
                  )
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(13),
            hoverColor: Colors.white.withOpacity(0.055),
            splashColor: Colors.white.withOpacity(0.10),
            highlightColor: Colors.white.withOpacity(0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withOpacity(0.14)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: selected ? Colors.white : const Color(0xFFB6BDD0),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : const Color(0xFFD1D5E2),
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 34, color: AppColors.green),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                height: 1.45,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? note;
  final Color accent;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.note,
    this.accent = AppColors.primary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 170;

          final iconSize = compact ? 38.0 : 44.0;

          return Padding(
            padding: EdgeInsets.all(compact ? 14 : 17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(compact ? 12 : 15),
                      ),
                      child: Icon(icon, color: accent, size: compact ? 20 : 23),
                    ),

                    const Spacer(),

                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),

                    if (onTap != null) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: AppColors.muted,
                      ),
                    ],
                  ],
                ),

                SizedBox(height: compact ? 8 : 12),

                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: compact ? 26 : 29,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),

                SizedBox(height: compact ? 4 : 6),

                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 11.5 : 12.5,
                  ),
                ),

                if (note != null) ...[
                  const SizedBox(height: 4),

                  Flexible(
                    child: Text(
                      note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

// ============================================================
// HOME
// ============================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _staffPendingQuick = 0;

  Future<void> _refreshStaffInboxQuick() async {
    if (!['admin', 'librarian'].contains((ApiService.role ?? '').toLowerCase()))
      return;

    try {
      final data = await ApiService.get('/reservations');
      if (!mounted || data is! List) return;

      final count = data
          .where((r) => r['status']?.toString() == 'Pending')
          .length;

      if (count != _staffPendingQuick) {
        setState(() => _staffPendingQuick = count);
      }
    } catch (_) {}
  }

  Future<void> _openStaffInboxQuick() async {
    List<dynamic> pending = [];
    List<dynamic> reviews = [];

    try {
      final data = await ApiService.get('/reservations');
      if (data is List) {
        pending = data
            .where((r) => r['status']?.toString() == 'Pending')
            .toList();
      }
    } catch (_) {}

    try {
      final data = await ApiService.get('/reviews');

      if (data is List) reviews = data;

      if (data is Map && data['reviews'] is List) {
        reviews = List<dynamic>.from(data['reviews']);
      }
    } catch (_) {}

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('Staff Notifications'),
        content: SizedBox(
          width: 560,
          height: 420,
          child: ListView(
            children: [
              Text(
                'Pending Reservations (${pending.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              if (pending.isEmpty)
                const ListTile(title: Text('No pending reservations')),

              ...pending
                  .take(20)
                  .map(
                    (r) => ListTile(
                      leading: const Icon(Icons.bookmark_outline),
                      title: Text(r['book_title']?.toString() ?? 'Book'),
                      subtitle: Text(
                        'Requested by ${r['member_name'] ?? 'Member'}',
                      ),
                      onTap: () {
                        Navigator.pop(dc);
                        final index = items.indexWhere(
                          (n) => n.title == 'Reservations',
                        );
                        if (index >= 0 && mounted) {
                          setState(() => selectedIndex = index);
                        }
                      },
                    ),
                  ),

              const Divider(),

              Text(
                'Member Reviews (${reviews.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              if (reviews.isEmpty)
                const ListTile(title: Text('No reviews returned by API')),

              ...reviews
                  .take(20)
                  .map(
                    (r) => ListTile(
                      leading: const Icon(Icons.star_outline),
                      title: Text(r['book_title']?.toString() ?? 'Book review'),
                      subtitle: Text(
                        '${r['member_name'] ?? 'Member'}: '
                        '${r['rating'] ?? r['stars'] ?? '-'} / 5\n'
                        '${r['review'] ?? r['comment'] ?? ''}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dc),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  int selectedIndex = 0;
  int _pageRevision = 0;

  Timer? _notificationTimer;
  final Set<int> _seenNotificationIds = <int>{};

  List<dynamic> _homeNotifications = [];

  int get _unreadNotificationCount {
    return _homeNotifications.where((n) => n['is_read'] != true).length;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pollNotifications(initial: true);

      if ((ApiService.role ?? '').toLowerCase() == 'member') {
        // Old duplicate reading quiz disabled
      }
    });
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _pollNotifications(),
    );
  }

  Future<void> _pollNotifications({bool initial = false}) async {
    await _refreshStaffInboxQuick();
    try {
      final notificationData = await ApiService.get('/notifications');

      final combined = List<dynamic>.from(notificationData ?? []);

      // Admin notification centre also shows
      // pending public membership requests.
      if ((ApiService.role ?? '').toLowerCase() == 'admin') {
        try {
          final requests = await ApiService.get(
            '/registration-requests?status=Pending',
          );

          for (final raw in List<dynamic>.from(requests ?? [])) {
            if (raw is! Map) continue;

            combined.insert(0, <String, dynamic>{
              'id': 'registration_${raw['id']}',
              'title': 'New membership request',
              'message': '${raw['name'] ?? 'New user'} - ${raw['email'] ?? ''}',
              'type': 'Registration',
              'created_at': raw['requested_at'],
              'is_read': false,
            });
          }
        } catch (_) {
          // Regular notifications still work.
        }
      }

      if (!mounted) return;

      setState(() {
        _homeNotifications = combined;
      });
    } catch (_) {
      // Notification polling must never
      // interrupt normal library work.
    }
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();

    _activeAppToastTimer?.cancel();

    try {
      _activeAppToast?.remove();
    } catch (_) {}

    _activeAppToast = null;

    super.dispose();
  }

  List<NavigationItem> get items {
    final currentRole = (ApiService.role ?? '').toLowerCase();
    final isAdmin = currentRole == 'admin';
    final isLibrarian = currentRole == 'librarian';
    final isMember = currentRole == 'member';

    if (isMember) {
      return <NavigationItem>[
        NavigationItem(
          title: 'My Library',
          icon: Icons.space_dashboard_rounded,
          page: const MemberDashboardPage(),
        ),
        NavigationItem(
          title: 'Browse Books',
          icon: Icons.menu_book_rounded,
          page: const BooksPage(),
        ),
        NavigationItem(
          title: 'My Loans',
          icon: Icons.swap_horiz_rounded,
          page: const LoansPage(),
        ),
        NavigationItem(
          title: 'My Reservations',
          icon: Icons.bookmark_border_rounded,
          page: const ReservationsPage(),
        ),
        NavigationItem(
          title: 'AI Recommendations',
          icon: Icons.auto_awesome_rounded,
          page: const MemberRecommendationsPage(),
        ),
        NavigationItem(
          title: 'My Profile',
          icon: Icons.person_outline_rounded,
          page: const ProfilePage(),
        ),
      ];
    }

    final list = <NavigationItem>[
      NavigationItem(
        title: 'Dashboard',
        icon: Icons.dashboard_rounded,
        page: DashboardPage(onNavigate: _navigateToTitle),
      ),
      NavigationItem(
        title: 'Books',
        icon: Icons.menu_book_rounded,
        page: const BooksPage(),
      ),
      NavigationItem(
        title: 'Members',
        icon: Icons.groups_2_outlined,
        page: const MembersPage(),
      ),
      NavigationItem(
        title: 'Loans',
        icon: Icons.swap_horiz_rounded,
        page: const LoansPage(),
      ),
      NavigationItem(
        title: 'Reservations',
        icon: Icons.bookmark_border_rounded,
        page: const ReservationsPage(),
      ),
      NavigationItem(
        title: 'Reports',
        icon: Icons.query_stats_rounded,
        page: const ReportsPage(),
      ),
    ];

    // Librarian owns the library-intelligence workflow.
    if (isLibrarian) {
      list.add(
        NavigationItem(
          title: 'AI Insights',
          icon: Icons.auto_awesome_rounded,
          page: const AiInsightsPage(),
        ),
      );
    }

    // Admin owns user/security/audit administration, not AI operations.
    if (isAdmin) {
      list.addAll([
        NavigationItem(
          title: 'Users',
          icon: Icons.manage_accounts_outlined,
          page: const UsersPage(),
        ),
        NavigationItem(
          title: 'Audit Logs',
          icon: Icons.history_rounded,
          page: const AuditPage(),
        ),
      ]);
    }

    list.add(
      NavigationItem(
        title: 'Profile',
        icon: Icons.person_outline_rounded,
        page: const ProfilePage(),
      ),
    );

    return list;
  }

  void _navigateToTitle(String title) {
    final navItems = items;

    final index = navItems.indexWhere((item) => item.title == title);

    if (index < 0 || !mounted) {
      return;
    }

    setState(() {
      selectedIndex = index;
      _pageRevision++;
    });
  }

  Future<void> _lmsRateReturnedBook(Map<String, dynamic> item) async {
    final parts = (item['type']?.toString() ?? '').split(':');

    if (parts.length < 2) return;

    final bookId = int.tryParse(parts[1]);

    if (bookId == null) return;

    var rating = 0;
    final comment = TextEditingController();

    try {
      final selected = await showDialog<int>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, refresh) => AlertDialog(
            title: const Text('Review your returned book'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item['message']?.toString() ?? ''),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (i) => IconButton(
                        onPressed: () => refresh(() => rating = i + 1),
                        icon: Icon(
                          i < rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ),
                  TextField(
                    controller: comment,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Your review (optional)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: rating == 0
                    ? null
                    : () => Navigator.pop(ctx, rating),
                child: const Text('Submit review'),
              ),
            ],
          ),
        ),
      );

      if (selected == null) return;

      await ApiService.post('/reviews', {
        'bookId': bookId,
        'rating': selected,
        'comment': comment.text.trim(),
      });

      final id = toInt(item['id']);

      if (id > 0) {
        try {
          await http.patch(
            Uri.parse('$apiBaseUrl/notifications/$id/read'),
            headers: ApiService.headers,
          );
        } catch (_) {}
      }

      await _pollNotifications();

      if (mounted) {
        showAppMessage(context, 'Review saved. Thank you!');
      }
    } catch (error) {
      if (mounted) {
        showAppMessage(context, cleanError(error));
      }
    } finally {
      comment.dispose();
    }
  }

  Future<void> _openNotificationCenter() async {
    await _pollNotifications();

    if (!mounted) return;

    final items = List<dynamic>.from(_homeNotifications);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(22, 20, 14, 8),

          title: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.primarySoft,

                child: Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Text(
                  'Notifications',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),

              IconButton(
                tooltip: 'Refresh',
                onPressed: () {
                  Navigator.pop(dialogContext);

                  _openNotificationCenter();
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),

          content: SizedBox(
            width: 560,
            height: 500,

            child: items.isEmpty
                ? const Center(
                    child: EmptyState(
                      icon: Icons.notifications_none_rounded,

                      title: 'No notifications',

                      subtitle: 'New library updates will appear here.',
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,

                    separatorBuilder: (_, __) => const Divider(height: 1),

                    itemBuilder: (context, index) {
                      final raw = items[index];

                      if (raw is! Map) {
                        return const SizedBox.shrink();
                      }

                      final item = Map<String, dynamic>.from(raw);

                      final unread = item['is_read'] != true;

                      final title =
                          item['title']?.toString() ?? 'Library update';

                      final message = item['message']?.toString() ?? '';

                      final type = item['type']?.toString() ?? '';

                      final created = item['created_at'] ?? item['createdAt'];

                      return Container(
                        color: unread
                            ? AppColors.primaryFaint
                            : Colors.transparent,

                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),

                          leading: CircleAvatar(
                            backgroundColor: unread
                                ? AppColors.primarySoft
                                : const Color(0xFFF2F3F7),

                            child: Icon(
                              type == 'Registration'
                                  ? Icons.person_add_alt_1_rounded
                                  : Icons.notifications_active_outlined,

                              color: unread
                                  ? AppColors.primary
                                  : AppColors.muted,

                              size: 19,
                            ),
                          ),

                          title: Text(
                            title,

                            style: TextStyle(
                              color: AppColors.ink,

                              fontWeight: unread
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),

                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              if (message.isNotEmpty) ...[
                                const SizedBox(height: 4),

                                Text(
                                  message,

                                  style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],

                              if (created != null) ...[
                                const SizedBox(height: 5),

                                Text(
                                  formatDate(created),

                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ],
                          ),

                          trailing: type.startsWith('Review:')
                              ? TextButton.icon(
                                  icon: const Icon(
                                    Icons.star_outline_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Rate now'),
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                    _lmsRateReturnedBook(item);
                                  },
                                )
                              : unread
                              ? Container(
                                  width: 8,
                                  height: 8,

                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,

                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  void _openAiAssistant() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.32),
      builder: (dialogContext) {
        final width = MediaQuery.of(dialogContext).size.width;
        final height = MediaQuery.of(dialogContext).size.height;
        return Dialog(
          alignment: width >= 760 ? Alignment.centerRight : Alignment.center,
          insetPadding: EdgeInsets.all(width >= 760 ? 20 : 10),
          backgroundColor: Colors.transparent,
          child: SizedBox(
            width: width >= 760 ? 470 : width - 20,
            height: height >= 760 ? 690 : height - 40,
            child: const AiAssistantPanel(),
          ),
        );
      },
    );
  }

  String _subtitle(String page) {
    switch (page) {
      case 'Dashboard':
        return (ApiService.role ?? '').toLowerCase() == 'admin'
            ? 'System administration and library operational overview'
            : 'Live operational overview and AI-powered library intelligence';
      case 'My Library':
        return 'Your loans, reservations, notifications and reading activity';
      case 'Books':
        return 'Catalogue, availability and collection details';
      case 'Browse Books':
        return 'Discover available titles and reserve books for librarian pickup and issue';
      case 'Members':
        return 'Member records and borrowing activity';
      case 'Loans':
        return 'Issue, return and settle fines';
      case 'My Loans':
        return 'Your current loans, due dates, history and fines';
      case 'Reservations':
        return 'Manage book reservation requests';
      case 'My Reservations':
        return 'Track your reservation queue and pickup status';
      case 'AI Recommendations':
        return 'Popular, highly rated and personalised AI book suggestions';
      case 'Reports':
        return 'Operational insights and performance analytics';
      case 'AI Insights':
        return 'Anomaly detection, demand forecasting and intelligent signals';
      case 'Users':
        return 'Administrator, librarian and member account access';
      case 'Audit Logs':
        return 'Review important administrative actions';
      case 'Profile':
        return 'Account details and security preferences';
      case 'My Profile':
        return 'Your account details and security preferences';
      default:
        return '';
    }
  }

  Widget _sidebar(List<NavigationItem> navItems, {bool closeDrawer = false}) {
    return Container(
      width: 252,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.sidebarLine)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7367F0), Color(0xFF9A7DFF)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.local_library_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LIBRARY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Digital management suite',
                          style: TextStyle(
                            color: Color(0xFF8991A8),
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 18),
              color: AppColors.sidebarLine,
            ),

            const SizedBox(height: 14),

            const Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'WORKSPACE',
                  style: TextStyle(
                    color: Color(0xFF6F778E),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.45,
                  ),
                ),
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: navItems.length,
                itemBuilder: (context, index) {
                  final item = navItems[index];

                  final selected = selectedIndex == index;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 4,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        selected: selected,

                        selectedTileColor: AppColors.primary,

                        tileColor: Colors.transparent,

                        hoverColor: Colors.white.withOpacity(0.06),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),

                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 3,
                        ),

                        leading: Icon(
                          item.icon,
                          size: 19,
                          color: selected
                              ? Colors.white
                              : const Color(0xFFB6BDD0),
                        ),

                        title: Text(
                          item.title,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFFD1D5E2),
                            fontSize: 12.5,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),

                        trailing: selected
                            ? const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,

                        onTap: () {
                          debugPrint('NAV CLICK: ${item.title} -> $index');

                          if (closeDrawer) {
                            Navigator.of(context).pop();
                          }

                          if (!mounted) {
                            return;
                          }

                          _navigateToTitle(item.title);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),

            Container(
              margin: const EdgeInsets.fromLTRB(13, 8, 13, 14),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.sidebarSoft,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppColors.sidebarLine),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      (ApiService.userName?.isNotEmpty ?? false)
                          ? ApiService.userName![0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ApiService.userName ?? 'User',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ApiService.role ?? '',
                          style: const TextStyle(
                            color: Color(0xFF8E96AC),
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    tooltip: 'Logout',
                    onPressed: logout,
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 17,
                      color: Color(0xFFB5BDCF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topbar(List<NavigationItem> navItems) {
    final item = navItems[selectedIndex];
    final now = DateTime.now();
    final date =
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year}';

    final userName = ApiService.userName ?? 'User';
    final userEmail = ApiService.email ?? '';
    final userRole = ApiService.role ?? '';

    return Container(
      height: 92,
      padding: const EdgeInsets.fromLTRB(28, 0, 24, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;

          return Row(
            children: [
              // --------------------------------------------------
              // PAGE TITLE - ALWAYS LEFT ALIGNED
              // --------------------------------------------------
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    transitionBuilder: (child, animation) {
                      final slide =
                          Tween<Offset>(
                            begin: const Offset(0.015, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          );

                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                    child: Container(
                      key: ValueKey(item.title),
                      alignment: Alignment.centerLeft,
                      width: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontFamily: 'Segoe UI Variable',
                              fontFamilyFallback: [
                                'Segoe UI',
                                'Roboto',
                                'Arial',
                              ],
                              fontSize: 24,
                              height: 1.08,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.75,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _subtitle(item.title),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontFamily: 'Segoe UI Variable',
                              fontFamilyFallback: [
                                'Segoe UI',
                                'Roboto',
                                'Arial',
                              ],
                              fontSize: 11.5,
                              height: 1.25,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.05,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // --------------------------------------------------
              // DATE
              // --------------------------------------------------
              if (!compact) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        date,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontFamily: 'Segoe UI Variable',
                          fontFamilyFallback: ['Segoe UI', 'Roboto', 'Arial'],
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(width: 1, height: 38, color: AppColors.line),
                const SizedBox(width: 16),
              ],

              // --------------------------------------------------
              // USER DETAILS MOVED TO TOP BAR
              // --------------------------------------------------
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: _openNotificationCenter,
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.text,
                    ),
                  ),

                  if (_unreadNotificationCount > 0)
                    Positioned(
                      right: 4,
                      top: 4,

                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),

                        padding: const EdgeInsets.symmetric(horizontal: 4),

                        decoration: const BoxDecoration(
                          color: AppColors.red,
                          shape: BoxShape.circle,
                        ),

                        alignment: Alignment.center,

                        child: Text(
                          _unreadNotificationCount > 99
                              ? '99+'
                              : '$_unreadNotificationCount',

                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 8),

              CircleAvatar(
                radius: 21,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontFamily: 'Segoe UI Variable',
                    fontFamilyFallback: ['Segoe UI', 'Roboto', 'Arial'],
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              if (!compact) ...[
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontFamily: 'Segoe UI Variable',
                          fontFamilyFallback: ['Segoe UI', 'Roboto', 'Arial'],
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontFamily: 'Segoe UI Variable',
                          fontFamilyFallback: ['Segoe UI', 'Roboto', 'Arial'],
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (userRole.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.12),
                      ),
                    ),
                    child: Text(
                      userRole,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontFamily: 'Segoe UI Variable',
                        fontFamilyFallback: ['Segoe UI', 'Roboto', 'Arial'],
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _currentPage(List<NavigationItem> navItems) {
    return KeyedSubtree(
      key: ValueKey<String>('${selectedIndex}_$_pageRevision'),
      child: navItems[selectedIndex].page,
    );
  }

  @override
  Widget build(BuildContext context) {
    final navItems = items;
    if (selectedIndex >= navItems.length) selectedIndex = 0;
    final wide = MediaQuery.of(context).size.width >= 900;
    final aiEnabled = (ApiService.role ?? '').toLowerCase() != 'admin';

    if (!wide) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          titleSpacing: 18,
          title: Text(
            navItems[selectedIndex].title,
            style: const TextStyle(
              fontFamily: 'Segoe UI Variable',
              fontFamilyFallback: ['Segoe UI', 'Roboto', 'Arial'],
              fontWeight: FontWeight.w700,
              letterSpacing: -0.7,
            ),
          ),
        ),
        drawer: Drawer(
          backgroundColor: AppColors.sidebar,
          child: _sidebar(navItems, closeDrawer: true),
        ),
        body: _currentPage(navItems),
        floatingActionButton: aiEnabled
            ? FloatingActionButton.extended(
                onPressed: _openAiAssistant,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.auto_awesome_rounded, size: 19),
                label: const Text(
                  'Ask AI',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              )
            : null,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Row(
        children: [
          _sidebar(navItems),
          Expanded(
            child: Column(
              children: [
                _topbar(navItems),
                Expanded(child: _currentPage(navItems)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: aiEnabled
          ? FloatingActionButton.extended(
              onPressed: _openAiAssistant,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 8,
              icon: const Icon(Icons.auto_awesome_rounded, size: 19),
              label: const Text(
                'Ask AI',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          : null,
    );
  }
}

class ContainerLibraryLogo extends StatelessWidget {
  final double size;

  const ContainerLibraryLogo({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFF7A6FF0)],
        ),
        borderRadius: BorderRadius.circular(size * 0.29),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.20),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        Icons.local_library_rounded,
        color: Colors.white,
        size: size * 0.53,
      ),
    );
  }
}

// ============================================================
// COMMON MESSAGE
// ============================================================

OverlayEntry? _activeAppToast;
Timer? _activeAppToastTimer;

bool _looksLikeError(String text) {
  final t = text.toLowerCase();
  return t.contains('invalid') ||
      t.contains('failed') ||
      t.contains('error') ||
      t.contains('unable') ||
      t.contains('required') ||
      t.contains('inactive') ||
      t.contains('unavailable') ||
      t.contains('cannot') ||
      t.contains('already') ||
      t.contains('not found') ||
      t.contains('do not match');
}

bool _looksLikeSuccess(String text) {
  final t = text.toLowerCase();
  return t.contains('success') ||
      t.contains('created') ||
      t.contains('saved') ||
      t.contains('updated') ||
      t.contains('issued') ||
      t.contains('returned') ||
      t.contains('renewed') ||
      t.contains('paid') ||
      t.contains('download') ||
      t.contains('reserved') ||
      t.contains('activated') ||
      t.contains('ready for pickup');
}

void showAppMessage(BuildContext context, Object value) {
  final rawText = cleanError(value).trim();

  if (rawText.isEmpty) {
    return;
  }

  _activeAppToastTimer?.cancel();

  try {
    _activeAppToast?.remove();
  } catch (_) {}

  _activeAppToast = null;

  final isNotification = rawText.startsWith('[NOTIFICATION]');

  final text = rawText.replaceFirst('[NOTIFICATION]', '').trim();

  final isError = _looksLikeError(text);

  final isSuccess = !isError && _looksLikeSuccess(text);

  final title = isError
      ? 'Action needed'
      : isNotification
      ? 'Library notification'
      : isSuccess
      ? 'Success'
      : 'Library update';

  final accent = isError
      ? const Color(0xFFDC3F4F)
      : isNotification
      ? AppColors.primary
      : isSuccess
      ? const Color(0xFF20A47A)
      : AppColors.blue;

  final icon = isError
      ? Icons.error_outline_rounded
      : isNotification
      ? Icons.notifications_active_rounded
      : isSuccess
      ? Icons.check_circle_outline_rounded
      : Icons.info_outline_rounded;

  final overlay = Overlay.maybeOf(context, rootOverlay: true);

  if (overlay == null) {
    return;
  }

  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (overlayContext) {
      final top = MediaQuery.of(overlayContext).padding.top + 14;

      return Positioned(
        top: top,
        left: 18,
        right: 18,

        // IMPORTANT:
        // This toast can NEVER receive mouse/touch events.
        child: IgnorePointer(
          ignoring: true,

          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),

              child: Material(
                color: Colors.transparent,

                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),

                  decoration: BoxDecoration(
                    color: Colors.white,

                    borderRadius: BorderRadius.circular(18),

                    border: Border.all(color: AppColors.line),

                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x260B1020),
                        blurRadius: 28,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),

                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,

                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.11),

                          borderRadius: BorderRadius.circular(12),
                        ),

                        child: Icon(icon, color: accent, size: 21),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,

                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Text(
                              title,

                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),

                            const SizedBox(height: 3),

                            Text(
                              text,

                              maxLines: 3,

                              overflow: TextOverflow.ellipsis,

                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 11.5,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  _activeAppToast = entry;

  overlay.insert(entry);

  _activeAppToastTimer = Timer(const Duration(seconds: 4), () {
    if (_activeAppToast != entry) {
      return;
    }

    try {
      entry.remove();
    } catch (_) {}

    _activeAppToast = null;
  });
}

// ============================================================
// ============================================================
// DASHBOARD
// ============================================================

class DashboardPage extends StatefulWidget {
  final ValueChanged<String>? onNavigate;

  const DashboardPage({super.key, this.onNavigate});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool loading = true;
  Map<String, dynamic> stats = {};
  Map<String, dynamic> aiDemand = {};
  Map<String, dynamic> aiAnomalies = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final data = await ApiService.get('/dashboard');
      if (!mounted) return;
      setState(() => stats = Map<String, dynamic>.from(data));

      if ((ApiService.role ?? '').toLowerCase() == 'librarian') {
        try {
          final ai = await Future.wait([
            ApiService.get('/ai/demand-forecast?months=6&limit=5'),
            ApiService.get('/ai/anomalies?limit=5'),
          ]);
          if (mounted) {
            setState(() {
              aiDemand = Map<String, dynamic>.from(ai[0]);
              aiAnomalies = Map<String, dynamic>.from(ai[1]);
            });
          }
        } catch (_) {
          // Dashboard still works when AI service is offline.
        }
      }
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );

    final titles = toDouble(stats['total_titles']);
    final copies = toDouble(stats['total_copies']);
    final available = toDouble(stats['available_copies']);
    final members = toDouble(stats['total_members']);
    final loans = toDouble(stats['active_loans']);
    final overdue = toDouble(stats['overdue_loans']);
    final unavailable = (copies - available)
        .clamp(0, double.infinity)
        .toDouble();
    final availability = copies <= 0
        ? 0.0
        : (available / copies).clamp(0.0, 1.0).toDouble();

    return RefreshIndicator(
      onRefresh: load,
      color: AppColors.primary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final cols = width >= 1180
              ? 4
              : width >= 760
              ? 2
              : 1;
          const gap = 16.0;
          final cardWidth = cols == 4
              ? (width - 52 - gap * 3) / 4
              : cols == 2
              ? (width - 52 - gap) / 2
              : width - 52;
          final split = width >= 980;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(26, 26, 26, 36),
            children: [
              DashboardSceneHero(
                greeting: _greeting(),
                userName: ApiService.userName ?? 'Admin',
                availability: availability,
                activeLoans: loans.toInt(),
                overdueLoans: overdue.toInt(),
              ),
              const SizedBox(height: 24),
              const SectionHeader(
                title: 'Overview',
                subtitle: 'Live totals from your PostgreSQL library database',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: cardWidth,
                    height: 158,
                    child: MetricCard(
                      label: 'Book Titles',
                      value: '${stats['total_titles'] ?? 0}',
                      icon: Icons.menu_book_rounded,
                      note: 'Unique catalogue titles',
                      accent: AppColors.primary,
                      onTap: () {
                        widget.onNavigate?.call('Books');
                      },
                    ),
                  ),

                  SizedBox(
                    width: cardWidth,
                    height: 158,
                    child: MetricCard(
                      label: 'Total Copies',
                      value: '${stats['total_copies'] ?? 0}',
                      icon: Icons.library_books_rounded,
                      note: 'Physical inventory',
                      accent: AppColors.blue,
                      onTap: () {
                        widget.onNavigate?.call('Books');
                      },
                    ),
                  ),

                  SizedBox(
                    width: cardWidth,
                    height: 158,
                    child: MetricCard(
                      label: 'Members',
                      value: '${stats['total_members'] ?? 0}',
                      icon: Icons.groups_2_outlined,
                      note: 'Registered members',
                      accent: AppColors.pink,
                      onTap: () {
                        widget.onNavigate?.call('Members');
                      },
                    ),
                  ),

                  SizedBox(
                    width: cardWidth,
                    height: 158,
                    child: MetricCard(
                      label: 'Active Loans',
                      value: '${stats['active_loans'] ?? 0}',
                      icon: Icons.swap_horiz_rounded,
                      note: 'Books currently issued',
                      accent: AppColors.cyan,
                      onTap: () {
                        widget.onNavigate?.call('Loans');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (split)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _AnalyticsPanel(
                        title: 'Operational snapshot',
                        subtitle: 'Current catalogue and circulation volumes',
                        child: SizedBox(
                          height: 250,
                          child: _CurrentVolumeBarChart(
                            titles: titles,
                            copies: copies,
                            members: members,
                            loans: loans,
                            overdue: overdue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: _AnalyticsPanel(
                        title: 'Collection status',
                        subtitle: 'Available vs currently unavailable copies',
                        child: SizedBox(
                          height: 250,
                          child: _AvailabilityDonut(
                            available: available,
                            unavailable: unavailable,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _AnalyticsPanel(
                      title: 'Operational snapshot',
                      subtitle: 'Current catalogue and circulation volumes',
                      child: SizedBox(
                        height: 250,
                        child: _CurrentVolumeBarChart(
                          titles: titles,
                          copies: copies,
                          members: members,
                          loans: loans,
                          overdue: overdue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _AnalyticsPanel(
                      title: 'Collection status',
                      subtitle: 'Available vs currently unavailable copies',
                      child: SizedBox(
                        height: 250,
                        child: _AvailabilityDonut(
                          available: available,
                          unavailable: unavailable,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              if (split)
                Row(
                  children: [
                    Expanded(
                      child: _PulseCard(
                        icon: Icons.check_circle_outline_rounded,
                        accent: AppColors.mint,
                        title: 'Availability',
                        value: '${(availability * 100).toStringAsFixed(0)}%',
                        subtitle:
                            '${stats['available_copies'] ?? 0} of ${stats['total_copies'] ?? 0} copies ready',
                        progress: availability,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _PulseCard(
                        icon: Icons.warning_amber_rounded,
                        accent: overdue > 0 ? AppColors.red : AppColors.amber,
                        title: 'Overdue attention',
                        value: '${stats['overdue_loans'] ?? 0}',
                        subtitle: overdue > 0
                            ? 'Loans need staff attention'
                            : 'No overdue loans right now',
                        progress: loans <= 0
                            ? 0
                            : (overdue / loans).clamp(0.0, 1.0).toDouble(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child:
                          (ApiService.role ?? '').toLowerCase() == 'librarian'
                          ? const _PulseCard(
                              icon: Icons.auto_awesome_rounded,
                              accent: AppColors.primary,
                              title: 'Smart workspace',
                              value: 'AI',
                              subtitle: 'Library intelligence and recommendation tools',
                              progress: 1,
                            )
                          : const _PulseCard(
                              icon: Icons.admin_panel_settings_outlined,
                              accent: AppColors.primary,
                              title: 'System control',
                              value: 'Admin',
                              subtitle: 'Users, access roles and audit administration',
                              progress: 1,
                            ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _PulseCard(
                      icon: Icons.check_circle_outline_rounded,
                      accent: AppColors.mint,
                      title: 'Availability',
                      value: '${(availability * 100).toStringAsFixed(0)}%',
                      subtitle:
                          '${stats['available_copies'] ?? 0} of ${stats['total_copies'] ?? 0} copies ready',
                      progress: availability,
                    ),
                    const SizedBox(height: 16),
                    _PulseCard(
                      icon: Icons.warning_amber_rounded,
                      accent: overdue > 0 ? AppColors.red : AppColors.amber,
                      title: 'Overdue attention',
                      value: '${stats['overdue_loans'] ?? 0}',
                      subtitle: overdue > 0
                          ? 'Loans need staff attention'
                          : 'No overdue loans right now',
                      progress: loans <= 0
                          ? 0
                          : (overdue / loans).clamp(0.0, 1.0).toDouble(),
                    ),
                    const SizedBox(height: 16),
                    (ApiService.role ?? '').toLowerCase() == 'librarian'
                        ? const _PulseCard(
                            icon: Icons.auto_awesome_rounded,
                            accent: AppColors.primary,
                            title: 'Smart workspace',
                            value: 'AI',
                            subtitle:
                                'Library intelligence and recommendation tools',
                            progress: 1,
                          )
                        : const _PulseCard(
                            icon: Icons.admin_panel_settings_outlined,
                            accent: AppColors.primary,
                            title: 'System control',
                            value: 'Admin',
                            subtitle:
                                'Users, access roles and audit administration',
                            progress: 1,
                          ),
                  ],
                ),
              if ((ApiService.role ?? '').toLowerCase() == 'librarian') ...[
                const SizedBox(height: 24),
                _DashboardAiInsights(
                  demand: List<dynamic>.from(aiDemand['forecast'] ?? []),
                  anomalies: List<dynamic>.from(aiAnomalies['anomalies'] ?? []),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AnalyticsPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _AnalyticsPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF24263A).withOpacity(0.045),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _CurrentVolumeBarChart extends StatelessWidget {
  final double titles, copies, members, loans, overdue;
  const _CurrentVolumeBarChart({
    required this.titles,
    required this.copies,
    required this.members,
    required this.loans,
    required this.overdue,
  });
  @override
  Widget build(BuildContext context) {
    final values = [titles, copies, members, loans, overdue];
    final maxValue = values.fold<double>(1, (p, v) => v > p ? v : p);
    const labels = ['Titles', 'Copies', 'Members', 'Loans', 'Overdue'];
    const colors = [
      AppColors.primary,
      AppColors.blue,
      AppColors.pink,
      AppColors.cyan,
      AppColors.red,
    ];
    return BarChart(
      BarChartData(
        maxY: maxValue * 1.25,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue <= 4 ? 1 : (maxValue / 4).ceilToDouble(),
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0xFFF0F1F5), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: maxValue <= 4 ? 1 : (maxValue / 4).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                if (value < 0 || value > maxValue * 1.25) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    value.toInt().toString(),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    labels[i],
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(
          values.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: values[i],
                width: 22,
                color: colors[i],
                borderRadius: BorderRadius.circular(7),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxValue * 1.25,
                  color: const Color(0xFFF2F3F7),
                ),
              ),
            ],
          ),
        ),
      ),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
    );
  }
}

class _AvailabilityDonut extends StatelessWidget {
  final double available, unavailable;
  const _AvailabilityDonut({
    required this.available,
    required this.unavailable,
  });
  @override
  Widget build(BuildContext context) {
    final total = available + unavailable;
    final pct = total <= 0 ? 0.0 : available / total * 100;
    return Row(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  centerSpaceRadius: 48,
                  sectionsSpace: 3,
                  sections: [
                    PieChartSectionData(
                      value: total <= 0 ? 1 : available,
                      color: AppColors.mint,
                      radius: 18,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: total <= 0 ? 0 : unavailable,
                      color: const Color(0xFFE9EBF2),
                      radius: 18,
                      showTitle: false,
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'available',
                    style: TextStyle(color: AppColors.muted, fontSize: 9.5),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendRow(
                color: AppColors.mint,
                title: 'Available',
                value: available.toInt().toString(),
              ),
              const SizedBox(height: 15),
              _LegendRow(
                color: const Color(0xFFD6DAE5),
                title: 'Unavailable',
                value: unavailable.toInt().toString(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String title, value;
  const _LegendRow({
    required this.color,
    required this.title,
    required this.value,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _DashboardAiInsights extends StatelessWidget {
  final List<dynamic> demand;
  final List<dynamic> anomalies;

  const _DashboardAiInsights({required this.demand, required this.anomalies});

  @override
  Widget build(BuildContext context) {
    final highRisk = anomalies.where((x) => x['anomaly'] == true).toList();
    return HoverCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
                SizedBox(width: 9),
                Text(
                  'AI Insights',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text(
              'Demand forecasting and unusual borrowing signals from the Python ML service.',
              style: TextStyle(color: AppColors.muted, fontSize: 10.5),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Books likely to be demanded',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      if (demand.isEmpty)
                        const Text(
                          'AI forecast unavailable or not enough history yet.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                          ),
                        )
                      else
                        ...demand
                            .take(4)
                            .map(
                              (b) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.trending_up_rounded,
                                  color: AppColors.primary,
                                ),
                                title: Text(b['title']?.toString() ?? ''),
                                subtitle: Text(
                                  '${b['demand_level']} demand  -  next month ${b['predicted_next_month']} borrows',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unusual borrowing signals',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      if (highRisk.isEmpty)
                        const Text(
                          'No strong anomaly signal detected.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                          ),
                        )
                      else
                        ...highRisk
                            .take(4)
                            .map(
                              (m) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.amber,
                                ),
                                title: Text(
                                  '${m['member_code']}  -  ${m['name']}',
                                ),
                                subtitle: Text(
                                  'Anomaly score ${toDouble(m['anomaly_score']).toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title, value, subtitle;
  final double progress;
  const _PulseCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.progress,
  });
  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.11),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 19),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    color: accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                  begin: 0,
                  end: progress.clamp(0.0, 1.0).toDouble(),
                ),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, v, child) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF0F1F5),
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// AI ASSISTANT + AI INSIGHTS
// ============================================================

class AiAssistantPanel extends StatefulWidget {
  const AiAssistantPanel({super.key});

  @override
  State<AiAssistantPanel> createState() => _AiAssistantPanelState();
}

class _AiAssistantPanelState extends State<AiAssistantPanel> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final List<Map<String, dynamic>> messages = [];
  bool sending = false;

  @override
  void initState() {
    super.initState();
    final isStaff = [
      'admin',
      'librarian',
    ].contains((ApiService.role ?? '').toLowerCase());
    messages.add({
      'role': 'assistant',
      'text': isStaff
          ? 'Hi ${ApiService.userName ?? ''}. I can search the catalogue, inspect overdue activity, summarize fines, run anomaly detection and explain demand forecasts.'
          : 'Hi ${ApiService.userName ?? ''}. I can search books, check availability, show your loans and reservations, and recommend books for you.',
      'cards': <dynamic>[],
      'suggestions': isStaff
          ? <String>[
              'Show library overview',
              'Show anomaly alerts',
              'Forecast next month demand',
              'Which books are popular?',
            ]
          : <String>[
              'Show my loans',
              'Recommend a book for me',
              'Find available books',
              'Show my fines',
            ],
    });
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _smartLibraryFallback(String question) async {
    final q = question.toLowerCase();

    if (q.contains('recommend') ||
        q.contains('suggest') ||
        q.contains('book for me')) {
      final data = await ApiService.get('/preferences/recommendations?limit=5');

      final books = List<dynamic>.from(data['recommendations'] ?? []);

      return {
        'answer': books.isEmpty
            ? 'I do not have enough preference data yet. Complete your reading-preference quiz or borrow a few books first.'
            : 'Based on your reading preferences, these books are a good place to start.',

        'intent': 'preference_recommendation',

        'confidence': 0.75,

        'cards': books.take(5).map((raw) {
          final b = Map<String, dynamic>.from(raw as Map);

          return {
            'type': 'book',
            'title': b['title'] ?? 'Book',
            'subtitle': b['author'] ?? '',
            'meta': b['reason'] ?? b['category'] ?? '',
          };
        }).toList(),

        'suggestions': ['Show my loans', 'Find available books'],
      };
    }

    if (q.contains('fine')) {
      final raw = await ApiService.get('/loans');

      final loans = List<dynamic>.from(raw ?? []);

      double total = 0;

      for (final item in loans) {
        if (item is! Map) continue;

        if (item['fine_paid'] == true) {
          continue;
        }

        total += toDouble(item['fine']);
      }

      return {
        'answer':
            'Your current unpaid fine total is LKR ${formatMoney(total)}.',

        'intent': 'fines',
        'confidence': 0.9,
        'cards': <dynamic>[],
        'suggestions': ['Show my loans', 'Recommend a book for me'],
      };
    }

    if (q.contains('loan')) {
      final raw = await ApiService.get('/loans');

      final loans = List<dynamic>.from(raw ?? []);

      final active = loans
          .where((l) => l is Map && l['status'] == 'Issued')
          .toList();

      return {
        'answer':
            'You currently have ${active.length} active loan${active.length == 1 ? '' : 's'}.',

        'intent': 'loans',
        'confidence': 0.9,

        'cards': active.take(5).map((raw) {
          final l = Map<String, dynamic>.from(raw as Map);

          return {
            'type': 'loan',
            'title': l['book_title'] ?? 'Loan',
            'subtitle': 'Due ${formatDate(l['due_date'])}',
            'meta': l['display_status'] ?? l['status'] ?? '',
          };
        }).toList(),

        'suggestions': ['Show my fines', 'Recommend a book for me'],
      };
    }

    if (q.contains('reservation')) {
      final raw = await ApiService.get('/reservations');

      final list = List<dynamic>.from(raw ?? []);

      return {
        'answer':
            'You have ${list.length} reservation record${list.length == 1 ? '' : 's'}.',

        'intent': 'reservations',

        'confidence': 0.85,

        'cards': list.take(5).map((raw) {
          final r = Map<String, dynamic>.from(raw as Map);

          return {
            'type': 'reservation',
            'title': r['book_title'] ?? 'Reservation',
            'subtitle': r['status'] ?? '',
            'meta': 'Reserved ${formatDate(r['reservation_date'])}',
          };
        }).toList(),

        'suggestions': ['Show my loans', 'Find available books'],
      };
    }

    final raw = await ApiService.get('/books');

    final books = List<dynamic>.from(raw ?? []);

    final available = books
        .where((b) => b is Map && toInt(b['available_copies']) > 0)
        .toList();

    return {
      'answer':
          'The library currently has ${available.length} available title${available.length == 1 ? '' : 's'}. You can ask me for recommendations, loans, fines or reservations.',

      'intent': 'library_overview',

      'confidence': 0.65,

      'cards': available.take(5).map((raw) {
        final b = Map<String, dynamic>.from(raw as Map);

        return {
          'type': 'book',
          'title': b['title'] ?? 'Book',
          'subtitle': b['author'] ?? '',
          'meta': '${b['available_copies'] ?? 0} available',
        };
      }).toList(),

      'suggestions': [
        'Recommend a book for me',
        'Show my loans',
        'Show my fines',
      ],
    };
  }

  static const Map<String, List<String>> _topicAliases = {
    'travel': [
      'travel',
      'travels',
      'travelling',
      'traveling',
      'tour',
      'tourism',
      'trip',
      'trips',
      'journey',
      'journeys',
      'holiday',
      'vacation',
      'destination',
      'explore',
      'exploring',
      'sightseeing',
      'backpacking',
    ],
    'culture': ['culture', 'cultures', 'cultural', 'tradition', 'traditions'],
    'technology': ['technology', 'computing', 'computer', 'computers', 'tech'],
    'programming': [
      'programming',
      'coding',
      'software',
      'python',
      'javascript',
    ],
    'science': ['science', 'scientific', 'physics'],
    'history': ['history', 'historical'],
    'romance': ['romance', 'romantic', 'love'],
    'mystery': ['mystery', 'detective', 'crime', 'thriller'],
    'fantasy': ['fantasy', 'magic'],
    'business': ['business', 'management', 'entrepreneurship'],
    'health': ['health', 'wellness'],
  };

  Set<String> _bookWords(String input, {bool removeNoise = false}) {
    const noise = {
      'i',
      'me',
      'my',
      'a',
      'an',
      'the',
      'for',
      'to',
      'of',
      'about',
      'like',
      'with',
      'please',
      'want',
      'need',
      'looking',
      'find',
      'show',
      'give',
      'book',
      'books',
      'read',
      'reading',
      'recommend',
      'suggest',
      'some',
      'any',
      'good',
      'best',
      'can',
      'you',
      'have',
      'do',
      'your',
      'in',
      'on',
      'available',
    };

    final result = <String>{};

    for (final m in RegExp(r'[a-z0-9]+').allMatches(input.toLowerCase())) {
      final word = m.group(0)!;

      if (removeNoise && (noise.contains(word) || word.length < 3)) {
        continue;
      }

      String term = word;

      for (final entry in _topicAliases.entries) {
        if (entry.value.contains(word)) {
          term = entry.key;
          break;
        }
      }

      result.add(term);
    }

    return result;
  }

  Future<Map<String, dynamic>?> _searchRequestedBookTopic(
    String question,
  ) async {
    final lower = question.toLowerCase();

    if (lower.contains('my loan') ||
        lower.contains('my fine') ||
        lower.contains('my reservation') ||
        lower.contains('overdue')) {
      return null;
    }

    if (!RegExp(r'\b(book|books|read|reading|recommend|suggest|novel|title)\b')
        .hasMatch(lower)) {
      return null;
    }

    final terms = _bookWords(question, removeNoise: true);

    if (terms.isEmpty) return null;

    final raw = await ApiService.get('/books');

    if (raw is! List) return null;

    final matches = <Map<String, dynamic>>[];

    for (final item in raw) {
      if (item is! Map) continue;

      final b = Map<String, dynamic>.from(item);

      final title = _bookWords(b['title']?.toString() ?? '');

      final category = _bookWords(b['category']?.toString() ?? '');

      final author = _bookWords(b['author']?.toString() ?? '');

      int score = 0;

      for (final term in terms) {
        if (title.contains(term)) score += 5;
        if (category.contains(term)) score += 7;
        if (author.contains(term)) score += 4;
      }

      if (score < 4) continue;

      b['_rank'] = score;
      matches.add(b);
    }

    matches.sort((a, b) {
      final rank = toInt(b['_rank']).compareTo(toInt(a['_rank']));

      if (rank != 0) return rank;

      return toInt(b['available_copies'])
          .compareTo(toInt(a['available_copies']));
    });

    final cards = matches.take(6).map((b) {
      return <String, dynamic>{
        'type': 'book',
        'title': b['title']?.toString() ?? 'Book',
        'subtitle': b['author']?.toString() ?? '',
        'meta':
            '${b['category'] ?? 'General'} | '
            '${b['available_copies'] ?? 0} available',
      };
    }).toList();

    return {
      'answer': matches.isEmpty
          ? 'No books matching "${terms.join(', ')}" '
                'were found in the library catalogue.'
          : 'Found ${matches.length} relevant book(s) '
                'in the catalogue for "${terms.join(', ')}".',
      'intent': 'book_search',
      'confidence': matches.isEmpty ? 0.0 : 0.95,
      'cards': cards,
      'suggestions': <String>[
        'Find available books',
        'Recommend a book for me',
      ],
    };
  }

  Future<Map<String, dynamic>?> _topicBookSearch(String question) async {
    final q = question.toLowerCase();

    if (!RegExp(r'\b(book|books|reading|read|recommend|suggest|novel|title)\b')
        .hasMatch(q)) {
      return null;
    }

    if (RegExp(
      r'\b(my loans?|my fines?|my reservations?|overdue|borrowed books)\b',
    ).hasMatch(q)) {
      return null;
    }

    const stop = <String>{
      'a',
      'an',
      'and',
      'are',
      'about',
      'any',
      'book',
      'books',
      'by',
      'can',
      'could',
      'do',
      'find',
      'for',
      'give',
      'good',
      'have',
      'i',
      'in',
      'is',
      'like',
      'looking',
      'me',
      'my',
      'need',
      'novel',
      'of',
      'on',
      'please',
      'read',
      'reading',
      'recommend',
      'search',
      'show',
      'some',
      'suggest',
      'the',
      'title',
      'to',
      'want',
      'with',
      'would',
      'you',
      'available',
      'best',
      'get',
      'related',
    };

    const aliases = <String, String>{
      'travelling': 'travel',
      'traveling': 'travel',
      'travels': 'travel',
      'tour': 'travel',
      'tourism': 'travel',
      'trip': 'travel',
      'trips': 'travel',
      'journey': 'travel',
      'journeys': 'travel',
      'holiday': 'travel',
      'vacation': 'travel',
      'backpacking': 'travel',
      'destinations': 'travel',
      'exploring': 'travel',
      'explore': 'travel',
      'cultures': 'culture',
      'cultural': 'culture',
      'computers': 'computer',
      'computing': 'computer',
      'novels': 'novel',
      'romantic': 'romance',
      'historical': 'history',
      'programming': 'program',
      'coding': 'program',
      'thrillers': 'thriller',
    };

    Set<String> words(String text, {bool skipStop = false}) {
      final result = <String>{};

      for (final m in RegExp(r'[a-z0-9]+').allMatches(text.toLowerCase())) {
        final word = m.group(0)!;

        if (skipStop && (stop.contains(word) || word.length < 3)) {
          continue;
        }

        result.add(aliases[word] ?? word);
      }

      return result;
    }

    final targets = words(question, skipStop: true);

    if (targets.isEmpty) return null;

    final raw = await ApiService.get('/books');

    if (raw is! List) return null;

    final ranked = <Map<String, dynamic>>[];

    for (final item in raw) {
      if (item is! Map) continue;

      final book = Map<String, dynamic>.from(item);

      final title = words(book['title']?.toString() ?? '');

      final category = words(book['category']?.toString() ?? '');

      final author = words(book['author']?.toString() ?? '');

      final description = words(book['description']?.toString() ?? '');

      var score = 0;

      for (final term in targets) {
        if (title.contains(term)) score += 7;
        if (category.contains(term)) score += 9;
        if (description.contains(term)) score += 3;
        if (author.contains(term)) score += 4;
      }

      if (score == 0) continue;

      book['_topicRank'] = score;
      ranked.add(book);
    }

    ranked.sort((a, b) {
      final primary = toInt(b['_topicRank']).compareTo(toInt(a['_topicRank']));

      if (primary != 0) return primary;

      return toInt(b['available_copies'])
          .compareTo(toInt(a['available_copies']));
    });

    final cards = ranked.take(6).map((book) {
      return <String, dynamic>{
        'type': 'book',
        'title': book['title']?.toString() ?? 'Book',
        'subtitle': book['author']?.toString() ?? '',
        'meta':
            '${book['category'] ?? 'Uncategorised'} - '
            '${book['available_copies'] ?? 0} available',
      };
    }).toList();

    return <String, dynamic>{
      'answer': ranked.isEmpty
          ? 'No books about ${targets.join(', ')} were found in the current library catalogue.'
          : 'Found ${ranked.length} matching catalogue title(s) for ${targets.join(', ')}.',
      'intent': 'book_search',
      'confidence': ranked.isEmpty ? 0.0 : 1.0,
      'cards': cards,
      'suggestions': <String>[
        'Find available books',
        'Recommend a book for me',
      ],
    };
  }

  Future<Map<String, dynamic>?> _memberLocalAssistant(String text) async {
    if ((ApiService.role ?? '').toLowerCase() != 'member') {
      return null;
    }

    final q = text.toLowerCase().trim();

    final topicAnswer = await _topicBookSearch(text);
    if (topicAnswer != null) return topicAnswer;

    final topic = await _searchRequestedBookTopic(text);
    if (topic != null) return topic;

    if (q.contains('recommend')) {
      final raw = await ApiService.get('/preferences/recommendations?limit=6');

      final data = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};

      final books = List<dynamic>.from(data['recommendations'] ?? const []);

      if (books.isEmpty) {
        return {
          'answer': 'I do not have enough matching books yet. Try selecting more reading interests or browse the catalogue.',
          'cards': <dynamic>[],
          'suggestions': <String>['Find available books', 'Show my loans'],
        };
      }

      final cards = books.take(6).map((rawBook) {
        final book = Map<String, dynamic>.from(rawBook as Map);

        return {
          'type': 'book',
          'title': book['title']?.toString() ?? 'Book',
          'subtitle': book['author']?.toString() ?? '',
          'meta':
              '${book['category'] ?? 'General'} ? ${book['available_copies'] ?? 0} available',
        };
      }).toList();

      return {
        'answer': 'Based on your reading profile and the books currently available, these are good matches for you.',
        'intent': 'member_recommendation',
        'confidence': 1.0,
        'cards': cards,
        'suggestions': <String>[
          'Find available books',
          'Show my loans',
          'Show my fines',
        ],
      };
    }

    if (q.contains('loan')) {
      final raw = await ApiService.get('/loans');
      final rows = List<dynamic>.from(raw ?? const []);

      final active = rows
          .where((x) => x['status']?.toString() == 'Issued')
          .toList();

      final cards = active.take(6).map((rawLoan) {
        final loan = Map<String, dynamic>.from(rawLoan as Map);

        return {
          'type': 'loan',
          'title': loan['book_title']?.toString() ?? 'Loan',
          'subtitle': 'Due ${formatDate(loan['due_date'])}',
          'meta':
              loan['display_status']?.toString() ??
              loan['status']?.toString() ??
              '',
        };
      }).toList();

      return {
        'answer': active.isEmpty
            ? 'You currently have no active loans.'
            : 'You currently have ${active.length} active loan${active.length == 1 ? '' : 's'}.',
        'cards': cards,
        'suggestions': <String>['Recommend a book for me', 'Show my fines'],
      };
    }

    if (q.contains('fine')) {
      final raw = await ApiService.get('/loans');
      final rows = List<dynamic>.from(raw ?? const []);

      double total = 0;

      for (final loan in rows) {
        if (loan['fine_paid'] != true) {
          total += toDouble(loan['calculated_fine'] ?? loan['fine']);
        }
      }

      return {
        'answer': total <= 0
            ? 'You currently have no unpaid fines.'
            : 'Your current unpaid fines total LKR ${formatMoney(total)}.',
        'cards': <dynamic>[],
        'suggestions': <String>['Show my loans', 'Recommend a book for me'],
      };
    }

    if (q.contains('available') ||
        q.contains('find book') ||
        q.contains('find available')) {
      final raw = await ApiService.get(
        '/books?availability=available&sort=popular',
      );

      final books = List<dynamic>.from(raw ?? const []);

      final cards = books.take(6).map((rawBook) {
        final book = Map<String, dynamic>.from(rawBook as Map);

        return {
          'type': 'book',
          'title': book['title']?.toString() ?? 'Book',
          'subtitle': book['author']?.toString() ?? '',
          'meta':
              '${book['category'] ?? 'General'} ? ${book['available_copies'] ?? 0} available',
        };
      }).toList();

      return {
        'answer': books.isEmpty
            ? 'There are no available books right now.'
            : 'I found ${books.length} available titles. Here are a few you can browse.',
        'cards': cards,
        'suggestions': <String>['Recommend a book for me', 'Show my loans'],
      };
    }

    return null;
  }

  Future<Map<String, dynamic>?> _memberLocalAssistantBackup(String text) async {
    if ((ApiService.role ?? '').toLowerCase() != 'member') {
      return null;
    }

    final q = text.toLowerCase().trim();

    if (q.contains('recommend')) {
      final raw = await ApiService.get('/preferences/recommendations?limit=6');

      final data = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};

      final books = List<dynamic>.from(data['recommendations'] ?? const []);

      if (books.isEmpty) {
        return {
          'answer': 'I do not have enough matching books yet. Try selecting more reading interests or browse the catalogue.',
          'cards': <dynamic>[],
          'suggestions': <String>['Find available books', 'Show my loans'],
        };
      }

      final cards = books.take(6).map((rawBook) {
        final book = Map<String, dynamic>.from(rawBook as Map);

        return {
          'type': 'book',
          'title': book['title']?.toString() ?? 'Book',
          'subtitle': book['author']?.toString() ?? '',
          'meta':
              '${book['category'] ?? 'General'} ? ${book['available_copies'] ?? 0} available',
        };
      }).toList();

      return {
        'answer': 'Based on your reading profile and the books currently available, these are good matches for you.',
        'intent': 'member_recommendation',
        'confidence': 1.0,
        'cards': cards,
        'suggestions': <String>[
          'Find available books',
          'Show my loans',
          'Show my fines',
        ],
      };
    }

    if (q.contains('loan')) {
      final raw = await ApiService.get('/loans');
      final rows = List<dynamic>.from(raw ?? const []);

      final active = rows
          .where((x) => x['status']?.toString() == 'Issued')
          .toList();

      final cards = active.take(6).map((rawLoan) {
        final loan = Map<String, dynamic>.from(rawLoan as Map);

        return {
          'type': 'loan',
          'title': loan['book_title']?.toString() ?? 'Loan',
          'subtitle': 'Due ${formatDate(loan['due_date'])}',
          'meta':
              loan['display_status']?.toString() ??
              loan['status']?.toString() ??
              '',
        };
      }).toList();

      return {
        'answer': active.isEmpty
            ? 'You currently have no active loans.'
            : 'You currently have ${active.length} active loan${active.length == 1 ? '' : 's'}.',
        'cards': cards,
        'suggestions': <String>['Recommend a book for me', 'Show my fines'],
      };
    }

    if (q.contains('fine')) {
      final raw = await ApiService.get('/loans');
      final rows = List<dynamic>.from(raw ?? const []);

      double total = 0;

      for (final loan in rows) {
        if (loan['fine_paid'] != true) {
          total += toDouble(loan['calculated_fine'] ?? loan['fine']);
        }
      }

      return {
        'answer': total <= 0
            ? 'You currently have no unpaid fines.'
            : 'Your current unpaid fines total LKR ${formatMoney(total)}.',
        'cards': <dynamic>[],
        'suggestions': <String>['Show my loans', 'Recommend a book for me'],
      };
    }

    if (q.contains('available') ||
        q.contains('find book') ||
        q.contains('find available')) {
      final raw = await ApiService.get(
        '/books?availability=available&sort=popular',
      );

      final books = List<dynamic>.from(raw ?? const []);

      final cards = books.take(6).map((rawBook) {
        final book = Map<String, dynamic>.from(rawBook as Map);

        return {
          'type': 'book',
          'title': book['title']?.toString() ?? 'Book',
          'subtitle': book['author']?.toString() ?? '',
          'meta':
              '${book['category'] ?? 'General'} ? ${book['available_copies'] ?? 0} available',
        };
      }).toList();

      return {
        'answer': books.isEmpty
            ? 'There are no available books right now.'
            : 'I found ${books.length} available titles. Here are a few you can browse.',
        'cards': cards,
        'suggestions': <String>['Recommend a book for me', 'Show my loans'],
      };
    }

    return null;
  }

  Future<void> send([String? preset]) async {
    final text = (preset ?? controller.text).trim();

    if (text.isEmpty || sending) return;

    controller.clear();

    setState(() {
      messages.add({
        'role': 'user',
        'text': text,
        'cards': <dynamic>[],
        'suggestions': <dynamic>[],
      });

      sending = true;
    });

    _scrollToBottom();

    try {
      Map<String, dynamic>? data;

      // Known member actions do not need the external AI service.
      try {
        data = await _memberLocalAssistant(text);
      } catch (_) {
        data = null;
      }

      // For open-ended questions, try the AI backend.
      if (data == null) {
        final raw = await ApiService.post('/ai/chat', {'message': text});

        data = Map<String, dynamic>.from(raw as Map);
      }

      if (!mounted) return;

      setState(() {
        messages.add({
          'role': 'assistant',
          'text':
              data?['answer']?.toString() ?? 'I could not produce a response.',
          'intent': data?['intent']?.toString() ?? '',
          'confidence': toDouble(data?['confidence']),
          'cards': List<dynamic>.from(data?['cards'] ?? const []),
          'suggestions': List<dynamic>.from(data?['suggestions'] ?? const []),
        });
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        messages.add({
          'role': 'assistant',
          'text': 'The advanced AI service is currently unavailable. Library search, loans, fines and personalised recommendations are still available through the quick actions.',
          'cards': <dynamic>[],
          'suggestions': <String>[
            'Recommend a book for me',
            'Show my loans',
            'Find available books',
            'Show my fines',
          ],
          'error': true,
        });
      });
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }

      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 44,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF191B2A), Color(0xFF2E3151)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFD6D2FF),
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Library AI Assistant',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Grounded in your live library data',
                        style: TextStyle(
                          color: Color(0xFFAAB1C7),
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mint.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.circle, color: AppColors.mint, size: 7),
                      SizedBox(width: 5),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: AppColors.mint,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: const Color(0xFFF7F8FC),
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length + (sending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (sending && index == messages.length) {
                    return const _AiTypingBubble();
                  }
                  return _AiChatBubble(
                    message: messages[index],
                    onSuggestion: send,
                  );
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => send(),
                    decoration: const InputDecoration(
                      hintText: 'Ask about books, loans, anomalies...',
                      prefixIcon: Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 19,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: FilledButton(
                    onPressed: sending ? null : () => send(),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: AppColors.primary,
                    ),
                    child: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiChatBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final Future<void> Function(String) onSuggestion;

  const _AiChatBubble({required this.message, required this.onSuggestion});

  Color _kindColor(String kind) {
    switch (kind) {
      case 'warning':
      case 'anomaly':
        return AppColors.amber;
      case 'forecast':
        return AppColors.cyan;
      case 'book':
        return AppColors.primary;
      case 'member':
        return AppColors.pink;
      case 'loan':
        return AppColors.blue;
      case 'reservation':
        return AppColors.violet;
      default:
        return AppColors.mint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = message['role'] == 'user';
    final cards = List<dynamic>.from(message['cards'] ?? const []);
    final suggestions = List<dynamic>.from(message['suggestions'] ?? const []);
    final error = message['error'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: user
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: user ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 390),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: user
                    ? AppColors.primary
                    : error
                    ? const Color(0xFFFFEEEE)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(user ? 16 : 4),
                  bottomRight: Radius.circular(user ? 4 : 16),
                ),
                border: user ? null : Border.all(color: AppColors.line),
                boxShadow: user
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.025),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
              ),
              child: Text(
                message['text']?.toString() ?? '',
                style: TextStyle(
                  color: user
                      ? Colors.white
                      : (error ? AppColors.red : AppColors.text),
                  fontSize: 11.2,
                  height: 1.48,
                  fontWeight: user ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
          if (cards.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...cards.take(6).map((raw) {
              final card = Map<String, dynamic>.from(raw as Map);
              final accent = _kindColor(card['type']?.toString() ?? 'info');
              return Container(
                width: 390,
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.11),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: accent,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card['title']?.toString() ?? '',
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                            ),
                          ),
                          if ((card['subtitle']?.toString() ?? '')
                              .isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              card['subtitle'].toString(),
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 9.2,
                              ),
                            ),
                          ],
                          if ((card['meta']?.toString() ?? '').isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              card['meta'].toString(),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 8.6,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (!user && suggestions.isNotEmpty) ...[
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: suggestions.take(5).map((s) {
                final text = s.toString();
                return ActionChip(
                  onPressed: () => onSuggestion(text),
                  backgroundColor: AppColors.primaryFaint,
                  side: const BorderSide(color: Color(0xFFDFDCFF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                  ),
                  avatar: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  label: Text(
                    text,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 8.7,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _AiTypingBubble extends StatelessWidget {
  const _AiTypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.line),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 9),
            Text(
              'AI is checking library data...',
              style: TextStyle(color: AppColors.muted, fontSize: 9.5),
            ),
          ],
        ),
      ),
    );
  }
}

class AiInsightsPage extends StatefulWidget {
  const AiInsightsPage({super.key});

  @override
  State<AiInsightsPage> createState() => _AiInsightsPageState();
}

class _AiInsightsPageState extends State<AiInsightsPage> {
  bool loading = true;
  Map<String, dynamic> anomalyData = {};
  Map<String, dynamic> forecastData = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final result = await Future.wait([
        ApiService.get('/ai/anomalies?limit=20'),
        ApiService.get('/ai/demand-forecast?months=6&limit=10'),
      ]);
      if (!mounted) return;
      setState(() {
        anomalyData = Map<String, dynamic>.from(result[0] as Map);
        forecastData = Map<String, dynamic>.from(result[1] as Map);
      });
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = [
      'admin',
      'librarian',
    ].contains((ApiService.role ?? '').toLowerCase());
    if (!isStaff) {
      return const Center(
        child: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Staff access only',
          subtitle: 'Anomaly detection compares activity across members and is restricted to library staff.',
        ),
      );
    }

    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final anomalies = List<dynamic>.from(anomalyData['anomalies'] ?? const []);
    final flagged = anomalies
        .where((x) => x is Map && x['anomaly'] == true)
        .toList();
    final forecasts = List<dynamic>.from(forecastData['forecast'] ?? const []);

    return RefreshIndicator(
      onRefresh: load,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(26, 26, 26, 40),
        children: [
          LibrarySceneBanner(
            imagePath: 'assets/images/library_reader.png',
            eyebrow: 'AI / ML Intelligence',
            title: 'Detect unusual activity before it becomes a problem',
            subtitle: 'Anomaly detection, demand forecasting and explainable member risk signals from your live library data.',
            icon: Icons.psychology_alt_rounded,
            height: 190,
            actionLabel: 'Run AI Scan',
            actionIcon: Icons.radar_rounded,
            onAction: load,
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _AiMetricTile(
                label: 'Members scanned',
                value: '${anomalyData['scanned_members'] ?? anomalies.length}',
                icon: Icons.groups_2_outlined,
                accent: AppColors.blue,
              ),
              _AiMetricTile(
                label: 'Flagged patterns',
                value: '${anomalyData['detected_count'] ?? flagged.length}',
                icon: Icons.warning_amber_rounded,
                accent: flagged.isEmpty ? AppColors.mint : AppColors.amber,
              ),
              _AiMetricTile(
                label: 'Forecast titles',
                value: '${forecasts.length}',
                icon: Icons.trending_up_rounded,
                accent: AppColors.cyan,
              ),
            ],
          ),
          const SizedBox(height: 26),
          SectionHeader(
            title: 'Anomaly detection',
            subtitle: flagged.isEmpty
                ? 'No strong anomaly is currently flagged; top member signals are still shown for review.'
                : '${flagged.length} unusual member pattern(s) need attention',
            action: IconButton(
              onPressed: load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(height: 14),
          if (anomalies.isEmpty)
            const EmptyState(
              icon: Icons.radar_rounded,
              title: 'No anomaly data',
              subtitle: 'Add member borrowing history and run the scan again.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 900;
                final cardWidth = twoColumns
                    ? (constraints.maxWidth - 14) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: anomalies.take(12).map((raw) {
                    return SizedBox(
                      width: cardWidth,
                      child: _AiAnomalyCard(
                        data: Map<String, dynamic>.from(raw as Map),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          const SizedBox(height: 28),
          const SectionHeader(
            title: 'Demand forecast',
            subtitle: 'Linear-regression signals estimate which titles may see higher borrowing next month',
          ),
          const SizedBox(height: 14),
          if (forecasts.isEmpty)
            const EmptyState(
              icon: Icons.insights_rounded,
              title: 'Not enough history yet',
              subtitle: 'Borrowing history is required before useful demand forecasts can be produced.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 900;
                final cardWidth = twoColumns
                    ? (constraints.maxWidth - 14) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: forecasts.take(10).map((raw) {
                    return SizedBox(
                      width: cardWidth,
                      child: _AiForecastCard(
                        data: Map<String, dynamic>.from(raw as Map),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _AiMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _AiMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.11),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 9.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiAnomalyCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AiAnomalyCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final anomaly = data['anomaly'] == true;
    final severity =
        data['severity']?.toString() ?? (anomaly ? 'Medium' : 'Normal');
    final features = data['features'] is Map
        ? Map<String, dynamic>.from(data['features'])
        : <String, dynamic>{};
    Color accent;
    switch (severity.toLowerCase()) {
      case 'high':
        accent = AppColors.red;
        break;
      case 'medium':
      case 'watch':
        accent = AppColors.amber;
        break;
      default:
        accent = AppColors.mint;
    }

    return HoverCard(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.11),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    anomaly
                        ? Icons.warning_amber_rounded
                        : Icons.verified_outlined,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data['member_code'] ?? ''}  -  ${data['name'] ?? ''}',
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Anomaly score ${toDouble(data['anomaly_score']).toStringAsFixed(3)}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 9.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.11),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    severity,
                    style: TextStyle(
                      color: accent,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              data['reason']?.toString() ?? 'Member activity signal',
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 10.2,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _AiFeatureChip(label: '${features['total_loans'] ?? 0} loans'),
                _AiFeatureChip(label: '${features['late_loans'] ?? 0} late'),
                _AiFeatureChip(
                  label: 'LKR ${formatMoney(features['unpaid_fines'])} unpaid',
                ),
                _AiFeatureChip(
                  label: '${features['reservations'] ?? 0} reservations',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AiForecastCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AiForecastCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final level = data['demand_level']?.toString() ?? 'Low';
    final accent = level == 'High'
        ? AppColors.red
        : level == 'Medium'
        ? AppColors.amber
        : AppColors.mint;
    return HoverCard(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.11),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.trending_up_rounded, color: accent, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title']?.toString() ?? '',
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data['author'] ?? ''}  -  ${data['category'] ?? ''}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 9.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Next month approximately  ${data['predicted_next_month'] ?? 0} borrows  -  trend ${data['trend_slope'] ?? 0}',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 9.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.11),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                level,
                style: TextStyle(
                  color: accent,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiFeatureChip extends StatelessWidget {
  final String label;
  const _AiFeatureChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ============================================================
// MEMBER DASHBOARD
// ============================================================

class MemberDashboardPage extends StatefulWidget {
  const MemberDashboardPage({super.key});

  @override
  State<MemberDashboardPage> createState() => _MemberDashboardPageState();
}

class _MemberDashboardPageState extends State<MemberDashboardPage> {
  // LMS_DUE_PREVIEW_V1
  static const bool _enableDuePreview = bool.fromEnvironment(
    'LMS_DUE_PREVIEW',
    defaultValue: false,
  );

  int _testDaysAhead = 0;

  bool loading = true;
  List<dynamic> loans = [];
  List<dynamic> reservations = [];
  List<dynamic> notifications = [];
  List<dynamic> recommendations = [];
  String recommendationMethod = '';

  @override
  void initState() {
    super.initState();

    load();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showFirstLoginReadingQuiz();
      }
    });
  }

  Future<void> _showFirstLoginReadingQuiz() async {
    if ((ApiService.role ?? '').toLowerCase() != 'member') {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    final memberKey =
        ApiService.memberId?.toString() ?? ApiService.email ?? 'member';

    final quizKey = 'reading_quiz_v20261101_fixed_done_$memberKey';
    // LMS_QUIZ_ONCE_V2
    final stableQuizKey = 'reading_profile_once_$memberKey';

    if (prefs.getBool(stableQuizKey) == true) return;

    final previousQuiz = prefs.getKeys().any(
      (key) =>
          key.startsWith('reading_quiz_') &&
          key.endsWith('_$memberKey') &&
          prefs.getBool(key) == true,
    );

    if (previousQuiz || prefs.getBool(quizKey) == true) {
      await prefs.setBool(stableQuizKey, true);
      return;
    }

    try {
      final saved = await ApiService.get('/preferences/me');

      if (saved is Map &&
          (saved['onboardingCompleted'] == true ||
              saved['onboarding_completed'] == true)) {
        await prefs.setBool(stableQuizKey, true);
        return;
      }
    } catch (_) {}

    await prefs.setBool(stableQuizKey, true);

    if (prefs.getBool(quizKey) == true) {
      return;
    }

    // QUIZ_SEEN_ON_FIRST_OPEN
    // Mark it as seen before opening the dialog.
    // Therefore changing pages will not show it again.
    await prefs.setBool(quizKey, true);

    if (!mounted) return;

    final selectedInterests = <String>{};

    String level = 'Any';
    String purpose = 'Explore new topics';
    String readingType = 'Mixed';

    String? errorText;

    final interests = <Map<String, dynamic>>[
      {'label': 'Technology & Computing', 'icon': Icons.computer_rounded},
      {'label': 'Science & Engineering', 'icon': Icons.science_outlined},
      {
        'label': 'Business & Management',
        'icon': Icons.business_center_outlined,
      },
      {'label': 'History & Politics', 'icon': Icons.account_balance_outlined},
      {'label': 'Biography & Memoir', 'icon': Icons.person_outline_rounded},
      {'label': 'Self-development', 'icon': Icons.trending_up_rounded},
      {'label': 'Health & Lifestyle', 'icon': Icons.favorite_outline_rounded},
      {'label': 'Fiction / Novels', 'icon': Icons.auto_stories_outlined},
      {'label': 'Mystery & Thriller', 'icon': Icons.search_rounded},
      {'label': 'Romance', 'icon': Icons.favorite_border_rounded},
      {
        'label': 'Science Fiction & Fantasy',
        'icon': Icons.rocket_launch_outlined,
      },
      {'label': 'Children & Young Adult', 'icon': Icons.child_care_rounded},
      {'label': 'Travel & Culture', 'icon': Icons.public_rounded},
      {'label': 'General / Other', 'icon': Icons.category_outlined},
    ];

    final save = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            Widget sectionCard({
              required String number,
              required IconData icon,
              required String title,
              required String subtitle,
              required List<String> options,
              required String selectedValue,
              required ValueChanged<String> onChanged,
            }) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF8F6FF), Colors.white],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E0F7)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D111827),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAE5FF),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(icon, color: AppColors.primary, size: 21),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$number. $title',
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 10.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: options.map((value) {
                        final selected = selectedValue == value;

                        return ChoiceChip(
                          selected: selected,
                          showCheckmark: selected,
                          checkmarkColor: AppColors.primary,
                          selectedColor: const Color(0xFFE7E1FF),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: selected
                                ? AppColors.primary
                                : const Color(0xFFDADCE7),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          label: Text(value),
                          labelStyle: TextStyle(
                            color: selected
                                ? AppColors.primary
                                : AppColors.text,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          onSelected: (_) {
                            onChanged(value);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 960,
                  maxHeight: 900,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x330B1020),
                        blurRadius: 44,
                        offset: Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // HEADER
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(28, 23, 28, 23),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF6753E8), Color(0xFF8874F5)],
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(28),
                            topRight: Radius.circular(28),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0x2AFFFFFF),
                                borderRadius: BorderRadius.circular(17),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                                size: 29,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Build your reading profile',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'A few choices now will help BookNest recommend books that actually match your interests.',
                                    style: TextStyle(
                                      color: Color(0xFFEDEAFF),
                                      fontSize: 11.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(28, 22, 28, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // INTERESTS CARD
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(19),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7F0),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x0D111827),
                                      blurRadius: 16,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEDE9FF),
                                            borderRadius: BorderRadius.circular(
                                              13,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.interests_outlined,
                                            color: AppColors.primary,
                                            size: 21,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '1. What do you enjoy reading?',
                                                style: TextStyle(
                                                  color: AppColors.ink,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              SizedBox(height: 3),
                                              Text(
                                                'Choose all the categories that interest you.',
                                                style: TextStyle(
                                                  color: AppColors.muted,
                                                  fontSize: 10.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: selectedInterests.isEmpty
                                                ? const Color(0xFFF2F3F7)
                                                : AppColors.primarySoft,
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                          child: Text(
                                            '${selectedInterests.length} selected',
                                            style: TextStyle(
                                              color: selectedInterests.isEmpty
                                                  ? AppColors.muted
                                                  : AppColors.primary,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 15),

                                    Wrap(
                                      spacing: 9,
                                      runSpacing: 9,
                                      children: interests.map((item) {
                                        final label = item['label'].toString();

                                        final icon = item['icon'] as IconData;

                                        final selected = selectedInterests
                                            .contains(label);

                                        return FilterChip(
                                          selected: selected,
                                          showCheckmark: false,
                                          avatar: Icon(
                                            icon,
                                            size: 17,
                                            color: selected
                                                ? AppColors.primary
                                                : AppColors.text,
                                          ),
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(label),
                                              if (selected) ...[
                                                const SizedBox(width: 5),
                                                const Icon(
                                                  Icons.check_circle_rounded,
                                                  color: AppColors.primary,
                                                  size: 15,
                                                ),
                                              ],
                                            ],
                                          ),
                                          selectedColor: const Color(
                                            0xFFEAE5FF,
                                          ),
                                          backgroundColor: const Color(
                                            0xFFF9F9FC,
                                          ),
                                          side: BorderSide(
                                            color: selected
                                                ? AppColors.primary
                                                : const Color(0xFFDDE0EA),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          labelStyle: TextStyle(
                                            color: selected
                                                ? AppColors.primary
                                                : AppColors.text,
                                            fontWeight: selected
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 9,
                                          ),
                                          onSelected: (value) {
                                            setLocal(() {
                                              errorText = null;

                                              if (value) {
                                                selectedInterests.add(label);
                                              } else {
                                                selectedInterests.remove(label);
                                              }
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 15),

                              // SMART INFO
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFF2EEFF),
                                      Color(0xFFFCFBFF),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFE5DEFF),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Color(0xFFE4DEFF),
                                      child: Icon(
                                        Icons.psychology_alt_outlined,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Make your recommendations smarter',
                                            style: TextStyle(
                                              color: AppColors.ink,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          SizedBox(height: 3),
                                          Text(
                                            'These preferences work together with your future borrowing history to improve recommendations.',
                                            style: TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 10.5,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 15),

                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final wide = constraints.maxWidth > 730;

                                  final levelCard = sectionCard(
                                    number: '2',
                                    icon: Icons.tune_rounded,
                                    title: 'Preferred reading level',
                                    subtitle: 'How challenging should your recommendations be?',
                                    options: const [
                                      'Easy',
                                      'Intermediate',
                                      'Advanced',
                                      'Any',
                                    ],
                                    selectedValue: level,
                                    onChanged: (value) {
                                      setLocal(() {
                                        level = value;
                                      });
                                    },
                                  );

                                  final typeCard = sectionCard(
                                    number: '4',
                                    icon: Icons.style_outlined,
                                    title: 'Reading style',
                                    subtitle: 'What type of reading feels most enjoyable to you?',
                                    options: const [
                                      'Academic & detailed',
                                      'Practical & concise',
                                      'Novels & stories',
                                      'Mixed',
                                    ],
                                    selectedValue: readingType,
                                    onChanged: (value) {
                                      setLocal(() {
                                        readingType = value;
                                      });
                                    },
                                  );

                                  final purposeCard = sectionCard(
                                    number: '3',
                                    icon: Icons.flag_outlined,
                                    title: 'Why do you mainly read?',
                                    subtitle: 'We will prioritise books that support your main reason for reading.',
                                    options: const [
                                      'Study & research',
                                      'Learn practical skills',
                                      'Career & professional growth',
                                      'Entertainment & relaxation',
                                      'Personal growth',
                                      'Explore new topics',
                                    ],
                                    selectedValue: purpose,
                                    onChanged: (value) {
                                      setLocal(() {
                                        purpose = value;
                                      });
                                    },
                                  );

                                  if (!wide) {
                                    return Column(
                                      children: [
                                        levelCard,
                                        const SizedBox(height: 14),
                                        purposeCard,
                                        const SizedBox(height: 14),
                                        typeCard,
                                      ],
                                    );
                                  }

                                  return Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: levelCard),
                                          const SizedBox(width: 14),
                                          Expanded(child: typeCard),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      purposeCard,
                                    ],
                                  );
                                },
                              ),

                              if (errorText != null) ...[
                                const SizedBox(height: 15),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF1F2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline_rounded,
                                        color: AppColors.red,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          errorText!,
                                          style: const TextStyle(
                                            color: AppColors.red,
                                            fontWeight: FontWeight.w700,
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

                      // FOOTER
                      Container(
                        padding: const EdgeInsets.fromLTRB(28, 14, 28, 18),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFBFBFE),
                          border: Border(
                            top: BorderSide(color: Color(0xFFECECF2)),
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(28),
                            bottomRight: Radius.circular(28),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lock_outline_rounded,
                              size: 15,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 7),
                            const Expanded(
                              child: Text(
                                'Your preferences are used only to personalise your library experience.',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 9.5,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(dialogContext, false);
                              },
                              child: const Text('Later'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF171928),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 17,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                if (selectedInterests.isEmpty) {
                                  setLocal(() {
                                    errorText =
                                        'Choose at least one reading interest.';
                                  });
                                  return;
                                }

                                Navigator.pop(dialogContext, true);
                              },
                              icon: const Icon(
                                Icons.auto_awesome_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Save reading profile',
                                style: TextStyle(fontWeight: FontWeight.w800),
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
          },
        );
      },
    );

    if (save != true) {
      return;
    }

    try {
      await ApiService.put('/preferences/me', {
        'categories': selectedInterests.toList(),
        'readingLevel': level,
        'readingGoal': purpose,
        'readingStyle': readingType,
        'onboardingCompleted': true,
      });

      await prefs.setBool(quizKey, true);

      if (!mounted) return;

      showAppMessage(context, 'Your reading profile is ready');

      await load();
    } catch (e) {
      if (!mounted) return;

      showAppMessage(
        context,
        'Could not save reading profile: ${cleanError(e)}',
      );
    }
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final core = await Future.wait([
        ApiService.get('/loans'),
        ApiService.get('/reservations'),
        ApiService.get('/notifications'),
      ]);

      if (!mounted) return;
      setState(() {
        loans = List<dynamic>.from(core[0] ?? []);
        reservations = List<dynamic>.from(core[1] ?? []);
        notifications = List<dynamic>.from(core[2] ?? []);
      });

      if (ApiService.memberId != null) {
        try {
          final ai = await ApiService.get(
            '/preferences/recommendations?limit=4',
          );
          if (mounted) {
            setState(() {
              recommendations = List<dynamic>.from(ai['recommendations'] ?? []);
              recommendationMethod = ai['method']?.toString() ?? '';
            });
          }
        } catch (_) {
          try {
            final pref = await ApiService.get(
              '/preferences/recommendations?limit=4',
            );

            if (mounted) {
              setState(() {
                recommendations = List<dynamic>.from(
                  pref['recommendations'] ?? [],
                );

                recommendationMethod = 'preference_profile';
              });
            }
          } catch (_) {
            // Dashboard remains usable.
          }
        }
      }
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _duePreviewToolbar() {
    const previews = <int, String>{
      0: 'Today',
      12: '+12d: Reminder',
      14: '+14d: Due today',
      15: '+15d: Overdue',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryFaint,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Due-date preview - test mode',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: previews.entries.map((entry) {
              return ChoiceChip(
                label: Text(entry.value),
                selected: _testDaysAhead == entry.key,
                onSelected: (_) => setState(() {
                  _testDaysAhead = entry.key;
                }),
              );
            }).toList(),
          ),
          if (_testDaysAhead != 0) ...[
            const SizedBox(height: 8),
            const Text(
              'PREVIEW ONLY: Clock and database are unchanged. No real notification is sent.',
              style: TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _memberDueCard(Map<String, dynamic> loan) {
    final raw = loan['due_date']?.toString() ?? '';
    final dateOnly = raw.split('T').first.split(' ').first;
    final parsed = DateTime.tryParse(dateOnly);
    final days = parsed == null ? null : correctLoanDays(loan) - _testDaysAhead;

    final overdue = days != null && days < 0;
    final urgent = days != null && days <= 2;

    final tone = overdue
        ? AppColors.red
        : urgent
        ? AppColors.amber
        : AppColors.mint;

    final countdown = days == null
        ? 'Date unavailable'
        : days < 0
        ? '${-days} day${days == -1 ? '' : 's'} overdue'
        : days == 0
        ? 'Due today'
        : '$days day${days == 1 ? '' : 's'} remaining';

    final message = overdue
        ? 'Overdue: Please return this book as soon as possible.'
        : days == 0
        ? 'Due today: Please return this book today.'
        : 'Due soon: Please return this book within $days day${days == 1 ? '' : 's'}.';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HoverCard(
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 47,
                    height: 47,
                    decoration: BoxDecoration(
                      color: tone.withOpacity(.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      overdue
                          ? Icons.warning_amber_rounded
                          : Icons.menu_book_rounded,
                      color: tone,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      loan['book_title']?.toString() ?? 'Book',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: overdue ? 'Overdue' : 'Issued'),
                ],
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.canvas,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RETURN BY',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              formatDate(loan['due_date']),
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: tone.withOpacity(.12),
                      border: Border.all(color: tone.withOpacity(.35)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      countdown,
                      style: TextStyle(
                        color: overdue ? AppColors.red : AppColors.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              if (urgent) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tone.withOpacity(.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tone.withOpacity(.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        color: tone,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _testDaysAhead == 0
                              ? message
                              : 'TEST PREVIEW - $message',
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
    );
  }

  String dueLabel(dynamic loan) {
    final status =
        loan['display_status']?.toString() ?? loan['status']?.toString() ?? '';
    if (status == 'Returned')
      return 'Returned ${formatDate(loan['return_date'])}';
    final days = correctLoanDays(loan);
    if (days < 0) return '${-days} day${-days == 1 ? '' : 's'} overdue';
    if (days == 0) return 'Due today';
    return '$days day${days == 1 ? '' : 's'} left';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final activeLoans = loans.where((l) => l['status'] == 'Issued').toList();
    final overdue = loans.where((l) => l['display_status'] == 'Overdue').length;
    final activeReservations = reservations
        .where((r) => ['Pending', 'Ready'].contains(r['status']?.toString()))
        .toList();
    final unread = notifications.where((n) => n['is_read'] != true).length;

    return RefreshIndicator(
      onRefresh: load,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          LibrarySceneBanner(
            imagePath: 'assets/images/library_reader.png',
            eyebrow: 'My library workspace',
            title: 'Welcome back, ${ApiService.userName ?? 'Member'}',
            subtitle: 'Your borrowing, reservations and personalised reading suggestions in one place.',
            icon: Icons.local_library_outlined,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 980
                  ? 4
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;
              const gap = 12.0;
              final tileWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: PageStatTile(
                      label: 'Current loans',
                      value: '${activeLoans.length}',
                      note: 'Books you currently hold',
                      icon: Icons.menu_book_outlined,
                      accent: AppColors.blue,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: PageStatTile(
                      label: 'Overdue',
                      value: '$overdue',
                      note: overdue == 0
                          ? 'Everything is on schedule'
                          : 'Needs your attention',
                      icon: Icons.warning_amber_rounded,
                      accent: overdue == 0 ? AppColors.mint : AppColors.red,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: PageStatTile(
                      label: 'Reservations',
                      value: '${activeReservations.length}',
                      note: 'Pending or ready for pickup',
                      icon: Icons.bookmark_outline_rounded,
                      accent: AppColors.primary,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: PageStatTile(
                      label: 'Notifications',
                      value: '$unread',
                      note: 'Unread library updates',
                      icon: Icons.notifications_none_rounded,
                      accent: AppColors.amber,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Current borrowing',
            subtitle: 'Your active loans and approaching due dates',
          ),
          const SizedBox(height: 12),
          if (activeLoans.isNotEmpty && _enableDuePreview) ...[
            _duePreviewToolbar(),
            const SizedBox(height: 12),
          ],
          if (activeLoans.isEmpty)
            const EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No active loans',
              subtitle:
                  'Browse the catalogue when you are ready for your next book.',
            )
          else
            ...activeLoans
                .take(4)
                .map(
                  (loan) =>
                      _memberDueCard(Map<String, dynamic>.from(loan as Map)),
                ),
          const SizedBox(height: 22),
          const SectionHeader(
            title: 'AI reading suggestions',
            subtitle: 'Personalised suggestions generated from your borrowing activity',
          ),
          const SizedBox(height: 12),
          if (recommendations.isEmpty)
            HoverCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Recommendations will appear as your borrowing history grows. You can also ask the AI assistant for suggestions.',
                        style: TextStyle(color: AppColors.text, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 2 : 1;
                const gap = 12.0;
                final cardWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: recommendations.map((book) {
                    return SizedBox(
                      width: cardWidth,
                      child: HoverCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.auto_stories_rounded,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      book['title']?.toString() ??
                                          'Recommended book',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      book['author']?.toString() ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.text,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      book['reason']?.toString() ??
                                          recommendationMethod,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 9.5,
                                        height: 1.35,
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
                  }).toList(),
                );
              },
            ),
          const SizedBox(height: 22),
          const SectionHeader(
            title: 'Recent notifications',
            subtitle:
                'Pickup, reservation and account messages from the library',
          ),
          const SizedBox(height: 12),
          if (notifications.isEmpty)
            const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications',
              subtitle: 'Important library updates will appear here.',
            )
          else
            ...notifications
                .take(5)
                .map(
                  (n) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: HoverCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              n['is_read'] == true
                                  ? Icons.notifications_none_rounded
                                  : Icons.notifications_active_outlined,
                              color: n['is_read'] == true
                                  ? AppColors.muted
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n['title']?.toString() ?? 'Library update',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    n['message']?.toString() ?? '',
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 10.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(
                              status: n['is_read'] == true ? 'Read' : 'New',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ============================================================
// MEMBER AI RECOMMENDATIONS
// ============================================================

class MemberRecommendationsPage extends StatefulWidget {
  const MemberRecommendationsPage({super.key});

  @override
  State<MemberRecommendationsPage> createState() =>
      _MemberRecommendationsPageState();
}

class _MemberRecommendationsPageState extends State<MemberRecommendationsPage> {
  Future<void> _loadRatedBooksQuick() async {
    try {
      final raw = await ApiService.get('/reviews');

      final List<dynamic> reviews = raw is List
          ? raw
          : raw is Map && raw['reviews'] is List
          ? List<dynamic>.from(raw['reviews'])
          : <dynamic>[];

      final ratings = <int, List<double>>{};

      for (final r in reviews) {
        if (r is! Map) continue;

        final id = toInt(r['book_id'] ?? r['bookId']);
        final score = toDouble(r['rating'] ?? r['stars']);

        if (id > 0 && score >= 1 && score <= 5) {
          ratings.putIfAbsent(id, () => []).add(score);
        }
      }

      final catalog = await ApiService.get('/books');
      if (catalog is! List) return;

      final rated = <Map<String, dynamic>>[];

      for (final record in catalog) {
        if (record is! Map) continue;

        final book = Map<String, dynamic>.from(record);
        final id = toInt(book['id']);
        final list = ratings[id] ?? <double>[];

        final count = list.isNotEmpty
            ? list.length
            : toInt(book['review_count'] ?? book['rating_count']);

        final score = list.isNotEmpty
            ? list.reduce((a, b) => a + b) / list.length
            : toDouble(book['average_rating'] ?? book['avg_rating']);

        if (count > 0 && score >= 4 && toInt(book['available_copies']) > 0) {
          book['_ratedScoreQuick'] = score;
          rated.add(book);
        }
      }

      rated.sort(
        (a, b) =>
            toDouble(b['_ratedScoreQuick'])
                .compareTo(toDouble(a['_ratedScoreQuick'])),
      );

      if (!mounted || rated.isEmpty) return;

      final known = highlyRecommended.map((e) => toInt(e['id'])).toSet();

      setState(() {
        highlyRecommended = [
          ...highlyRecommended,
          ...rated.where((b) => !known.contains(toInt(b['id']))),
        ].take(6).toList();
      });
      await _loadRatedBooksQuick();
    } catch (_) {
      // Preserve original recommendations if API unavailable.
    }
  }

  bool loading = true;
  String method = '';
  int historyCount = 0;
  List<dynamic> personalised = [];
  List<dynamic> popularNow = [];
  List<dynamic> highlyRecommended = [];
  List<dynamic> becauseYouBorrowed = [];
  List<dynamic> similarReaders = [];
  List<String> tasteCategories = [];
  List<String> tasteAuthors = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> _editReadingInterests() async {
    try {
      final raw = await ApiService.get('/preferences/me');
      final profile = Map<String, dynamic>.from(raw);
      final selected = <String>{
        ...List<dynamic>.from(profile['categories'] ?? [])
            .map((e) => e.toString()),
      };

      const options = <String>[
        'Technology & Computing',
        'Science & Engineering',
        'Business & Management',
        'History & Politics',
        'Biography & Memoir',
        'Self-development',
        'Health & Lifestyle',
        'Fiction / Novels',
        'Mystery & Thriller',
        'Romance',
        'Science Fiction & Fantasy',
        'Children & Young Adult',
        'Travel & Culture',
        'General / Other',
      ];

      if (!mounted) return;

      final chosen = await showDialog<List<String>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Choose your reading interests'),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options
                      .map(
                        (option) => FilterChip(
                          label: Text(option),
                          selected: selected.contains(option),
                          onSelected: (value) => update(() {
                            if (value) {
                              selected.add(option);
                            } else {
                              selected.remove(option);
                            }
                          }),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, selected.toList()),
                child: const Text('Save interests'),
              ),
            ],
          ),
        ),
      );

      if (chosen == null) return;

      await ApiService.put('/preferences/me', {
        'categories': chosen,
        'readingLevel': profile['readingLevel'] ?? 'Any',
        'readingGoal': profile['readingGoal'] ?? 'Explore new topics',
        'readingStyle': profile['readingStyle'] ?? 'Mixed',
        'onboardingCompleted': true,
      });

      await load();

      if (mounted) {
        showAppMessage(context, 'Reading interests updated');
      }
    } catch (error) {
      if (mounted) {
        showAppMessage(context, cleanError(error));
      }
    }
  }

  String recommendationError = '';

  String _clean(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  bool _fits(Map<String, dynamic> b, String interest) {
    final category = _clean('${b['category'] ?? ''}');
    final wanted = _clean(interest);

    if (category.isEmpty || wanted.isEmpty) return false;
    if (category == wanted) return true;

    const alias = {
      'health lifestyle': [
        'health',
        'wellness',
        'lifestyle',
        'nutrition',
        'fitness',
      ],
      'travel culture': ['travel', 'tourism', 'culture'],
      'technology computing': [
        'technology',
        'computing',
        'programming',
        'database',
        'networking',
      ],
      'science engineering': [
        'science',
        'engineering',
        'electronics',
        'mathematics',
      ],
      'fiction novels': ['fiction', 'novels'],
      'self development': ['self help', 'personal development'],
      'mystery thriller': ['mystery', 'thriller'],
      'science fiction fantasy': ['science fiction', 'fantasy'],
    };

    return alias[wanted]?.contains(category) ?? false;
  }

  int _activity(Map<String, dynamic> b) =>
      2 * toInt(b['borrow_count']) + 3 * toInt(b['reservation_count']);

  Future<void> load() async {
    if (ApiService.memberId == null) {
      if (mounted) setState(() => loading = false);
      return;
    }

    setState(() {
      loading = true;
      recommendationError = '';
    });

    try {
      final pref = Map<String, dynamic>.from(
        await ApiService.get('/preferences/me'),
      );

      final raw = await ApiService.get('/books');

      final all = List<dynamic>.from(raw ?? [])
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();

      final chosen = List<dynamic>.from(pref['categories'] ?? [])
          .map((x) => x.toString())
          .toList();

      final books = all.where((b) => toInt(b['available_copies']) > 0).toList();

      List<dynamic> loans = [];

      try {
        loans = List<dynamic>.from(await ApiService.get('/loans'));
      } catch (_) {}

      final borrowed = loans.map((x) => toInt(x['book_id'])).toSet();

      final categories = all
          .where((b) => borrowed.contains(toInt(b['id'])))
          .map((b) => _clean('${b['category'] ?? ''}'))
          .toSet();

      final seen = <int>{...borrowed};

      List<dynamic> take3(
        List<Map<String, dynamic>> items,
        String Function(Map<String, dynamic>) why,
      ) {
        final out = <dynamic>[];

        for (final book in items) {
          if (!seen.add(toInt(book['id']))) continue;

          out.add({...book, 'reason': why(book)});

          if (out.length == 3) break;
        }

        return out;
      }

      List<Map<String, dynamic>> sortActivity(
        Iterable<Map<String, dynamic>> items,
      ) => items.toList()..sort((x, y) => _activity(y).compareTo(_activity(x)));

      final personal = take3(
        sortActivity(books.where((b) => chosen.any((c) => _fits(b, c)))),
        (b) => 'Saved reading interest: ${b['category']}.',
      );

      final because = take3(
        sortActivity(
          books.where(
            (b) => categories.contains(_clean('${b['category'] ?? ''}')),
          ),
        ),
        (b) =>
            'Same category as a book in your real loan history: ${b['category']}.',
      );

      final popular = take3(
        sortActivity(books.where((b) => _activity(b) > 0)),
        (b) =>
            '${toInt(b['borrow_count'])} loans; '
            '${toInt(b['reservation_count'])} active reservations.',
      );

      final highly = take3(
        sortActivity(
          books.where(
            (b) =>
                toInt(b['borrow_count']) >= 2 ||
                toInt(b['reservation_count']) >= 2,
          ),
        ),
        (b) =>
            'Evidence: ${toInt(b['borrow_count'])} loans '
            'and ${toInt(b['reservation_count'])} active reservations.',
      );

      if (!mounted) return;

      setState(() {
        method = 'saved_interests';
        historyCount = borrowed.length;
        tasteCategories = chosen;
        tasteAuthors = [];

        personalised = personal;
        becauseYouBorrowed = because;
        popularNow = popular;
        highlyRecommended = highly;
        similarReaders = [];
      });

      if (borrowed.isNotEmpty) {
        _loadVerifiedSimilar(seen);
      }
    } catch (e) {
      if (mounted) {
        setState(() => recommendationError = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _loadVerifiedSimilar(Set<int> used) async {
    try {
      final raw = await ApiService.get(
        '/ai/recommendations/member/'
        '${ApiService.memberId}/expanded?limit=12',
      );

      final found = <dynamic>[];
      final seen = <int>{...used};

      for (final x in List<dynamic>.from(raw['similar_readers'] ?? [])) {
        final b = Map<String, dynamic>.from(x as Map);

        if (toInt(b['similar_reader_count']) < 1 ||
            toInt(b['available_copies']) < 1 ||
            !seen.add(toInt(b['id']))) {
          continue;
        }

        found.add({
          ...b,
          'reason':
              '${toInt(b['similar_reader_count'])} verified readers with overlapping loans.',
        });

        if (found.length == 3) break;
      }

      if (mounted) {
        setState(() => similarReaders = found);
      }
    } catch (_) {
      // Do not invent recommendations when AI is offline.
    }
  }

  Future<void> _editInterests() async {
    const all = <String>[
      'Technology & Computing',
      'Science & Engineering',
      'Business & Management',
      'History & Politics',
      'Biography & Memoir',
      'Self-development',
      'Health & Lifestyle',
      'Fiction / Novels',
      'Mystery & Thriller',
      'Romance',
      'Science Fiction & Fantasy',
      'Children & Young Adult',
      'Travel & Culture',
      'General / Other',
    ];

    try {
      final pref = Map<String, dynamic>.from(
        await ApiService.get('/preferences/me'),
      );

      final chosen = List<dynamic>.from(pref['categories'] ?? [])
          .map((x) => x.toString())
          .toSet();

      if (!mounted) return;

      final updated = await showDialog<List<String>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, refresh) => AlertDialog(
            title: const Text('Edit reading interests'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: all
                      .map(
                        (name) => FilterChip(
                          label: Text(name),
                          selected: chosen.contains(name),
                          onSelected: (yes) => refresh(() {
                            if (yes) {
                              chosen.add(name);
                            } else {
                              chosen.remove(name);
                            }
                          }),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, chosen.toList()),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );

      if (updated == null) return;

      await ApiService.put('/preferences/me', {
        'categories': updated,
        'readingLevel': pref['readingLevel'] ?? 'Any',
        'readingGoal': pref['readingGoal'] ?? 'Explore new topics',
        'readingStyle': pref['readingStyle'] ?? 'Mixed',
        'onboardingCompleted': true,
      });

      if (mounted) await load();
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  Future<void> reserveBook(Map<String, dynamic> book) async {
    if (toInt(book['available_copies']) <= 0) {
      showAppMessage(context, 'This title is currently unavailable');
      return;
    }
    try {
      await ApiService.post('/reservations', {
        'bookId': toInt(book['id']),
        'memberId': ApiService.memberId,
      });
      if (!mounted) return;
      showAppMessage(context, 'Reservation created for ${book['title']}');
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  String methodLabel() {
    switch (method) {
      case 'tfidf_content_based':
      case 'content_based':
        return 'Personalised taste matching';
      case 'popular_fallback':
        return 'Popular-books starter profile';
      case 'no_unseen_books':
        return 'Catalogue fully explored';
      default:
        return method.isEmpty
            ? 'AI recommendation engine'
            : method.replaceAll('_', ' ');
    }
  }

  Widget _recommendationCard(
    Map<String, dynamic> book, {
    required Color accent,
    String? badge,
    String? reason,
  }) {
    final available = toInt(book['available_copies']);
    final category = book['category']?.toString() ?? '';
    final reasonText =
        reason ??
        book['reason']?.toString() ??
        'Selected by the recommendation engine';

    return HoverCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BookCoverArt(book: book, width: 66, height: 90, radius: 12),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book['title']?.toString() ?? 'Book',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 14.5,
                          height: 1.18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        book['author']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 10.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          StatusBadge(
                            status: available > 0 ? 'Available' : 'Unavailable',
                          ),
                          if (category.isNotEmpty)
                            StatusBadge(status: category),
                          if (badge != null && badge.isNotEmpty)
                            StatusBadge(status: badge),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: accent.withOpacity(.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withOpacity(.13)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 15, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reasonText,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 10.5,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: Text(
                    available > 0
                        ? '$available copies available'
                        : 'Currently unavailable',
                    style: TextStyle(
                      color: available > 0 ? AppColors.text : AppColors.red,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: available > 0 ? () => reserveBook(book) : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                  label: const Text('Reserve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _group({
    required String number,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required List<dynamic> books,
    String Function(Map<String, dynamic>)? badgeBuilder,
    String Function(Map<String, dynamic>)? reasonBuilder,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0B1020),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            number,
                            style: TextStyle(
                              color: accent,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${books.length} / 3 books',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          if (books.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                number == '01'
                    ? 'No available books match your saved interests. Use Edit interests to change them.'
                    : number == '02'
                    ? 'Borrow a book to unlock content-based suggestions.'
                    : number == '03'
                    ? 'No recorded borrowing or reservation activity yet.'
                    : number == '04'
                    ? 'No additional titles have enough evidence yet.'
                    : 'Not enough overlapping reader histories yet.',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            )
          else if (books.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                number == '01'
                    ? 'No available books match your selected interests. Edit interests or add relevant books.'
                    : number == '02'
                    ? 'No further matches from your recorded borrowing categories.'
                    : number == '03'
                    ? 'No other titles with actual loan or reservation activity.'
                    : number == '04'
                    ? 'No further books meet the two-activity minimum.'
                    : 'No verified recommendations from similar readers yet.',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1050
                    ? 3
                    : constraints.maxWidth >= 680
                    ? 2
                    : 1;
                const gap = 14.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: books.take(3).map((item) {
                    final book = Map<String, dynamic>.from(item);
                    return SizedBox(
                      width: width,
                      child: _recommendationCard(
                        book,
                        accent: accent,
                        badge: badgeBuilder?.call(book),
                        reason: reasonBuilder?.call(book),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasteLabels = <String>[
      ...tasteCategories.map((e) => 'Category: $e'),
      ...tasteAuthors.map((e) => 'Author: $e'),
    ];

    return RefreshIndicator(
      onRefresh: load,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const LibrarySceneBanner(
            imagePath: 'assets/images/library_login_main.png',
            eyebrow: 'AI reading assistant',
            title: 'Your personalised reading guide',
            subtitle: 'Personal interests and real library activity. Up to three books per section.',
            icon: Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF8F7FF), Color(0xFFF2F7FF)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE5E5F6)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.psychology_alt_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your saved reading interests',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        tasteCategories.isEmpty
                            ? 'No interests saved. Use Edit interests.'
                            : 'Personal matches use your saved interests. '
                                  'Popular books use real circulation data.',
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 11.5,
                          height: 1.45,
                        ),
                      ),
                      if (tasteLabels.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: tasteLabels
                              .take(8)
                              .map((e) => StatusBadge(status: e))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                TextButton.icon(
                  onPressed: _editInterests,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Edit interests'),
                ),
                IconButton(
                  tooltip: 'Refresh recommendations',
                  onPressed: load,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 100),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (recommendationError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Recommendation load failed: $recommendationError',
                style: const TextStyle(color: AppColors.red),
              ),
            )
          else if (ApiService.memberId == null)
            const EmptyState(
              icon: Icons.link_off_rounded,
              title: 'Member account is not linked',
              subtitle: 'Activate your login using your Member ID and registered contact details.',
            )
          else ...[
            _group(
              number: '01',
              title: 'Matches your interests',
              subtitle: 'Books matching your selected categories.',
              icon: Icons.person_search_rounded,
              accent: AppColors.primary,
              books: personalised,
              badgeBuilder: (_) => 'Interest match',
            ),
            _group(
              number: '02',
              title: 'Because you borrowed...',
              subtitle: 'Direct content matches connected to books you already borrowed.',
              icon: Icons.account_tree_outlined,
              accent: AppColors.blue,
              books: becauseYouBorrowed,
              badgeBuilder: (book) =>
                  (book['source_title']?.toString().isNotEmpty ?? false)
                  ? 'From ${book['source_title']}'
                  : 'Taste match',
            ),
            _group(
              number: '03',
              title: 'Popular now',
              subtitle: 'Ranked by recorded borrows and active reservations.',
              icon: Icons.local_fire_department_outlined,
              accent: AppColors.amber,
              books: popularNow,
              badgeBuilder: (book) => '${toInt(book['borrow_count'])} borrows',
              reasonBuilder: (book) =>
                  'Popular now  -  ${toInt(book['borrow_count'])} borrows and ${toInt(book['reservation_count'])} active reservations',
            ),
            _group(
              number: '04',
              title: 'Highly recommended',
              subtitle: 'Titles supported by recorded borrowing activity.',
              icon: Icons.workspace_premium_outlined,
              accent: AppColors.mint,
              books: highlyRecommended,
              badgeBuilder: (_) => 'Activity backed',
            ),
            _group(
              number: '05',
              title: 'Readers like you also borrowed',
              subtitle: 'Collaborative suggestions from members whose borrowing overlaps with yours.',
              icon: Icons.groups_2_outlined,
              accent: AppColors.violet,
              books: similarReaders,
              badgeBuilder: (book) =>
                  '${toInt(book['similar_reader_count'])} similar readers',
            ),
            if (personalised.isEmpty &&
                popularNow.isEmpty &&
                highlyRecommended.isEmpty)
              const EmptyState(
                icon: Icons.auto_awesome_rounded,
                title: 'No recommendations yet',
                subtitle:
                    'Borrowing activity will create recommendation signals.',
              ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// ============================================================
// BOOKS
// ============================================================

class BooksPage extends StatefulWidget {
  const BooksPage({super.key});

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
  bool loading = true;
  List<dynamic> books = [];
  final searchController = TextEditingController();
  final authorController = TextEditingController();
  String category = '';
  String availability = '';
  String sort = 'title_asc';

  bool get canEdit =>
      ['admin', 'librarian'].contains((ApiService.role ?? '').toLowerCase());
  bool get canDelete => (ApiService.role ?? '').toLowerCase() == 'admin';
  bool get isMember => (ApiService.role ?? '').toLowerCase() == 'member';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    authorController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final params = <String, String>{
        if (searchController.text.trim().isNotEmpty)
          'search': searchController.text.trim(),
        if (authorController.text.trim().isNotEmpty)
          'author': authorController.text.trim(),
        if (category.isNotEmpty) 'category': category,
        if (availability.isNotEmpty) 'availability': availability,
        'sort': sort,
      };
      final query = Uri(queryParameters: params).query;
      final data = await ApiService.get('/books?$query');
      if (!mounted) return;
      setState(() => books = List<dynamic>.from(data));
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> reserveBook(Map<String, dynamic> book) async {
    if (!isMember || ApiService.memberId == null) return;

    if (toInt(book['available_copies']) <= 0) {
      showAppMessage(context, 'This title is currently unavailable');
      return;
    }

    try {
      await ApiService.post('/reservations', {
        'bookId': toInt(book['id']),
        'memberId': ApiService.memberId,
      });
      if (!mounted) return;
      showAppMessage(context, 'Reservation created for ${book['title']}');
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  Future<void> quickIsbnLookup() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ISBN / Barcode Quick Find'),
        content: SizedBox(
          width: 430,
          child: TextField(
            controller: controller,
            autofocus: true,
            onSubmitted: (v) => Navigator.pop(dialogContext, v.trim()),
            decoration: const InputDecoration(
              labelText: 'Scan or type ISBN',
              prefixIcon: Icon(Icons.qr_code_scanner_rounded),
              helperText: 'USB barcode scanners work here as keyboard input.',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Find'),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    searchController.text = value;
    await load();
  }

  Future<void> bookDialog({Map<String, dynamic>? book}) async {
    final isbn = TextEditingController(text: book?['isbn']?.toString() ?? '');
    final title = TextEditingController(text: book?['title']?.toString() ?? '');
    final author = TextEditingController(
      text: book?['author']?.toString() ?? '',
    );
    final categoryC = TextEditingController(
      text: book?['category']?.toString() ?? '',
    );

    final categoryOptions = <String>[
      'Technology & Computing',
      'Science & Engineering',
      'Business & Management',
      'History & Politics',
      'Biography & Memoir',
      'Self-development',
      'Health & Lifestyle',
      'Fiction / Novels',
      'Mystery & Thriller',
      'Romance',
      'Science Fiction & Fantasy',
      'Children & Young Adult',
      'Travel & Culture',
      'General / Other',
    ];

    final existingCategory = categoryC.text.trim();

    if (existingCategory.isNotEmpty &&
        !categoryOptions.contains(existingCategory)) {
      categoryOptions.add(existingCategory);
    }

    final publisher = TextEditingController(
      text: book?['publisher']?.toString() ?? '',
    );
    final copies = TextEditingController(
      text: book == null ? '1' : '${book['total_copies']}',
    );
    final cover = TextEditingController(
      text: book?['cover_url']?.toString() ?? '',
    );
    final shelf = TextEditingController(
      text: book?['shelf_location']?.toString() ?? '',
    );
    final description = TextEditingController(
      text: book?['description']?.toString() ?? '',
    );
    final threshold = TextEditingController(
      text: '${book?['low_stock_threshold'] ?? 1}',
    );

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(book == null ? 'Add Book' : 'Edit Book'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: isbn,
                        decoration: const InputDecoration(labelText: 'ISBN'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: copies,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total Copies',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: author,
                  decoration: const InputDecoration(labelText: 'Author'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: categoryC.text.trim().isEmpty
                            ? 'General / Other'
                            : categoryC.text.trim(),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: categoryOptions
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          categoryC.text = value ?? 'General / Other';
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: publisher,
                        decoration: const InputDecoration(
                          labelText: 'Publisher',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: shelf,
                        decoration: const InputDecoration(
                          labelText: 'Shelf Location',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: threshold,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Low-stock Threshold',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cover,
                  decoration: const InputDecoration(
                    labelText: 'Cover Image URL (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (save != true) return;

    try {
      final body = {
        'isbn': isbn.text.trim(),
        'title': title.text.trim(),
        'author': author.text.trim(),
        'category': categoryC.text.trim(),
        'publisher': publisher.text.trim(),
        'totalCopies': int.tryParse(copies.text.trim()) ?? 1,
        'coverUrl': cover.text.trim(),
        'shelfLocation': shelf.text.trim(),
        'description': description.text.trim(),
        'lowStockThreshold': int.tryParse(threshold.text.trim()) ?? 1,
      };
      if (book == null) {
        await ApiService.post('/books', body);
      } else {
        await ApiService.put('/books/${book['id']}', body);
      }
      if (!mounted) return;
      showAppMessage(
        context,
        book == null ? 'Book added successfully' : 'Book updated successfully',
      );
      await load();
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  Future<void> showDetails(Map<String, dynamic> book) async {
    try {
      final details = Map<String, dynamic>.from(
        await ApiService.get('/books/${book['id']}/details'),
      );
      List<dynamic> similar = [];
      try {
        final ai = Map<String, dynamic>.from(
          await ApiService.get('/ai/similar-book/${book['id']}'),
        );
        similar = List<dynamic>.from(ai['results'] ?? []);
      } catch (_) {}
      if (!mounted) return;
      final b = Map<String, dynamic>.from(details['book']);
      final recent = List<dynamic>.from(details['recentLoans'] ?? []);
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(b['title']?.toString() ?? 'Book Details'),
          content: SizedBox(
            width: 780,
            height: 590,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BookCoverArt(
                        book: b,
                        width: 120,
                        height: 170,
                        radius: 16,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b['author']?.toString() ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'ISBN ${b['isbn']}  -  ${b['category'] ?? 'Uncategorized'}',
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Shelf: ${b['shelf_location'] ?? '-'}  -  Publisher: ${b['publisher'] ?? '-'}',
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                StatusBadge(
                                  status:
                                      '${b['available_copies']}/${b['total_copies']} available',
                                ),
                                StatusBadge(
                                  status: '${b['borrow_count'] ?? 0} borrows',
                                ),
                                StatusBadge(
                                  status:
                                      '${b['active_reservation_count'] ?? 0} reservations',
                                ),
                              ],
                            ),
                            if ((b['description']?.toString() ?? '')
                                .isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Text(
                                b['description'].toString(),
                                style: const TextStyle(
                                  color: AppColors.text,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'AI Similar Books',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Click a suggestion to open its full book details.',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  if (similar.isEmpty)
                    const Text(
                      'Not enough catalogue data for similar-book suggestions yet.',
                      style: TextStyle(color: AppColors.muted),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: similar.map((s) {
                        final similarBook = Map<String, dynamic>.from(s);
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.pop(dialogContext);
                              Future.delayed(Duration.zero, () {
                                if (mounted) showDetails(similarBook);
                              });
                            },
                            child: Container(
                              width: 230,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryFaint,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BookCoverArt(
                                    book: similarBook,
                                    width: 48,
                                    height: 68,
                                    radius: 9,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s['title']?.toString() ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          s['author']?.toString() ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          'Match ${(toDouble(s['score']) * 100).toStringAsFixed(0)}%',
                                          style: const TextStyle(
                                            color: AppColors.primaryDark,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Open book ->',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 10,
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
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            if (isMember)
              FilledButton.icon(
                onPressed: toInt(b['available_copies']) > 0
                    ? () {
                        Navigator.pop(dialogContext);
                        reserveBook(b);
                      }
                    : null,
                icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                label: const Text('Reserve this book'),
              ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  Future<void> deleteBook(Map<String, dynamic> book) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Book'),
        content: Text('Delete "${book['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ApiService.delete('/books/${book['id']}');
      if (!mounted) return;
      showAppMessage(context, 'Book deleted successfully');
      await load();
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCopies = books.fold<int>(
      0,
      (sum, b) => sum + toInt(b['total_copies']),
    );
    final availableCopies = books.fold<int>(
      0,
      (sum, b) => sum + toInt(b['available_copies']),
    );
    final categories =
        books
            .map((b) => b['category']?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: RefreshIndicator(
        onRefresh: load,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const LibrarySceneBanner(
              imagePath: 'assets/images/library_shelves.png',
              eyebrow: 'Collection workspace',
              title: 'Explore the catalogue',
              subtitle: 'Search, filter, track popularity and use AI to understand similar titles.',
              icon: Icons.menu_book_rounded,
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 980
                    ? 4
                    : constraints.maxWidth >= 560
                    ? 2
                    : 1;
                const gap = 12.0;
                final tileWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: tileWidth,
                      child: PageStatTile(
                        label: 'Titles',
                        value: '${books.length}',
                        note: 'Catalogue records',
                        icon: Icons.menu_book_rounded,
                        accent: AppColors.primary,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: PageStatTile(
                        label: 'Total copies',
                        value: '$totalCopies',
                        note: 'Physical inventory',
                        icon: Icons.library_books_rounded,
                        accent: AppColors.blue,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: PageStatTile(
                        label: 'Available now',
                        value: '$availableCopies',
                        note: 'Ready to issue',
                        icon: Icons.check_circle_outline_rounded,
                        accent: AppColors.mint,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: PageStatTile(
                        label: 'Low stock',
                        value:
                            '${books.where((b) => b['low_stock'] == true).length}',
                        note: 'Needs attention',
                        icon: Icons.inventory_2_outlined,
                        accent: AppColors.amber,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            HoverCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Catalogue controls',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            onSubmitted: (_) => load(),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText:
                                  'Search title, author, ISBN, category...',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: load,
                          icon: const Icon(Icons.search),
                          label: const Text('Search'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: quickIsbnLookup,
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: const Text('ISBN Scan'),
                        ),
                        if (canEdit) ...[
                          const SizedBox(width: 10),
                          FilledButton.icon(
                            onPressed: () => bookDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Book'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: 180,
                          child: TextField(
                            controller: authorController,
                            onSubmitted: (_) => load(),
                            decoration: const InputDecoration(
                              labelText: 'Author filter',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 210,
                          child: DropdownButtonFormField<String>(
                            value: categories.contains(category)
                                ? category
                                : '',
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text(
                                  'All categories',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ...categories.map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) {
                              setState(() => category = v ?? '');
                              load();
                            },
                          ),
                        ),
                        SizedBox(
                          width: 175,
                          child: DropdownButtonFormField<String>(
                            value: availability,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Availability',
                            ),
                            items: const [
                              DropdownMenuItem(value: '', child: Text('All')),
                              DropdownMenuItem(
                                value: 'available',
                                child: Text('Available'),
                              ),
                              DropdownMenuItem(
                                value: 'unavailable',
                                child: Text('Unavailable'),
                              ),
                              DropdownMenuItem(
                                value: 'low',
                                child: Text('Low stock'),
                              ),
                            ],
                            onChanged: (v) {
                              setState(() => availability = v ?? '');
                              load();
                            },
                          ),
                        ),
                        SizedBox(
                          width: 190,
                          child: DropdownButtonFormField<String>(
                            value: sort,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Sort',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'title_asc',
                                child: Text('Title A-Z'),
                              ),
                              DropdownMenuItem(
                                value: 'title_desc',
                                child: Text('Title Z-A'),
                              ),
                              DropdownMenuItem(
                                value: 'popular',
                                child: Text('Most borrowed'),
                              ),
                              DropdownMenuItem(
                                value: 'available',
                                child: Text('Most available'),
                              ),
                              DropdownMenuItem(
                                value: 'newest',
                                child: Text('Newest'),
                              ),
                            ],
                            onChanged: (v) {
                              setState(() => sort = v ?? 'title_asc');
                              load();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            SectionHeader(
              title: 'Book catalogue',
              subtitle: '${books.length} titles match this view',
              action: IconButton(
                onPressed: load,
                icon: const Icon(Icons.refresh),
              ),
            ),
            const SizedBox(height: 14),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (books.isEmpty)
              const EmptyState(
                icon: Icons.menu_book_outlined,
                title: 'No books found',
                subtitle: 'Change the filters or add a new title.',
              )
            else
              ...books.map((book) {
                final low = book['low_stock'] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HoverCard(
                    onTap: () => showDetails(Map<String, dynamic>.from(book)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          BookCoverArt(
                            book: Map<String, dynamic>.from(book),
                            width: 74,
                            height: 102,
                            radius: 13,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  book['title']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  book['author']?.toString() ?? '',
                                  style: const TextStyle(color: AppColors.text),
                                ),
                                const SizedBox(height: 7),
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 7,
                                  children: [
                                    StatusBadge(
                                      status:
                                          toInt(book['available_copies']) > 0
                                          ? 'Available'
                                          : 'Unavailable',
                                    ),
                                    if ((book['category']?.toString() ?? '')
                                        .isNotEmpty)
                                      StatusBadge(
                                        status: book['category'].toString(),
                                      ),
                                    if (low)
                                      const StatusBadge(status: 'Low Stock'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'ISBN ${book['isbn']}  -  ${book['available_copies']}/${book['total_copies']} copies  -  ${book['borrow_count'] ?? 0} borrows  -  Shelf ${book['shelf_location'] ?? '-'}',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isMember)
                            OutlinedButton.icon(
                              onPressed: toInt(book['available_copies']) > 0
                                  ? () => reserveBook(
                                      Map<String, dynamic>.from(book),
                                    )
                                  : null,
                              icon: const Icon(
                                Icons.bookmark_add_outlined,
                                size: 17,
                              ),
                              label: const Text('Reserve'),
                            ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Details + AI similar books',
                            onPressed: () =>
                                showDetails(Map<String, dynamic>.from(book)),
                            icon: const Icon(
                              Icons.auto_awesome_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          if (canEdit)
                            IconButton(
                              tooltip: 'Edit',
                              onPressed: () => bookDialog(
                                book: Map<String, dynamic>.from(book),
                              ),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          if (canDelete)
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () =>
                                  deleteBook(Map<String, dynamic>.from(book)),
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MEMBERS
// ============================================================

class MembersPage extends StatefulWidget {
  const MembersPage({super.key});

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  bool loading = true;
  List<dynamic> members = [];
  final searchController = TextEditingController();
  String statusFilter = '';

  bool get canEdit =>
      ['admin', 'librarian'].contains((ApiService.role ?? '').toLowerCase());
  bool get canDelete => (ApiService.role ?? '').toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final query = Uri(
        queryParameters: {
          if (searchController.text.trim().isNotEmpty)
            'search': searchController.text.trim(),
          if (statusFilter.isNotEmpty) 'status': statusFilter,
        },
      ).query;
      final data = await ApiService.get('/members?$query');
      if (!mounted) return;
      setState(() => members = List<dynamic>.from(data));
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> memberDialog({Map<String, dynamic>? member}) async {
    final codeC = TextEditingController(
      text: member?['member_code']?.toString() ?? '',
    );
    final name = TextEditingController(text: member?['name']?.toString() ?? '');
    final email = TextEditingController(
      text: member?['email']?.toString() ?? '',
    );
    final phone = TextEditingController(
      text: member?['phone']?.toString() ?? '',
    );
    final expiry = TextEditingController(
      text: member?['membership_expiry'] == null
          ? ''
          : formatDate(member?['membership_expiry']),
    );
    final notes = TextEditingController(
      text: member?['notes']?.toString() ?? '',
    );
    String status = member?['status']?.toString() ?? 'Active';

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(member == null ? 'Add Member' : 'Edit Member'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeC,
                          decoration: const InputDecoration(
                            labelText: 'Member Code',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Active',
                              child: Text('Active'),
                            ),
                            DropdownMenuItem(
                              value: 'Inactive',
                              child: Text('Inactive'),
                            ),
                          ],
                          onChanged: (v) =>
                              setLocal(() => status = v ?? 'Active'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: email,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: phone,
                          decoration: const InputDecoration(labelText: 'Phone'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: expiry,
                    decoration: const InputDecoration(
                      labelText: 'Membership Expiry (YYYY-MM-DD)',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (save != true) return;

    try {
      final body = {
        'memberCode': codeC.text.trim(),
        'name': name.text.trim(),
        'email': email.text.trim(),
        'phone': phone.text.trim(),
        'status': status,
        'membershipExpiry': expiry.text.trim().isEmpty
            ? null
            : expiry.text.trim(),
        'notes': notes.text.trim(),
      };
      if (member == null)
        await ApiService.post('/members', body);
      else
        await ApiService.put('/members/${member['id']}', body);
      if (!mounted) return;
      showAppMessage(
        context,
        member == null
            ? 'Member added successfully'
            : 'Member updated successfully',
      );
      await load();
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  Future<void> showProfile(Map<String, dynamic> member) async {
    try {
      final profile = Map<String, dynamic>.from(
        await ApiService.get('/members/${member['id']}/profile'),
      );
      Map<String, dynamic>? risk;
      try {
        risk = Map<String, dynamic>.from(
          await ApiService.get('/ai/member-risk/${member['id']}'),
        );
      } catch (_) {}
      Map<String, dynamic>? rec;
      try {
        rec = Map<String, dynamic>.from(
          await ApiService.get(
            '/ai/recommendations/member/${member['id']}?limit=4',
          ),
        );
      } catch (_) {}
      if (!mounted) return;
      final m = Map<String, dynamic>.from(profile['member']);
      final loans = List<dynamic>.from(profile['loans'] ?? []);
      final reservations = List<dynamic>.from(profile['reservations'] ?? []);
      final recommendations = List<dynamic>.from(rec?['recommendations'] ?? []);
      final riskLevel = risk?['risk_level']?.toString() ?? 'Unavailable';
      final riskScore = toDouble(risk?['risk_score']);
      final riskColor = riskLevel == 'High'
          ? AppColors.red
          : riskLevel == 'Medium'
          ? AppColors.amber
          : AppColors.mint;

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('${m['name']}  -  ${m['member_code']}'),
          content: SizedBox(
            width: 830,
            height: 640,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: QrImageView(
                          data: 'MEMBER:${m['member_code']}',
                          size: 135,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m['email']?.toString() ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              m['phone']?.toString() ?? '-',
                              style: const TextStyle(color: AppColors.text),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                StatusBadge(
                                  status: m['status']?.toString() ?? '',
                                ),
                                StatusBadge(
                                  status:
                                      '${m['active_loans'] ?? 0} active loans',
                                ),
                                StatusBadge(
                                  status:
                                      'LKR ${formatMoney(m['unpaid_fines'])} unpaid',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Joined ${formatDate(m['joined_at'])}  -  Membership expiry ${formatDate(m['membership_expiry'])}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 190,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: riskColor.withOpacity(.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: riskColor.withOpacity(.28)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AI RISK SCORE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              riskLevel,
                              style: TextStyle(
                                color: riskColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                              ),
                            ),
                            Text(
                              '${(riskScore * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              risk?['risk_reason']?.toString() ??
                                  'AI service unavailable',
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 10,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Borrowing History',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (loans.isEmpty)
                    const Text(
                      'No loans yet.',
                      style: TextStyle(color: AppColors.muted),
                    )
                  else
                    ...loans
                        .take(8)
                        .map(
                          (l) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.history),
                            title: Text(l['book_title']?.toString() ?? ''),
                            subtitle: Text(
                              'Issued ${formatDate(l['issue_date'])}  -  Due ${formatDate(l['due_date'])}  -  Fine LKR ${formatMoney(l['fine'])}',
                            ),
                            trailing: StatusBadge(
                              status:
                                  l['display_status']?.toString() ??
                                  l['status']?.toString() ??
                                  '',
                            ),
                          ),
                        ),
                  const SizedBox(height: 18),
                  const Text(
                    'Active / Recent Reservations',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (reservations.isEmpty)
                    const Text(
                      'No reservations.',
                      style: TextStyle(color: AppColors.muted),
                    )
                  else
                    ...reservations
                        .take(5)
                        .map(
                          (r) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.bookmark_outline),
                            title: Text(r['book_title']?.toString() ?? ''),
                            subtitle: Text(
                              'Reserved ${formatDate(r['reservation_date'])}',
                            ),
                            trailing: StatusBadge(
                              status: r['status']?.toString() ?? '',
                            ),
                          ),
                        ),
                  const SizedBox(height: 18),
                  const Text(
                    'AI Recommendations',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  if (recommendations.isEmpty)
                    const Text(
                      'No recommendations yet.',
                      style: TextStyle(color: AppColors.muted),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: recommendations
                          .map(
                            (b) => Container(
                              width: 230,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryFaint,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b['title']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    b['reason']?.toString() ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  Future<void> deleteMember(Map<String, dynamic> member) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Member'),
        content: Text('Delete "${member['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ApiService.delete('/members/${member['id']}');
      if (!mounted) return;
      showAppMessage(context, 'Member deleted');
      await load();
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = members.where((m) => m['status'] == 'Active').length;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: RefreshIndicator(
        onRefresh: load,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const LibrarySceneBanner(
              imagePath: 'assets/images/library_reader.png',
              eyebrow: 'Member experience',
              title: 'People at the center',
              subtitle: 'Profiles, borrowing history, QR identity and AI risk insights in one place.',
              icon: Icons.groups_2_rounded,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onSubmitted: (_) => load(),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search name, member code, email...',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    value: statusFilter,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All')),
                      DropdownMenuItem(value: 'Active', child: Text('Active')),
                      DropdownMenuItem(
                        value: 'Inactive',
                        child: Text('Inactive'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => statusFilter = v ?? '');
                      load();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: load,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                ),
                if (canEdit) ...[
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => memberDialog(),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Add Member'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              children: [
                StatusBadge(status: '${members.length} total'),
                StatusBadge(status: '$active active'),
                StatusBadge(status: '${members.length - active} inactive'),
              ],
            ),
            const SizedBox(height: 20),
            SectionHeader(
              title: 'Member directory',
              subtitle: 'Open a member to see history, QR identity, fines and AI insights',
              action: IconButton(
                onPressed: load,
                icon: const Icon(Icons.refresh),
              ),
            ),
            const SizedBox(height: 14),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (members.isEmpty)
              const EmptyState(
                icon: Icons.groups_outlined,
                title: 'No members found',
                subtitle: 'Add or search for a library member.',
              )
            else
              ...members.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HoverCard(
                    onTap: () => showProfile(Map<String, dynamic>.from(m)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: AppColors.primarySoft,
                            child: Text(
                              (m['name']?.toString().isNotEmpty ?? false)
                                  ? m['name'].toString()[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['name']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${m['member_code']}  -  ${m['email'] ?? '-'}',
                                  style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${m['active_loan_count'] ?? 0} active loans  -  LKR ${formatMoney(m['unpaid_fines'])} unpaid fines  -  ${m['active_reservation_count'] ?? 0} reservations',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(status: m['status']?.toString() ?? ''),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Profile + AI risk',
                            onPressed: () =>
                                showProfile(Map<String, dynamic>.from(m)),
                            icon: const Icon(
                              Icons.auto_awesome_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          if (canEdit)
                            IconButton(
                              onPressed: () => memberDialog(
                                member: Map<String, dynamic>.from(m),
                              ),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          if (canDelete)
                            IconButton(
                              onPressed: () =>
                                  deleteMember(Map<String, dynamic>.from(m)),
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LOANS
// ============================================================

class LoansPage extends StatefulWidget {
  const LoansPage({super.key});
  @override
  State<LoansPage> createState() => _LoansPageState();
}

class _LoansPageState extends State<LoansPage> {
  bool loading = true;
  List<dynamic> loans = [];
  String filter = 'All';

  final TextEditingController loanSearchController = TextEditingController();
  bool get canOperate =>
      ['admin', 'librarian'].contains((ApiService.role ?? '').toLowerCase());

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    loanSearchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final data = await ApiService.get('/loans');
      if (!mounted) return;
      setState(() => loans = List<dynamic>.from(data));
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<dynamic> get filtered {
    final query = loanSearchController.text.trim().toLowerCase();

    return loans.where((loan) {
      final status =
          loan['display_status']?.toString() ??
          loan['status']?.toString() ??
          '';

      bool statusMatches = true;

      if (filter == 'Unpaid Fine') {
        statusMatches =
            toDouble(loan['calculated_fine'] ?? loan['fine']) > 0 &&
            loan['fine_paid'] != true;
      } else if (filter != 'All') {
        statusMatches = status == filter;
      }

      if (!statusMatches) return false;

      if (query.isEmpty) return true;

      final searchable = [
        loan['book_title'],
        loan['isbn'],
        loan['member_name'],
        loan['member_code'],
        loan['status'],
        loan['display_status'],
      ].map((x) => x?.toString() ?? '').join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  String dueText(dynamic loan) {
    if ((loan['status']?.toString() ?? '') != 'Issued')
      return 'Returned ${formatDate(loan['return_date'])}';
    final days = correctLoanDays(loan);
    if (days < 0) return '${-days} day${-days == 1 ? '' : 's'} overdue';
    if (days == 0) return 'Due today';
    return '$days day${days == 1 ? '' : 's'} left';
  }

  Future<void> issueDialog() async {
    try {
      final books = List<dynamic>.from(
        await ApiService.get('/books?availability=available'),
      );
      final members = List<dynamic>.from(
        await ApiService.get('/members?status=Active'),
      );
      if (books.isEmpty || members.isEmpty) {
        if (mounted)
          showAppMessage(
            context,
            'Available books or active members are missing',
          );
        return;
      }
      int bookId = toInt(books.first['id']);
      int memberId = toInt(members.first['id']);
      DateTime dueDate = DateTime.now().add(const Duration(days: 14));
      if (!mounted) return;
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (_, setLocal) => AlertDialog(
            title: const Text('Issue Book'),
            content: SizedBox(
              width: 570,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: bookId,
                    isExpanded: true,
                    menuMaxHeight: 360,
                    decoration: const InputDecoration(labelText: 'Book'),
                    items: books
                        .map<DropdownMenuItem<int>>(
                          (b) => DropdownMenuItem(
                            value: toInt(b['id']),
                            child: Text(
                              '${b['title']} (${b['available_copies']} available)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setLocal(() => bookId = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: memberId,
                    isExpanded: true,
                    menuMaxHeight: 360,
                    decoration: const InputDecoration(labelText: 'Member'),
                    items: members
                        .map<DropdownMenuItem<int>>(
                          (m) => DropdownMenuItem(
                            value: toInt(m['id']),
                            child: Text(
                              '${m['member_code']} - ${m['name']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setLocal(() => memberId = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Due ${dueDate.toIso8601String().substring(0, 10)}',
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: dueDate,
                            firstDate: DateTime(2020, 1, 1),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (d != null) setLocal(() => dueDate = d);
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Select'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Issue'),
              ),
            ],
          ),
        ),
      );
      if (yes != true) return;
      await ApiService.post('/loans/issue', {
        'bookId': bookId,
        'memberId': memberId,
        'dueDate': dueDate.toIso8601String().substring(0, 10),
      });
      if (!mounted) return;
      showAppMessage(context, 'Book issued successfully');
      await load();
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  Future<void> quickIssue() async {
    final isbn = TextEditingController();
    final member = TextEditingController();
    DateTime due = DateTime.now().add(const Duration(days: 14));
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (_, setLocal) => AlertDialog(
          title: const Text('Fast Barcode Issue'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: isbn,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Scan / type book ISBN',
                    prefixIcon: Icon(Icons.qr_code_scanner),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: member,
                  decoration: const InputDecoration(
                    labelText: 'Scan / type member code',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Due ${due.toIso8601String().substring(0, 10)}',
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: due,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (d != null) setLocal(() => due = d);
                      },
                      child: const Text('Change'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Issue'),
            ),
          ],
        ),
      ),
    );
    if (yes != true) return;
    try {
      await ApiService.post('/loans/issue-by-code', {
        'isbn': isbn.text.trim(),
        'memberCode': member.text.trim(),
        'dueDate': due.toIso8601String().substring(0, 10),
      });
      if (!mounted) return;
      showAppMessage(context, 'Book issued by barcode');
      await load();
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  Future<void> returnBook(Map<String, dynamic> loan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primarySoft,
                child: Icon(
                  Icons.assignment_return_outlined,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 12),
              Text('Return book'),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Confirm that this physical book has been returned to the library.',
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFaint,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan['book_title']?.toString() ?? 'Book',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${loan['member_code'] ?? ''} ? ${loan['member_name'] ?? ''}',
                        style: const TextStyle(color: AppColors.text),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Due ${formatDate(loan['due_date'])}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Confirm return'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final raw = await ApiService.post('/loans/${loan['id']}/return-safe', {});

      final data = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};

      if (!mounted) return;

      final fine = toDouble(data['fine']);

      showAppMessage(
        context,
        fine > 0
            ? 'Book returned ? Fine LKR ${formatMoney(fine)}'
            : 'Book returned successfully ? No fine',
      );

      await load();
    } catch (e) {
      if (mounted) {
        showAppMessage(context, e);
      }
    }
  }

  Future<void> payFine(Map<String, dynamic> loan) async {
    try {
      await ApiService.put('/loans/${loan['id']}/pay-fine');
      if (!mounted) return;
      showAppMessage(context, 'Fine marked as paid');
      await load();
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  Future<void> renew(Map<String, dynamic> loan) async {
    try {
      await ApiService.post('/loans/${loan['id']}/renew', {'extraDays': 14});
      if (!mounted) return;
      showAppMessage(context, 'Loan renewed for 14 days');
      await load();
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  Future<void> receipt(Map<String, dynamic> loan) async {
    try {
      final r = Map<String, dynamic>.from(
        await ApiService.get('/loans/${loan['id']}/receipt'),
      );
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Receipt ${r['receiptNo']}'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['book_title']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text('ISBN: ${r['isbn']}'),
                Text('Member: ${r['member_code']} - ${r['member_name']}'),
                const Divider(height: 28),
                Text('Issued: ${formatDate(r['issue_date'])}'),
                Text('Due: ${formatDate(r['due_date'])}'),
                Text('Returned: ${formatDate(r['return_date'])}'),
                Text('Status: ${r['status']}'),
                if (correctLoanFine(r) > 0)
                  Text(
                    'Accrued fine estimate: LKR ${formatMoney(correctLoanFine(r))} (not yet posted)',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                Text(
                  toDouble(r['fine']) > 0
                      ? 'Fine: LKR ${formatMoney(r['fine'])}'
                      : 'Fine: No fine',
                ),
                Text(
                  'Fine payment: ${toDouble(r['fine']) <= 0 ? 'Not applicable' : (r['fine_paid'] == true ? 'Paid' : 'Unpaid')}',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMember = (ApiService.role ?? '').toLowerCase() == 'member';
    final active = loans.where((l) => l['status'] == 'Issued').length;
    final overdue = loans.where((l) => l['display_status'] == 'Overdue').length;
    final unpaid = loans
        .where((l) => correctLoanFine(l) > 0 && l['fine_paid'] != true)
        .length;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: RefreshIndicator(
        onRefresh: load,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            LibrarySceneBanner(
              imagePath: 'assets/images/library_modern.png',
              eyebrow: isMember ? 'My borrowing' : 'Circulation workspace',
              title: isMember
                  ? 'Your loans, clearly organised'
                  : 'Keep every loan moving',
              subtitle: isMember
                  ? 'Track due dates, overdue status, fines and your complete borrowing history.'
                  : 'Renew loans, calculate overdue fines, process returns and print receipt data.',
              icon: Icons.swap_horiz_rounded,
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final returned = loans
                    .where((l) => l['status'] == 'Returned')
                    .length;
                final columns = constraints.maxWidth >= 980
                    ? 4
                    : constraints.maxWidth >= 560
                    ? 2
                    : 1;
                const gap = 12.0;
                final tileWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: tileWidth,
                      child: PageStatTile(
                        label: 'Issued',
                        value: '$active',
                        note: 'Currently on loan',
                        icon: Icons.swap_horiz_rounded,
                        accent: AppColors.cyan,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: PageStatTile(
                        label: 'Overdue',
                        value: '$overdue',
                        note: 'Needs staff attention',
                        icon: Icons.warning_amber_rounded,
                        accent: overdue > 0 ? AppColors.red : AppColors.mint,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: PageStatTile(
                        label: 'Returned',
                        value: '$returned',
                        note: 'Completed circulation',
                        icon: Icons.task_alt_rounded,
                        accent: AppColors.mint,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: PageStatTile(
                        label: 'Unpaid fines',
                        value: '$unpaid',
                        note: 'Outstanding payments',
                        icon: Icons.payments_outlined,
                        accent: AppColors.amber,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),

            HoverCard(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: isMember
                          ? 'My borrowing history'
                          : 'Circulation desk',
                      subtitle: isMember
                          ? 'Filter your current and previous loans'
                          : 'Issue, renew, return and settle fines',
                      action: canOperate
                          ? Wrap(
                              spacing: 10,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: quickIssue,
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: const Text('Fast Issue'),
                                ),
                                FilledButton.icon(
                                  onPressed: issueDialog,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Issue Book'),
                                ),
                              ],
                            )
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: loanSearchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'Search book, member, Member ID or ISBN...',
                        suffixIcon: loanSearchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  loanSearchController.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          [
                                'All',
                                'Issued',
                                'Overdue',
                                'Returned',
                                'Unpaid Fine',
                              ]
                              .map(
                                (x) => ChoiceChip(
                                  label: Text(x),
                                  selected: filter == x,
                                  onSelected: (_) => setState(() => filter = x),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (filtered.isEmpty)
              const EmptyState(
                icon: Icons.swap_horiz_rounded,
                title: 'No loans in this view',
                subtitle: 'Issue a book or change the filter.',
              )
            else
              ...filtered.map((l) {
                final status =
                    l['display_status']?.toString() ??
                    l['status']?.toString() ??
                    '';
                final isIssued = l['status'] == 'Issued';
                final isOverdue = status == 'Overdue';
                final fine = correctLoanFine(l);
                final unpaidFine = fine > 0 && l['fine_paid'] != true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HoverCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isOverdue
                                  ? AppColors.red.withOpacity(.10)
                                  : AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              isOverdue
                                  ? Icons.warning_amber_rounded
                                  : Icons.swap_horiz_rounded,
                              color: isOverdue
                                  ? AppColors.red
                                  : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l['book_title']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${l['member_code']}  -  ${l['member_name']}',
                                  style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 11.5,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Issued ${formatDate(l['issue_date'])}  -  Due ${formatDate(l['due_date'])}  -  ${dueText(l)}  -  Renewed ${l['renew_count'] ?? 0}/2',
                                  style: TextStyle(
                                    color: isOverdue
                                        ? AppColors.red
                                        : AppColors.muted,
                                    fontSize: 10.5,
                                    fontWeight: isOverdue
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(status: status),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: fine > 0
                                  ? AppColors.red.withOpacity(.08)
                                  : AppColors.mint.withOpacity(.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              fine > 0
                                  ? 'Fine LKR ${formatMoney(fine)}'
                                  : 'No fine',
                              style: TextStyle(
                                color: fine > 0
                                    ? AppColors.red
                                    : const Color(0xFF14835F),
                                fontWeight: FontWeight.w900,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: 'Receipt',
                            onPressed: () =>
                                receipt(Map<String, dynamic>.from(l)),
                            icon: const Icon(Icons.receipt_long_outlined),
                          ),
                          if (canOperate && isIssued)
                            IconButton(
                              tooltip: 'Renew +14 days',
                              onPressed: () =>
                                  renew(Map<String, dynamic>.from(l)),
                              icon: const Icon(Icons.update_rounded),
                            ),
                          if (canOperate && isIssued)
                            FilledButton.tonal(
                              onPressed: () =>
                                  returnBook(Map<String, dynamic>.from(l)),
                              child: const Text('Return'),
                            ),
                          if (canOperate && unpaidFine) ...[
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () =>
                                  payFine(Map<String, dynamic>.from(l)),
                              child: const Text('Mark Paid'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// RESERVATIONS
// ============================================================

class ReservationsPage extends StatefulWidget {
  const ReservationsPage({super.key});
  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  bool loading = true;
  List<dynamic> reservations = [];

  final TextEditingController reservationSearchController =
      TextEditingController();

  List<dynamic> get visibleReservations {
    final query = reservationSearchController.text.trim().toLowerCase();

    if (query.isEmpty) return reservations;

    return reservations.where((reservation) {
      final searchable = [
        reservation['book_title'],
        reservation['member_name'],
        reservation['member_code'],
        reservation['status'],
      ].map((x) => x?.toString() ?? '').join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();
  }

  bool get isMember => (ApiService.role ?? '').toLowerCase() == 'member';

  bool get canOperate =>
      ['admin', 'librarian'].contains((ApiService.role ?? '').toLowerCase());

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    reservationSearchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final d = await ApiService.get('/reservations');
      if (!mounted) return;
      setState(() => reservations = List<dynamic>.from(d));
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addReservation() async {
    try {
      final books = List<dynamic>.from(await ApiService.get('/books'));
      List<dynamic> members = [];
      if (canOperate)
        members = List<dynamic>.from(
          await ApiService.get('/members?status=Active'),
        );
      if (books.isEmpty || (canOperate && members.isEmpty)) {
        if (mounted) showAppMessage(context, 'Books or members unavailable');
        return;
      }
      int bookId = toInt(books.first['id']);
      int memberId = canOperate
          ? toInt(members.first['id'])
          : (ApiService.memberId ?? 0);
      if (!mounted) return;
      final save = await showDialog<bool>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (_, setLocal) => AlertDialog(
            title: Text(isMember ? 'Request a Book' : 'New Reservation'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: bookId,
                    isExpanded: true,
                    menuMaxHeight: 360,
                    decoration: const InputDecoration(labelText: 'Book'),
                    items: books
                        .map<DropdownMenuItem<int>>(
                          (b) => DropdownMenuItem(
                            value: toInt(b['id']),
                            child: Text(
                              '${b['title']}  -  ${b['available_copies']} available',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setLocal(() => bookId = v);
                    },
                  ),
                  if (canOperate) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: memberId,
                      isExpanded: true,
                      menuMaxHeight: 360,
                      decoration: const InputDecoration(labelText: 'Member'),
                      items: members
                          .map<DropdownMenuItem<int>>(
                            (m) => DropdownMenuItem(
                              value: toInt(m['id']),
                              child: Text(
                                '${m['member_code']} - ${m['name']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setLocal(() => memberId = v);
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(isMember ? 'Request Book' : 'Reserve'),
              ),
            ],
          ),
        ),
      );
      if (save != true) return;
      await ApiService.post('/reservations', {
        'bookId': bookId,
        'memberId': memberId,
      });
      if (!mounted) return;
      showAppMessage(context, 'Reservation created');
      await load();
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  Future<void> cancel(Map<String, dynamic> r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.event_busy_outlined, color: Color(0xFFCF4055)),
            SizedBox(width: 12),
            Expanded(child: Text('Cancel reservation?')),
          ],
        ),
        content: SizedBox(
          width: 410,
          child: Text(
            'Cancel the reservation for "${r['book_title'] ?? 'this book'}"? '
            'This will update the reservation status.',
            style: const TextStyle(height: 1.5, color: AppColors.text),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep reservation'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFCF4055),
            ),
            icon: const Icon(Icons.event_busy_outlined, size: 17),
            label: const Text('Yes, cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.put('/reservations/${r['id']}/cancel');

      if (!mounted) return;

      showAppMessage(context, 'Reservation cancelled');
      await load();
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  Future<void> ready(Map<String, dynamic> r) async {
    try {
      await ApiService.put('/reservations/${r['id']}/ready');
      if (!mounted) return;
      showAppMessage(context, 'Book request approved and member notified');
      await load();
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  Future<void> reject(Map<String, dynamic> r) async {
    try {
      await ApiService.put('/reservations/${r['id']}/reject');
      if (!mounted) return;
      showAppMessage(context, 'Book request rejected and member notified');
      await load();
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  Future<void> convert(Map<String, dynamic> r) async {
    DateTime due = DateTime.now().add(const Duration(days: 14));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(Icons.menu_book_rounded, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(child: Text('Issue reserved book')),
            ],
          ),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BOOK DETAILS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${r['book_title'] ?? 'Selected book'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Member: ${r['member_name'] ?? r['member_code'] ?? ''}',
                  style: const TextStyle(color: AppColors.text),
                ),
                const SizedBox(height: 22),

                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'RETURN DUE DATE',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              due.toIso8601String().substring(0, 10),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: dialogContext,
                            initialDate: due,
                            firstDate: DateTime(2020, 1, 1),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );

                          if (date != null) {
                            updateDialog(() => due = date);
                          }
                        },
                        icon: const Icon(
                          Icons.edit_calendar_outlined,
                          size: 17,
                        ),
                        label: const Text('Change'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Back'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
              label: const Text('Confirm issue'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.post('/reservations/${r['id']}/convert-to-loan', {
        'dueDate': due.toIso8601String().substring(0, 10),
      });

      if (!mounted) return;

      showAppMessage(context, 'Reservation converted to active loan');
      await load();
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  Widget _reservationCard(Map<String, dynamic> r) {
    final status = r['status']?.toString() ?? '';
    final active = status == 'Pending' || status == 'Ready';

    final bookTitle = r['book_title']?.toString() ?? 'Untitled book';

    final memberName = r['member_name']?.toString() ?? '';

    final memberCode = r['member_code']?.toString() ?? '';

    final details = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: status == 'Ready'
                ? const Color(0xFFE8F8F2)
                : AppColors.primarySoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            status == 'Ready'
                ? Icons.inventory_2_outlined
                : Icons.bookmark_border_rounded,
            color: status == 'Ready'
                ? const Color(0xFF149A76)
                : AppColors.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bookTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                isMember ? 'My reservation' : '$memberCode | $memberName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.text, fontSize: 12.5),
              ),
              const SizedBox(height: 6),
              Text(
                'Reserved: ${formatDate(r['reservation_date'])}    '
                'Expires: ${formatDate(r['expiry_date'])}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );

    final actionRow = Wrap(
      spacing: 9,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusBadge(status: status),

        if (canOperate && status == 'Pending')
          FilledButton.icon(
            onPressed: () => ready(r),
            icon: const Icon(Icons.check_rounded, size: 17),
            label: const Text('Approve'),
          ),

        if (canOperate && status == 'Pending')
          OutlinedButton.icon(
            onPressed: () => reject(r),
            icon: const Icon(Icons.block_outlined, size: 17),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFBF4654),
            ),
          ),

        if (canOperate && status == 'Ready')
          FilledButton.icon(
            onPressed: () => convert(r),
            icon: const Icon(Icons.menu_book_outlined, size: 17),
            label: const Text('Issue Book'),
          ),

        if (active)
          OutlinedButton.icon(
            onPressed: () => cancel(r),
            icon: const Icon(Icons.event_busy_outlined, size: 17),
            label: Text(isMember ? 'Cancel request' : 'Cancel reservation'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFBF4654),
              side: const BorderSide(color: Color(0xFFF1C6CD)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HoverCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 860) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    details,
                    const SizedBox(height: 14),
                    Align(alignment: Alignment.centerLeft, child: actionRow),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 16),
                  Flexible(child: actionRow),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMember = (ApiService.role ?? '').toLowerCase() == 'member';
    final pending = reservations.where((r) => r['status'] == 'Pending').length;
    final readyCount = reservations.where((r) => r['status'] == 'Ready').length;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: RefreshIndicator(
        onRefresh: load,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            LibrarySceneBanner(
              height: 148,
              imagePath: 'assets/images/library_login_main.png',
              eyebrow: isMember ? 'My reservations' : 'Reservation flow',
              title: isMember ? 'Plan your next read' : 'Plan the next read',
              subtitle: isMember
                  ? 'Track queue position, pickup readiness and reservation expiry in one place.'
                  : 'Queue positions, pickup expiry, notifications and one-click conversion to loans.',
              icon: Icons.bookmark_add_outlined,
            ),
            const SizedBox(height: 20),
            SectionHeader(
              title: isMember ? 'My reservation queue' : 'Reservation queue',
              subtitle: isMember
                  ? 'Your pending requests and books ready for pickup'
                  : 'Manage pending requests and books ready for pickup',
              action: FilledButton.icon(
                onPressed: addReservation,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(isMember ? 'Request Book' : 'New Reservation'),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              children: [
                StatusBadge(status: '$pending pending'),
                StatusBadge(status: '$readyCount ready'),
                StatusBadge(status: '${reservations.length} total'),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reservationSearchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Search reservation, book, member or Member ID...',
                suffixIcon: reservationSearchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          reservationSearchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 18),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (visibleReservations.isEmpty)
              const EmptyState(
                icon: Icons.bookmark_border_rounded,
                title: 'No reservations',
                subtitle: 'Create the first reservation.',
              )
            else
              ...visibleReservations.map(
                (r) => _reservationCard(Map<String, dynamic>.from(r as Map)),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// REPORTS
// ============================================================

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final ScrollController _scrollController = ScrollController();
  bool loading = true;
  bool exporting = false;
  Map<String, dynamic> summary = {};
  Map<String, dynamic> analytics = {};
  DateTime from = DateTime.now().subtract(const Duration(days: 180));
  DateTime to = DateTime.now();

  String date(DateTime d) => d.toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final results = await Future.wait([
        ApiService.get('/reports/summary'),
        ApiService.get('/reports/analytics?from=${date(from)}&to=${date(to)}'),
      ]);
      if (!mounted) return;
      setState(() {
        summary = Map<String, dynamic>.from(results[0]);
        analytics = Map<String, dynamic>.from(results[1]);
      });
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> pickFrom() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: from,
      initialEntryMode: DatePickerEntryMode.calendar,
      helpText: 'Select start date',
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (d != null) {
      setState(() {
        from = d;
        if (to.isBefore(from)) to = from;
      });
      await load();
    }
  }

  Future<void> pickTo() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: to,
      initialEntryMode: DatePickerEntryMode.calendar,
      helpText: 'Select end date',
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (d != null) {
      setState(() {
        to = d;
        if (from.isAfter(to)) from = to;
      });
      await load();
    }
  }

  Future<void> export(String type) async {
    if (loading) {
      showAppMessage(context, 'Report data is still loading');
      return;
    }
    if (exporting) return;

    final ext = type == 'xlsx' ? 'xlsx' : type;
    setState(() => exporting = true);
    try {
      if (ext != 'xlsx' && ext != 'pdf') {
        throw Exception('Unsupported export type');
      }

      ApiService.downloadWebFile(
        path: '/reports/export.$ext?from=${date(from)}&to=${date(to)}',
        filename: 'library-report-${date(from)}-${date(to)}.$ext',
      );

      if (mounted) {
        showAppMessage(context, '$ext report download started');
      }
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthly = List<dynamic>.from(analytics['monthlyLoans'] ?? []);
    final categories = List<dynamic>.from(
      analytics['categoryPopularity'] ?? [],
    );
    final popular = List<dynamic>.from(analytics['popularBooks'] ?? []);
    final activeMembers = List<dynamic>.from(analytics['activeMembers'] ?? []);
    final fines = Map<String, dynamic>.from(analytics['fineCollection'] ?? {});

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: RefreshIndicator(
        onRefresh: load,
        color: AppColors.primary,
        child: ListView(
          controller: _scrollController,
          primary: false,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const LibrarySceneBanner(
              imagePath: 'assets/images/library_modern.png',
              eyebrow: 'Library intelligence',
              title: 'See the story behind the numbers',
              subtitle: 'Date-range analytics, trends, top books, active members and exportable reports.',
              icon: Icons.insights_rounded,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: exporting ? null : pickFrom,
                  icon: const Icon(Icons.date_range),
                  label: Text('From ${date(from)}'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: exporting ? null : pickTo,
                  icon: const Icon(Icons.event),
                  label: Text('To ${date(to)}'),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: loading || exporting ? null : () => export('xlsx'),
                  icon: exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.table_chart_outlined),
                  label: Text(exporting ? 'Exporting...' : 'Export Excel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: loading || exporting ? null : () => export('pdf'),
                  icon: exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(exporting ? 'Exporting...' : 'Export PDF'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else ...[
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: 210,
                    height: 145,
                    child: MetricCard(
                      label: 'Book Titles',
                      value: '${summary['books'] ?? 0}',
                      icon: Icons.menu_book_rounded,
                      accent: AppColors.primary,
                    ),
                  ),
                  SizedBox(
                    width: 210,
                    height: 145,
                    child: MetricCard(
                      label: 'Members',
                      value: '${summary['members'] ?? 0}',
                      icon: Icons.groups_outlined,
                      accent: AppColors.pink,
                    ),
                  ),
                  SizedBox(
                    width: 210,
                    height: 145,
                    child: MetricCard(
                      label: 'Total Loans',
                      value: '${summary['total_loans'] ?? 0}',
                      icon: Icons.swap_horiz_rounded,
                      accent: AppColors.cyan,
                    ),
                  ),
                  SizedBox(
                    width: 210,
                    height: 145,
                    child: MetricCard(
                      label: 'Overdue',
                      value: '${summary['overdue'] ?? 0}',
                      icon: Icons.warning_amber_rounded,
                      accent: AppColors.red,
                    ),
                  ),
                  SizedBox(
                    width: 245,
                    height: 145,
                    child: MetricCard(
                      label: 'Unpaid Fines',
                      value: 'LKR ${formatMoney(summary['unpaid_fines'])}',
                      icon: Icons.payments_outlined,
                      accent: AppColors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final two = constraints.maxWidth > 900;
                  final trend = _ReportPanel(
                    title: 'Monthly loan trend',
                    child: SizedBox(
                      height: 270,
                      child: monthly.isEmpty
                          ? const Center(
                              child: Text('No loan data in selected range'),
                            )
                          : LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: true),
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      getTitlesWidget: (value, meta) {
                                        final i = value.toInt();
                                        if (i < 0 || i >= monthly.length) {
                                          return const SizedBox.shrink();
                                        }
                                        final label = monthly[i]['month']
                                            .toString();
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Text(
                                            label.length >= 7
                                                ? label.substring(5)
                                                : label,
                                            style: const TextStyle(fontSize: 9),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: List.generate(
                                      monthly.length,
                                      (i) => FlSpot(
                                        i.toDouble(),
                                        toDouble(monthly[i]['loans']),
                                      ),
                                    ),
                                    isCurved: true,
                                    color: AppColors.primary,
                                    barWidth: 3,
                                    dotData: const FlDotData(show: true),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: AppColors.primary.withOpacity(.10),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  );

                  final finePanel = _ReportPanel(
                    title: 'Fine collection',
                    child: SizedBox(
                      height: 270,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'LKR ${formatMoney(fines['total_assessed'])}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'Assessed',
                            style: TextStyle(color: AppColors.muted),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _MiniReportStat(
                                label: 'Paid',
                                value:
                                    'LKR ${formatMoney(fines['total_paid'])}',
                                color: AppColors.mint,
                              ),
                              _MiniReportStat(
                                label: 'Unpaid',
                                value:
                                    'LKR ${formatMoney(fines['total_unpaid'])}',
                                color: AppColors.red,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );

                  return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    trend,
                    const SizedBox(height: 14),
                    finePanel,
                  ],
                );
                },
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final two = constraints.maxWidth > 900;
                  final popularPanel = _ReportPanel(
                    title: 'Popular books',
                    child: Column(
                      children: popular.isEmpty
                          ? [
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('No data'),
                              ),
                            ]
                          : popular
                                .map(
                                  (b) => ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.trending_up_rounded,
                                      color: AppColors.primary,
                                    ),
                                    title: Text(b['title']?.toString() ?? ''),
                                    subtitle: Text(
                                      b['author']?.toString() ?? '',
                                    ),
                                    trailing: Text(
                                      '${b['borrow_count']} borrows',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                    ),
                  );
                  final membersPanel = _ReportPanel(
                    title: 'Most active members',
                    child: Column(
                      children: activeMembers.isEmpty
                          ? [
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text('No data'),
                              ),
                            ]
                          : activeMembers
                                .map(
                                  (m) => ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      radius: 16,
                                      child: Text(
                                        (m['name']?.toString().isNotEmpty ??
                                                false)
                                            ? m['name'].toString()[0]
                                            : '?',
                                      ),
                                    ),
                                    title: Text(m['name']?.toString() ?? ''),
                                    subtitle: Text(
                                      m['member_code']?.toString() ?? '',
                                    ),
                                    trailing: Text(
                                      '${m['loan_count']} loans',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                    ),
                  );
                  return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    popularPanel,
                    const SizedBox(height: 14),
                    membersPanel,
                  ],
                );
                },
              ),
              const SizedBox(height: 18),
              _ReportPanel(
                title: 'Category popularity',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: categories
                      .map(
                        (x) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryFaint,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Text(
                            '${x['category']}  -  ${x['borrow_count']} borrows',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _ReportPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _MiniReportStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniReportStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 10),
        ),
      ],
    );
  }
}

// ============================================================
// USERS - ADMIN ONLY
// ============================================================

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  bool loading = true;

  List<dynamic> users = [];

  List<dynamic> registrationRequests = [];

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    load();

    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final userData = await ApiService.get('/users');

      final requestData = await ApiService.get('/registration-requests');

      final allRequests = List<dynamic>.from(requestData ?? []);

      final pending = allRequests.where((raw) {
        if (raw is! Map) {
          return false;
        }

        return (raw['status']?.toString() ?? '').trim().toLowerCase() ==
            'pending';
      }).toList();

      if (!mounted) return;

      setState(() {
        users = List<dynamic>.from(userData ?? []);

        registrationRequests = pending;

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      if (!silent) {
        showAppMessage(context, e);
      }

      setState(() {
        loading = false;
      });
    }
  }

  Future<void> approveRegistration(Map<String, dynamic> request) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Approve registration?'),
        content: Text(
          '${request['name'] ?? ''}\n${request['email'] ?? ''}\n\n'
          'This will create an active Member record and Member login account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Approve'),
          ),
        ],
      ),
    );
    if (approved != true) return;

    try {
      final data = await ApiService.post(
        '/registration-requests/${request['id']}/approve',
      );
      if (!mounted) return;
      showAppMessage(
        context,
        data is Map && data['message'] != null
            ? data['message'].toString()
            : 'Registration approved',
      );
      await load();
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  Future<void> rejectRegistration(Map<String, dynamic> request) async {
    final reason = TextEditingController();
    final rejected = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject registration?'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${request['name'] ?? ''}  -  ${request['email'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reason,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'Enter a short reason for rejection',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Reject'),
          ),
        ],
      ),
    );

    if (rejected != true) {
      reason.dispose();
      return;
    }

    try {
      final data = await ApiService.post(
        '/registration-requests/${request['id']}/reject',
        {'reason': reason.text.trim()},
      );
      if (!mounted) return;
      showAppMessage(
        context,
        data is Map && data['message'] != null
            ? data['message'].toString()
            : 'Registration rejected',
      );
      await load();
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    } finally {
      reason.dispose();
    }
  }

  Future<void> userDialog({Map<String, dynamic>? user}) async {
    final name = TextEditingController(text: user?['name']?.toString() ?? '');
    final email = TextEditingController(text: user?['email']?.toString() ?? '');
    final password = TextEditingController();
    String role = user?['role']?.toString() ?? 'Librarian';
    int? memberId = toInt(user?['member_id']);
    if (memberId == 0) memberId = null;

    List<dynamic> members = [];
    try {
      members = List<dynamic>.from(
        await ApiService.get('/members?status=Active'),
      );
    } catch (_) {}

    if (!mounted) return;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(user == null ? 'Create User' : 'Edit User'),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: email,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: user == null
                              ? 'Password'
                              : 'New Password (leave blank to keep current)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: const [
                          DropdownMenuItem(
                            value: 'Admin',
                            child: Text('Admin'),
                          ),
                          DropdownMenuItem(
                            value: 'Librarian',
                            child: Text('Librarian'),
                          ),
                          DropdownMenuItem(
                            value: 'Member',
                            child: Text('Member'),
                          ),
                        ],
                        onChanged: (value) {
                          setLocal(() => role = value ?? 'Librarian');
                        },
                      ),
                      if (role == 'Member') ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: memberId,
                          isExpanded: true,
                          menuMaxHeight: 350,
                          decoration: const InputDecoration(
                            labelText: 'Linked Member',
                          ),
                          items: members
                              .map<DropdownMenuItem<int>>(
                                (m) => DropdownMenuItem<int>(
                                  value: toInt(m['id']),
                                  child: Text(
                                    '${m['member_code']} - ${m['name']}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setLocal(() => memberId = value);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (save != true) return;

    try {
      final body = <String, dynamic>{
        'name': name.text.trim(),
        'email': email.text.trim(),
        'role': role,
        'memberId': memberId,
        if (password.text.isNotEmpty) 'password': password.text,
      };

      if (user == null) {
        if (password.text.length < 6) {
          throw Exception('Password must be at least 6 characters');
        }
        await ApiService.post('/users', body);
      } else {
        await ApiService.put('/users/${user['id']}', body);
      }

      if (!mounted) return;
      showAppMessage(context, 'User saved');
      await load();
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  Future<void> deleteUser(Map<String, dynamic> user) async {
    try {
      await ApiService.delete('/users/${user['id']}');
      if (!mounted) return;
      showAppMessage(context, 'User deleted');
      await load();
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admins = users.where((u) => u['role'] == 'Admin').length;
    final librarians = users.where((u) => u['role'] == 'Librarian').length;
    final members = users.where((u) => u['role'] == 'Member').length;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: RefreshIndicator(
        onRefresh: load,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const LibrarySceneBanner(
              imagePath: 'assets/images/library_login_main.png',
              eyebrow: 'Access workspace',
              title: 'Manage roles and user access',
              subtitle: 'Control administrator, librarian and member access from one secure workspace.',
              icon: Icons.admin_panel_settings_rounded,
              height: 180,
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 980
                    ? 4
                    : constraints.maxWidth >= 560
                    ? 2
                    : 1;
                const gap = 12.0;
                final tileWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: tileWidth,
                      child: PageStatTile(
                        label: 'All users',
                        value: '${users.length}',
                        note: 'Registered accounts',
                        icon: Icons.people_alt_outlined,
                        accent: AppColors.primary,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: PageStatTile(
                        label: 'Admins',
                        value: '$admins',
                        note: 'Full system access',
                        icon: Icons.admin_panel_settings_outlined,
                        accent: AppColors.red,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: PageStatTile(
                        label: 'Librarians',
                        value: '$librarians',
                        note: 'Operational access',
                        icon: Icons.local_library_outlined,
                        accent: AppColors.blue,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: PageStatTile(
                        label: 'Members',
                        value: '$members',
                        note: 'Member accounts',
                        icon: Icons.badge_outlined,
                        accent: AppColors.mint,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: PageStatTile(
                        label: 'Pending',
                        value: '${registrationRequests.length}',
                        note: 'Awaiting approval',
                        icon: Icons.how_to_reg_outlined,
                        accent: AppColors.amber,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Pending member registrations',
              subtitle:
                  'Review public membership requests before access is granted',
              action: IconButton(
                tooltip: 'Refresh requests',
                onPressed: load,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            const SizedBox(height: 14),
            if (loading)
              const SizedBox.shrink()
            else if (registrationRequests.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4FCF8),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: const Color(0xFFD8F3E8)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_outlined, color: AppColors.mint),
                    SizedBox(width: 11),
                    Text(
                      'No pending registration requests',
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 980;
                  final cardWidth = twoColumns
                      ? (constraints.maxWidth - 12) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: registrationRequests.map((raw) {
                      final request = Map<String, dynamic>.from(raw as Map);
                      return SizedBox(
                        width: cardWidth,
                        child: HoverCard(
                          child: Padding(
                            padding: const EdgeInsets.all(17),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppColors.primarySoft,
                                      child: const Icon(
                                        Icons.person_add_alt_1_rounded,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            request['name']?.toString() ?? '',
                                            style: const TextStyle(
                                              color: AppColors.ink,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            request['email']?.toString() ?? '',
                                            style: const TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 10.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const StatusBadge(status: 'Pending'),
                                  ],
                                ),
                                const SizedBox(height: 13),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 6,
                                  children: [
                                    Text(
                                      'Phone: ${request['phone'] ?? '-'}',
                                      style: const TextStyle(
                                        color: AppColors.text,
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      'Address: ${request['address']?.toString().trim().isNotEmpty == true ? request['address'] : '-'}',
                                      style: const TextStyle(
                                        color: AppColors.text,
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      'Requested: ${formatDate(request['requested_at'])}',
                                      style: const TextStyle(
                                        color: AppColors.text,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: () =>
                                            approveRegistration(request),
                                        icon: const Icon(
                                          Icons.check_rounded,
                                          size: 17,
                                        ),
                                        label: const Text('Approve'),
                                      ),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            rejectRegistration(request),
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          size: 17,
                                        ),
                                        label: const Text('Reject'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.red,
                                          side: const BorderSide(
                                            color: Color(0xFFFFD5D9),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 15,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            const SizedBox(height: 26),
            SectionHeader(
              title: 'Role & access management',
              subtitle: 'Admin, Librarian and Member accounts with least-privilege navigation',
              action: FilledButton.icon(
                onPressed: () => userDialog(),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add User'),
              ),
            ),
            const SizedBox(height: 16),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else
              ...users.map(
                (u) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HoverCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primarySoft,
                            child: Icon(
                              u['role'] == 'Admin'
                                  ? Icons.admin_panel_settings
                                  : u['role'] == 'Member'
                                  ? Icons.badge_outlined
                                  : Icons.local_library_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  u['name']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  u['email']?.toString() ?? '',
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                                if (u['member_code'] != null)
                                  Text(
                                    'Linked: ${u['member_code']} - ${u['member_name']}',
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          StatusBadge(status: u['role']?.toString() ?? ''),
                          IconButton(
                            tooltip: 'Edit',
                            onPressed: () =>
                                userDialog(user: Map<String, dynamic>.from(u)),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            onPressed: () =>
                                deleteUser(Map<String, dynamic>.from(u)),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// AUDIT
// ============================================================

class AuditPage extends StatefulWidget {
  const AuditPage({super.key});

  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  bool loading = true;
  List<dynamic> logs = [];
  final search = TextEditingController();
  String action = '';
  DateTime? from;
  DateTime? to;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  String date(DateTime d) => d.toIso8601String().substring(0, 10);

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final query = Uri(
        queryParameters: {
          if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
          if (action.isNotEmpty) 'action': action,
          if (from != null) 'from': date(from!),
          if (to != null) 'to': date(to!),
        },
      ).query;
      final data = await ApiService.get('/audit?$query');
      if (!mounted) return;
      setState(() => logs = List<dynamic>.from(data));
    } catch (e) {
      if (mounted) showAppMessage(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions =
        logs
            .map((x) => x['action']?.toString() ?? '')
            .where((x) => x.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final actors = logs
        .map(
          (x) =>
              x['user_email']?.toString() ??
              x['user_name']?.toString() ??
              'System',
        )
        .where((x) => x.isNotEmpty)
        .toSet()
        .length;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: RefreshIndicator(
        onRefresh: load,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const LibrarySceneBanner(
              imagePath: 'assets/images/library_shelves.png',
              eyebrow: 'Audit workspace',
              title: 'Trace every important system action',
              subtitle: 'Review security-sensitive changes, user activity and entity updates with a clear audit trail.',
              icon: Icons.history_rounded,
              height: 180,
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 760 ? 3 : 1;
                const gap = 12.0;
                final tileWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: tileWidth,
                      child: PageStatTile(
                        label: 'Visible events',
                        value: '${logs.length}',
                        note: 'Current filtered result',
                        icon: Icons.receipt_long_outlined,
                        accent: AppColors.primary,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: PageStatTile(
                        label: 'Action types',
                        value: '${actions.length}',
                        note: 'Distinct activities',
                        icon: Icons.category_outlined,
                        accent: AppColors.blue,
                      ),
                    ),
                    SizedBox(
                      width: tileWidth,
                      child: PageStatTile(
                        label: 'Actors',
                        value: '$actors',
                        note: 'Users represented',
                        icon: Icons.manage_accounts_outlined,
                        accent: AppColors.mint,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            SectionHeader(
              title: 'Audit trail',
              subtitle:
                  'Search administrative activity by user, action and date',
              action: IconButton(
                onPressed: load,
                icon: const Icon(Icons.refresh),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: search,
                    onSubmitted: (_) => load(),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search user, action, entity...',
                    ),
                  ),
                ),
                SizedBox(
                  width: 240,

                  child: DropdownButtonFormField<String>(
                    value: actions.contains(action) ? action : '',

                    isExpanded: true,

                    decoration: const InputDecoration(labelText: 'Action'),

                    items: [
                      const DropdownMenuItem(
                        value: '',

                        child: Text(
                          'All actions',
                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      ...actions.map(
                        (x) => DropdownMenuItem<String>(
                          value: x,

                          child: Text(
                            x,
                            maxLines: 1,

                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],

                    onChanged: (value) {
                      setState(() {
                        action = value ?? '';
                      });

                      load();
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          from ??
                          DateTime.now().subtract(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => from = picked);
                      load();
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(from == null ? 'From' : date(from!)),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: to ?? DateTime.now(),
                      firstDate: from ?? DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => to = picked);
                      load();
                    }
                  },
                  icon: const Icon(Icons.event),
                  label: Text(to == null ? 'To' : date(to!)),
                ),
                FilledButton.icon(
                  onPressed: load,
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: const Text('Apply'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 100),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (logs.isEmpty)
              const EmptyState(
                icon: Icons.history,
                title: 'No matching activity',
                subtitle: 'Audit events will appear here.',
              )
            else
              ...logs.map(
                (log) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: HoverCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.history_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log['action']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${log['user_name'] ?? 'System'}  -  ${log['user_email'] ?? ''}  -  ${log['entity_type'] ?? '-'} #${log['entity_id'] ?? '-'}',
                                  style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 10.5,
                                  ),
                                ),
                                if (log['details'] != null)
                                  Text(
                                    log['details'].toString(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 9.5,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            formatDate(log['created_at']),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PROFILE
// ============================================================

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool loading = true;

  final name = TextEditingController();

  final email = TextEditingController();

  final currentPassword = TextEditingController();

  final newPassword = TextEditingController();

  String role = '';

  @override
  void initState() {
    super.initState();

    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
    });

    try {
      final data = await ApiService.get('/profile');

      if (!mounted) return;

      name.text = data['name']?.toString() ?? '';

      email.text = data['email']?.toString() ?? '';

      role = data['role']?.toString() ?? '';

      setState(() {});
    } catch (e) {
      if (mounted) {
        showAppMessage(context, e);
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> saveProfile() async {
    try {
      final result = await ApiService.put('/profile', {
        'name': name.text.trim(),
        'email': email.text.trim(),
      });

      final user = result['user'] ?? result;

      ApiService.userName = user['name']?.toString();

      ApiService.email = user['email']?.toString();

      await ApiService.saveSession();

      if (!mounted) return;

      showAppMessage(context, 'Profile updated successfully');

      setState(() {});
    } catch (e) {
      if (mounted) {
        showAppMessage(context, e);
      }
    }
  }

  Future<void> changePassword() async {
    if (currentPassword.text.isEmpty || newPassword.text.isEmpty) {
      showAppMessage(context, 'Enter both passwords');

      return;
    }

    try {
      await ApiService.put('/profile/password', {
        'currentPassword': currentPassword.text,
        'newPassword': newPassword.text,
      });

      currentPassword.clear();
      newPassword.clear();

      if (!mounted) return;

      showAppMessage(context, 'Password changed successfully');
    } catch (e) {
      if (mounted) {
        showAppMessage(context, e);
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    currentPassword.dispose();
    newPassword.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const LibrarySceneBanner(
          imagePath: 'assets/images/library_shelves.png',
          eyebrow: 'Account & security',
          title: 'Your library identity',
          subtitle:
              'Keep your profile details and account security up to date.',
          icon: Icons.person_outline_rounded,
          height: 155,
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final cardWidth = wide
                ? (constraints.maxWidth - 16) / 2
                : constraints.maxWidth;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: HoverCard(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Personal information',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            (ApiService.role ?? '').toLowerCase() == 'member'
                                ? 'Keep your member account details up to date.'
                                : 'Keep your staff profile details up to date.',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            controller: name,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: email,
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: saveProfile,
                              icon: const Icon(Icons.save_outlined, size: 17),
                              label: const Text('Save Changes'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: HoverCard(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Security',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Update your password regularly to protect your account.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 22),
                          TextField(
                            controller: currentPassword,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Current password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: newPassword,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'New password',
                              prefixIcon: Icon(Icons.password_outlined),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: changePassword,
                              icon: const Icon(Icons.shield_outlined, size: 17),
                              label: const Text('Update Password'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
