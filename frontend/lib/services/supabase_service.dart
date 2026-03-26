import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report_model.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  String? get currentUserId => currentUser?.id;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<String?> fetchDisplayName() async {
    try {
      final userId = currentUserId;
      print('[Supabase] fetchDisplayName → userId=$userId');
      if (userId == null) {
        print('[Supabase] fetchDisplayName → aborted, no user');
        return null;
      }

      final res = await _client
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      print('[Supabase] fetchDisplayName → result=$res');
      return res?['full_name'] as String?;
    } catch (e) {
      print('[Supabase] fetchDisplayName ERROR → $e');
      return null;
    }
  }

  Future<String?> uploadImage(File imageFile, String fileName) async {
    try {
      print('[Supabase] uploadImage → fileName=$fileName');
      final bytes = await imageFile.readAsBytes();
      print('[Supabase] uploadImage → bytes=${bytes.length}');

      await _client.storage
          .from('test_storage')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final publicUrl = _client.storage
          .from('test_storage')
          .getPublicUrl(fileName);
      print('[Supabase] uploadImage → publicUrl=$publicUrl');
      return publicUrl;
    } catch (e) {
      print('[Supabase] uploadImage ERROR → $e');
      throw Exception('Upload failed: $e');
    }
  }

  Future<void> submitReport({
    required String image_link,
    required double lat,
    required double long,
    required int intensity,
    required String name,
  }) async {
    print(
      '[Supabase] submitReport → lat=$lat, long=$long, intensity=$intensity, name=$name, user_id=$currentUserId',
    );
    try {
      await _client.from('report_submission').insert({
        'image_link': image_link,
        'lat': lat,
        'long': long,
        'intensity': intensity,
        'name': name,
        'user_id': currentUserId,
      });
      print('[Supabase] submitReport → success');
    } catch (e) {
      print('[Supabase] submitReport ERROR → $e');
      rethrow;
    }
  }

  Future<List<ReportModel>> fetchAllReports() async {
    print('[Supabase] fetchAllReports → called');
    try {
      final res = await _client
          .from('report_submission')
          .select('*, profiles(full_name)')
          .order('created_at', ascending: false);

      print('[Supabase] fetchAllReports → ${(res as List).length} rows');
      return res.map((json) => ReportModel.fromJson(json)).toList();
    } catch (e) {
      print('[Supabase] fetchAllReports ERROR → $e');
      return [];
    }
  }

  Future<List<ReportModel>> fetchMyReports() async {
    final userId = currentUserId;
    print('[Supabase] fetchMyReports → userId=$userId');
    if (userId == null) {
      print('[Supabase] fetchMyReports → aborted, no user');
      return [];
    }

    try {
      final res = await _client
          .from('report_submission')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      print('[Supabase] fetchMyReports → ${(res as List).length} rows');
      return res.map((json) => ReportModel.fromJson(json)).toList();
    } catch (e) {
      print('[Supabase] fetchMyReports ERROR → $e');
      return [];
    }
  }

  Future<Map<String, int>> fetchStats() async {
    print('[Supabase] fetchStats → called');
    try {
      final userId = currentUserId;
      if (userId == null) {
        print('[Supabase] fetchStats → aborted, no user');
        return {};
      }

      final res = await _client
          .from('report_submission')
          .select('status')
          .eq('user_id', userId);

      final list = res as List;
      print(
        '[Supabase] fetchStats → ${list.length} rows, statuses=${list.map((r) => r['status']).toList()}',
      );

      int success = 0, pending = 0, failed = 0;
      for (final r in list) {
        switch ((r['status'] as String?)?.toLowerCase()) {
          case 'success':
            success++;
            break;
          case 'pending':
            pending++;
            break;
          case 'failed':
            failed++;
            break;
          default:
            print('[Supabase] fetchStats → unknown status: ${r['status']}');
        }
      }

      final stats = {
        'total': list.length,
        'success': success,
        'pending': pending,
        'failed': failed,
      };
      print('[Supabase] fetchStats → $stats');
      return stats;
    } catch (e) {
      print('[Supabase] fetchStats ERROR → $e');
      return {};
    }
  }
}
