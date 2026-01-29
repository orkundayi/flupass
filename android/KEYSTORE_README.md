# 🔐 Keystore Bilgileri

Bu dosya keystore şifrelerinizi saklamak içindir. **GİZLİ TUTUN!**

## Keystore Dosyası
- **Dosya Yolu:** `android/app/upload-keystore.jks`
- **Alias:** `upload`

## Şifreler
⚠️ **BURAYA ŞİFRELERİNİZİ YAZIN ve bu dosyayı güvenli bir yerde saklayın!**

```
Store Password: [Keystore oluştururken girdiğiniz şifre]
Key Password: [Keystore oluştururken girdiğiniz şifre]
```

## key.properties Dosyası Oluşturma
Projeyi yeni bir bilgisayara klonladığınızda:

1. `android/key.properties` dosyası oluşturun
2. Aşağıdaki içeriği ekleyin:

```properties
storePassword=[STORE_PASSWORD_BURAYA]
keyPassword=[KEY_PASSWORD_BURAYA]
keyAlias=upload
storeFile=app/upload-keystore.jks
```

## Google Play Console
- **Package Name:** com.flutech.flupass
- **Keystore SHA-256:** (Google Play Console'da görebilirsiniz)

## Önemli Notlar
- ✅ `upload-keystore.jks` dosyası GitHub'a commit edilir
- ❌ `key.properties` dosyası .gitignore'da, commit edilmez
- 📝 Bu README'yi güvenli bir yerde (şifre yöneticisi gibi) saklayın
- 🔄 Keystore dosyasını asla değiştirmeyin (güncelleyemezsiniz!)
