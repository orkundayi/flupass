# FluPass Local Database Migration Guide

Bu belge, yerel Sqflite veritabanı altyapımızın nasıl çalıştığını ve üretim ortamında güvenli schema güncellemeleri yaparken izlemeniz gereken adımları detaylı şekilde özetler.

## Mimari Genel Bakış
- **Giriş Noktası:** `AppDatabase.instance` veritabanı bağlantısını yönetir. Bağlantı açıldığında `DatabaseInitializer` tüm tablo şemalarını sırayla çalıştırır.
- **Şema Tanımı:** Her tablo kendi klasöründe (`lib/services/database/<kategori>`) bir `TableSchema` sınıfı ile temsil edilir. Bu sınıflar `tableName` ve `List<MigrationStep>` tanımlar.
- **Sürüm Takibi:** `SchemaVersionStore` tablo başına sürümü `_schema_versions` tablosunda saklar. Bu nedenle global veritabanı versiyonuna ihtiyaç kalmaz.
- **MigrationStep:** Her adım hedeflediği versiyonu (`version`) ve çalıştıracağı fonksiyonu (`runner`) içerir. Migration çalıştığında tablo sürümü bu hedefe güncellenir.
- **İşlem Güvenliği:** `DatabaseInitializer` her tablo migration’ını tek bir `transaction` içinde yürütür; adımlardan biri başarısız olursa rollback gerçekleşir.

## Migration Hazırlık Kontrol Listesi
1. Şema değişikliğinin hangi tabloyu etkilediğini netleştir.
2. Gerekirse ürün gereksinimleri eşliğinde veri taşıma stratejisini belirle (ör. eski veriler dönüşecek mi?).
3. `MigrationStep` numarasını seçerken sıradaki tamsayıyı kullan (ör. mevcut son versiyon 2 ise yeni adım 3 olur).
4. Model, repository ve UI katmanlarında yapılması gereken değişiklikleri listele.
5. Test planını yaz (manuel, birim ve regression testleri).

## Yaygın Senaryolar

### 1. Kolon Ekleme (Varsayılan Değer ile)
```dart
// lib/services/database/credentials/credential_schema.dart
List<MigrationStep> get migrations => const [
  MigrationStep(1, _createV1),
  MigrationStep(2, _addSecurityLevel),
];

static Future<void> _addSecurityLevel(DatabaseExecutor db) async {
  await db.execute(
    'ALTER TABLE credentials ADD COLUMN security_level INTEGER NOT NULL DEFAULT 0',
  );
}
```

> Notlar
- `NOT NULL` yeni değerler için default gerektirir. Eski kayıtlar default ile güncellenir.
- Model (`Credential`) ve repository kodunda `securityLevel` alanını ekle.
- UI’da alan gösterilecekse formları/ekranları güncelle.

### 2. Kolon Adı Değiştirme (Yeniden Oluşturma + Veri Taşıma)
Sqflite `ALTER TABLE ... RENAME COLUMN` desteklemez. Bu yüzden geçici tablo üzerinden taşıma yapılır.

```dart
MigrationStep(2, _renameTitleToLabel),

static Future<void> _renameTitleToLabel(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE credentials_tmp (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      label TEXT NOT NULL,
      username TEXT NOT NULL,
      password TEXT NOT NULL,
      website TEXT,
      notes TEXT,
      tags TEXT,
      is_favorite INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');

  await db.execute('''
    INSERT INTO credentials_tmp (
      id, label, username, password, website, notes, tags,
      is_favorite, created_at, updated_at
    )
    SELECT
      id, title, username, password, website, notes, tags,
      is_favorite, created_at, updated_at
    FROM credentials
  ''');

  await db.execute('DROP TABLE credentials');
  await db.execute('ALTER TABLE credentials_tmp RENAME TO credentials');
}
```

> Notlar
- Model/repository’de `title` yerine `label` kullan.
- UI katmanını da yeni alan ismine göre düzenle.
- Taşıma sırasında veri dönüşümü gerekiyorsa `SELECT` kısmına SQL fonksiyonları ekleyebilirsin.

### 3. Kolon Silme
Sqflite doğrudan kolon silmeyi desteklemez. Aynı kolon adı değiştirmede olduğu gibi yeni tablo oluşturup sadece gerekli alanları taşırsın.

