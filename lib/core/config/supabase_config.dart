/// Konfigurasi Supabase
/// Untuk menggunakan Supabase REST API
class SupabaseConfig {
  SupabaseConfig._(); // Private constructor untuk mencegah instantiasi

  // Supabase configuration
  // Dapatkan dari: https://app.supabase.com -> Project Settings -> API
  static const String supabaseUrl = 'https://ksizwnhqotjwcaapxoeq.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzaXp3bmhxb3Rqd2NhYXB4b2VxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE4NzMyODQsImV4cCI6MjA3NzQ0OTI4NH0.k9aLRot8vN8oA62VAkYpA_lgss2rO0O6LL7Q9CnTdMY'; // Anon/Public Key

  // Storage bucket name - GANTI dengan nama bucket yang ada di Supabase Storage Anda
  // Default: 'files'
  // Untuk melihat nama bucket: Supabase Dashboard -> Storage -> Buckets
  static const String storageBucketName = 'files';

  // Endpoints untuk REST API
  static String get todosUrl => '$supabaseUrl/rest/v1/todos';
  static String get notesUrl => '$supabaseUrl/rest/v1/notes';
  static String get archivesUrl => '$supabaseUrl/rest/v1/archives';
}
