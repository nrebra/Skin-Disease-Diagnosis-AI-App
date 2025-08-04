class Config {
  // Ana API URL'si
  static const String API_URL = 'https://ebranursayar.com.tr';

  // Yedek API URL'si
  static const String BACKUP_API_URL = 'http://ebranursayar.com.tr';

  // API Zaman Aşımı süresi
  static const int API_TIMEOUT_SECONDS = 30;

  // Yeniden Deneme Sayısı
  static const int MAX_RETRY_ATTEMPTS = 3;
}