```dart
MigrationStep(3, _dropDeprecatedColumn),

static Future<void> _dropDeprecatedColumn(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE credentials_tmp AS
    SELECT id, title, username, password, website, notes, tags,
           is_favorite, created_at, updated_at
    FROM credentials
  ''');

  await db.execute('DROP TABLE credentials');
  await db.execute('ALTER TABLE credentials_tmp RENAME TO credentials');
}
```

### 4. Kolon Bölmek (Composite Veriyi Çözmek)
Örneğin tek `name` kolonunu `first_name` ve `last_name` olarak ayırmak:

```dart
MigrationStep(4, _splitNameColumn),

static Future<void> _splitNameColumn(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE credentials_tmp (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      first_name TEXT,
      last_name TEXT,
      username TEXT NOT NULL,
      password TEXT NOT NULL,
      website TEXT,
      notes TEXT,
      tags TEXT,
      is_favorite INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');

  await db.execute('''
    INSERT INTO credentials_tmp (
      id, first_name, last_name, username, password, website,
      notes, tags, is_favorite, created_at, updated_at
    )
    SELECT
      id,
      substr(title, 1, instr(title, ' ') - 1) AS first_name,
      substr(title, instr(title, ' ') + 1) AS last_name,
      username, password, website,
      notes, tags, is_favorite, created_at, updated_at
    FROM credentials
  ''');

  await db.execute('DROP TABLE credentials');
  await db.execute('ALTER TABLE credentials_tmp RENAME TO credentials');
}
```

> Notlar
- Buradaki string fonksiyonları SQLite’a özeldir; farklı kurallara göre ayırmak için SQL’i uyarlayın.

### 5. Veri Arkadan Doldurma (Backfill)
Yeni kolon, mevcut verilerden türetilmiş değeri tutacaksa hem kolon ekleyip hem de güncelleme yapmak gerekir.

```dart
MigrationStep(5, _addStrengthScore),

static Future<void> _addStrengthScore(DatabaseExecutor db) async {
  await db.execute(
    'ALTER TABLE credentials ADD COLUMN strength_score INTEGER NOT NULL DEFAULT 0',
  );

  // Basit örnek: şifre uzunluğuna göre skor.
  final rows = await db.query('credentials', columns: ['id', 'password']);
  for (final row in rows) {
    final id = row['id'] as int;
    final password = row['password'] as String? ?? '';
    final score = password.length.clamp(0, 10);

    await db.update(
      'credentials',
      {'strength_score': score},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
```

> Notlar
- Döngü içerisinde `update` kullanmak yavaş olabilir; çok büyük tablolar için SQL fonksiyonlarıyla tek seferde güncelleme veya batch transaction tercih edin.

### 6. Index Eklemek
```dart
MigrationStep(6, _addUsernameIndex),

static Future<void> _addUsernameIndex(DatabaseExecutor db) async {
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_credentials_username ON credentials(username)',
  );
}
```

> Notlar
- Index adında tablo ismini içermek isim çakışmalarını önler.
- Index eklediğiniz alan için repository sorgularında da bu alanı kullandığınızdan emin olun.

### 7. Unique Constraint Uygulamak
```dart
MigrationStep(7, _enforceUniqueTitle),

static Future<void> _enforceUniqueTitle(DatabaseExecutor db) async {
  // Kopya oluşturarak constraint ekleme
  await db.execute('''
    CREATE TABLE credentials_tmp (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL UNIQUE,
      username TEXT NOT NULL,
      password TEXT NOT NULL,
      website TEXT,
      notes TEXT,
      tags TEXT,
      is_favorite INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');

  // Çakışmaları çözmek için DISTINCT veya özel SELECT kullanın
  await db.execute('''
    INSERT INTO credentials_tmp
    SELECT * FROM credentials
    GROUP BY title
  ''');

  await db.execute('DROP TABLE credentials');
  await db.execute('ALTER TABLE credentials_tmp RENAME TO credentials');
}
```

> Notlar
- Constraint eklemeden önce veri çakışmalarını temizlemek için SELECT ifadesini uyarlayın (ör. `MAX(updated_at)` ile en yeni kaydı seçmek gibi).

### 8. Tabloyu Parçalara Ayırmak (Normalization)
Örneğin `credentials` tablosundaki kart verilerini ayrı bir tabloya taşımak:

