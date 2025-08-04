class Config:
    # Veritabanı yapılandırması
    DATABASE_CONFIG = {
        'host': 'localhost',
        'user': 'ebr38crsayarcom',
        'password': 'your_password',  # Gerçek şifrenizi buraya yazın
        'database': 'ebr38crsayarcom_skincancer'
    }
    
    # API yapılandırması
    BASE_URL = 'https://ebranursayar.com'  # Ana domain adresiniz
    
    # Upload klasörü yapılandırması
    UPLOAD_FOLDER = "/home/ebr38crsayarcom/skin_diseases/uploads/ai_uploads"
    UPLOAD_URL_PATH = "/uploads/ai_uploads"  # nginx'in servis edeceği URL yolu 