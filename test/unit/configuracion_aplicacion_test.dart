import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_final_360/config/configuracion_aplicacion.dart';

void main() {
  test('AppConfig solo habilita Supabase con URL y clave pública', () {
    expect(const AppConfig(supabaseUrl: '', supabaseKey: '').hasSupabaseConfig, isFalse);
    expect(const AppConfig(supabaseUrl: 'https://example.supabase.co', supabaseKey: '').hasSupabaseConfig, isFalse);
    expect(const AppConfig(supabaseUrl: ' https://example.supabase.co ', supabaseKey: ' public ').hasSupabaseConfig, isTrue);
  });
}