```dart
MigrationStep(8, _splitCardsTable),

static Future<void> _splitCardsTable(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS credit_cards (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      credential_id INTEGER NOT NULL,
      card_holder_name TEXT NOT NULL,
      card_number TEXT NOT NULL,
      expiry_date TEXT NOT NULL,
      FOREIGN KEY (credential_id) REFERENCES credentials(id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    INSERT INTO credit_cards (credential_id, card_holder_name, card_number, expiry_date)
    SELECT id, title, notes, tags
    FROM credentials
    WHERE tags LIKE 'CARD:%'
  ''');

  await db.execute('''
    UPDATE credentials
    SET notes = NULL,
        tags = NULL
    WHERE tags LIKE 'CARD:%'
  ''');
}
```

> Notlar
- Yeni tablo için ayrı bir `TableSchema` türevi oluşturup `DatabaseInitializer` listesine eklemeyi unutmayın.
- Foreign key ilişkisi için `PRAGMA foreign_keys = ON` çağrısı kritik (initializer zaten yapıyor).

## Yeni Tablo Ekleme Adımları
1. `lib/services/database/<kategori>/<isim>_schema.dart` dosyasını oluştur ve `TableSchema` implementasyonu yaz.
2. Migration listesini oluştur: en az `MigrationStep(1, _createV1)` bulunmalı.
3. `AppDatabase` içindeki `DatabaseInitializer` listesine yeni şemayı ekle.
4. Model, repository ve UI katmanında yeni tabloya karşılık gelen kodu yaz.
5. Gerekirse provider/repository testleri oluştur.

## Test Stratejileri
- **Manuel:** Geliştirici cihazında/simülatörde uygulamayı açıp kritik ekranları gez; verilerin beklendiği gibi gözüktüğünü doğrula.
- **Birim Testi:** `sqflite_common_ffi` ile in-memory veritabanı açıp `DatabaseInitializer`’ı tetikleyerek migration adımlarının beklendiği gibi çalıştığını test edebilirsin.
    ```dart
    test('Credential schema adds security level', () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      final initializer = DatabaseInitializer(const [CredentialSchema()]);
      await initializer.initialize(db);

      final columns = await db.rawQuery(
        "PRAGMA table_info('credentials')",
      );
      expect(columns.any((c) => c['name'] == 'security_level'), isTrue);
    });
    ```
- **Regression:** Migration öncesi ve sonrası veri setleri oluşturarak UI testleri (golden test, integration test) çalıştır.

## Sorun Giderme
- Migration sırasında hata alırsan transaction rollback olur; loglar üzerinden hangi adımın patladığını kontrol et.
- Şema sürümü `_schema_versions` tablosunda yanlış görünüyorsa manuel olarak `DELETE FROM _schema_versions WHERE table_name = '...'` yapıp migration’ı tekrar çalıştırabilirsin (yalnız bu işlemi üretimde yapmadan önce kapsamlı test yap). 
- Migration yazarken `await` çağrılarını unutursan transaction tamamlanmadan sürüm güncellenebilir; tüm SQL komutlarının `await` ile beklendiğini doğrula.
- Büyük veri taşımalarda performans sıkıntısı yaşarsan `Batch` API’sini kullanmayı değerlendir.

## Sıkça Sorulanlar
- **Global veritabanı versiyonunu artırmalı mıyım?** Hayır. Her tablo kendi migration adımlarını bağımsız yönetiyor.
- **MigrationStep numaraları boşluk içerebilir mi?** Evet, ancak sıralama artan şekilde olmalı. Atlanan numara sorun yaratmaz fakat düzenli tutmak için ardışık gitmek önerilir.
- **Geri dönüş (downgrade) destekliyor muyuz?** Şu an hayır. Üretimde down-migration gereksinimi olursa manuel SQL scriptleri hazırlamak gerekir.
- **Migration sırasında başka işlemler veritabanına erişirse?** `DatabaseInitializer` açılışta çalıştığından, kullanıcı etkileşimi başlamadan migration tamamlanır; yine de uzun sürecek işlemler için kullanıcıyı bilgilendirmek gerekebilir.

---

Yeni senaryolar veya sorular için bu dosyayı genişletmekten çekinmeyin. Kod örneklerini doğrudan kopyalayabileceğiniz şekilde güncel tutmak, bakım maliyetini ciddi biçimde azaltır.
