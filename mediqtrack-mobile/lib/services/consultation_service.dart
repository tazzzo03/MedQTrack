import 'package:supabase_flutter/supabase_flutter.dart';

class ConsultationService {
  ConsultationService._();
  static final ConsultationService instance = ConsultationService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<String> startConsultation({
    required int patientId,
    required int queueId,
    required int roomId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final result = await _client
        .from('consultation_logs')
        .insert({
          'patient_id': patientId,
          'queue_id': queueId,
          'room_id': roomId,
          'start_time': now,
        })
        .select('id')
        .single();
    return result['id'].toString();
  }

  Future<void> endConsultation(String consultationId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('consultation_logs')
        .update({'end_time': now})
        .eq('id', consultationId);
  }

  Future<double> fetchAverageMinutes() async {
  final data = await _client
      .from('average_consultation_today2')
      .select('average_minutes')
      .limit(1)
      .maybeSingle();

  return (data?['average_minutes'] as num?)?.toDouble() ?? 0;
}


  Future<double> fetchAverageCombinedMinutes() async {
    final data = await _client
        .from('average_consultation_combined')
        .select('average_minutes')
        .limit(1)
        .maybeSingle();
    return (data?['average_minutes'] as num?)?.toDouble() ?? 0;
  }
}
