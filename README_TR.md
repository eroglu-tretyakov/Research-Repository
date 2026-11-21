# MATLAB Yeniden Üretilebilirlik Paketi

## Kullanım Kılavuzu ve Teknik Açıklama

### 1. Amaç ve kapsam

`run_Mathematics_R14_Manuscript.m`, **"Segmented Bezier Representation
of Solar Wind Speed and a Local Activity Index"** başlıklı çalışmanın
sayısal analizlerini, tablolarını ve şekillerini yeniden üretmek
amacıyla hazırlanmış, Excel dosyaları üzerinden çalışan tek dosyalı bir
MATLAB uygulamasıdır.

Program altı güneş rüzgârı hız serisini (Set N, Set A, Set M ve Set
1--3) ve dört 3 saatlik Kp çalışma kitabını (Set M ve Set 1--3)
kullanıcıdan seçmesini ister. Bézier eğri uydurma, klasik interpolasyon,
süreklilik, Yerel Aktivite İndeksi (Local Activity Index, LAI),
duyarlılık, bootstrap, pertürbasyon, adaptif segmentasyon, Gaussian
process (GP) ve Kp--LAI ilişki analizlerini yürütür.

**Kapsam sınırı:** Bu sürüm R14 makalesindeki altı veri setinin kayıt
sayılarına ve tarih eşlemelerine göre yapılandırılmıştır. Farklı
uzunlukta veya farklı tarih aralığında veri setleri için kod içindeki
beklenen kayıt sayıları ve gerekiyorsa başlangıç zamanı eşlemeleri
değiştirilmelidir. Kod, rastgele uzunluktaki serilere otomatik uyum
sağlayan genel amaçlı bir uygulama değildir.

### 2. Yazılım gereksinimleri

-   MATLAB R2020a veya üzeri.
-   Kaynak kodda özel bir MATLAB toolbox gereksinimi belirtilmemiştir;
    GP optimizasyonu için de kod içinde yazılmış BFGS yordamı
    kullanılır.
-   Harici Python, NumPy, SciPy veya üçüncü taraf MATLAB paketi
    çağrılmaz.
-   Girdiler `.xlsx` veya `.xls` Excel dosyaları olmalıdır.
-   Çıktı klasöründe dosya yazma izni bulunmalıdır.

**Dosya adı:** Ana MATLAB fonksiyonu `run_Mathematics_R14_Manuscript`
adını taşır. Bu nedenle dosya `run_Mathematics_R14_Manuscript.m` adıyla
kaydedilmelidir. İndirme sırasında eklenebilen `(2)` gibi son ekler
kaldırılmalıdır. Bu pakette kod, doğru MATLAB dosya adıyla ve kaynak
içeriği değiştirilmeden sunulmuştur.

### 3. Girdi dosyaları

Program sabit bir dosya yoluna bağlı değildir; her dosya için seçim
penceresi açar. Çalışma sayfası ve ölçüm sütunu gerektiğinde kullanıcı
tarafından seçilir.

#### 3.1. Güneş rüzgârı hız verileri

Aşağıdaki dosyalar sırayla seçilmelidir:

  -------------------------------------------------------------------------
                  Sıra Veri seti            Beklenen gözlem Zaman bilgisi
                                                     sayısı 
  -------------------- --------------- -------------------- ---------------
                     1 Set N                           2706 Özgün gözlem
                                                            sırası
                                                            kullanılır;
                                                            özgün zaman
                                                            damgası
                                                            eşlemesi
                                                            programda
                                                            bulunmaz.

                     2 Set A                           2706 Özgün gözlem
                                                            sırası
                                                            kullanılır;
                                                            özgün zaman
                                                            damgası
                                                            eşlemesi
                                                            programda
                                                            bulunmaz.

                     3 Set M                           2706 Saatlik ardışık
                                                            UTC; sütun
                                                            yoksa
                                                            01.01.2026
                                                            00:00 UTC
                                                            varsayılır.

                     4 Set 1                           2880 Saatlik ardışık
                                                            UTC; sütun
                                                            yoksa
                                                            01.01.2017
                                                            00:00 UTC
                                                            varsayılır.

                     5 Set 2                           2952 Saatlik ardışık
                                                            UTC; sütun
                                                            yoksa
                                                            01.05.2017
                                                            00:00 UTC
                                                            varsayılır.

                     6 Set 3                           2928 Saatlik ardışık
                                                            UTC; sütun
                                                            yoksa
                                                            01.09.2017
                                                            00:00 UTC
                                                            varsayılır.
  -------------------------------------------------------------------------

Program bu kayıt sayılarını kontrol eder. Eksik ölçüm içeren satırlar
silinmemelidir; boş hücre, `NaN` veya tanımlanmış eksik-veri kodu olarak
özgün satırında korunmalıdır. Ölçüm sütunu adı Set adı, `speed`, `v_kms`
veya `v` benzeri ifadeler üzerinden otomatik tanınmaya çalışılır; birden
fazla sayısal aday varsa kullanıcıdan seçim istenir.

#### 3.2. Zaman sütunu

Set M ve Set 1--3 için tek bir UTC zaman damgası sütunu kullanılması
önerilir. Uygun örnek biçimler:

-   `yyyy-MM-dd HH:mm:ss`
-   `yyyy-MM-dd'T'HH:mm:ss'Z'`

Sütun adı `timestamp_utc`, `start_utc`, `datetime` veya benzeri
olabilir. Mevcut zaman sütunu kullanıldığında saatlik kayıtların ardışık
olması gerekir; program bu koşul sağlanmazsa analizi durdurur. Zaman
sütunu yoksa kod yukarıdaki nominal başlangıç zamanlarını kullanarak
saatlik zaman üretir. Bu nedenle gerçek zaman bilgisi mevcutsa otomatik
varsayıma bırakılmamalı, kaynak zaman damgası verilmelidir.

Set N ve Set A için zaman damgası eşlemesi kullanılmaz; bu seriler
gözlem sırasına göre ve sıfır tabanlı gözlem indeksiyle değerlendirilir.
Doğrulanmamış zaman damgaları eklenmemelidir.

#### 3.3. Eksik veri kodları

Başlangıç penceresinde ek sayısal eksik-veri kodları virgülle ayrılarak
girilebilir. `9999` daima eksik kabul edilir. Örneğin:

`-999, -9999, 999.9`

Başka kod yoksa alan boş bırakılabilir. Boş hücreler ve sayısal olmayan
ölçüm girdileri de geçersiz/eksik değer olarak ele alınır. Kod eksik
değerleri otomatik enterpole etmez.

#### 3.4. Kp dosyaları

Set M, Set 1, Set 2 ve Set 3 için dört Kp Excel dosyası sırayla seçilir.
Set N ve Set A için Kp dosyası istenmez. Kp çalışma sayfasında Kp ölçüm
sütunu ve UTC zaman bilgisi bulunmalıdır.

Program iki biçimi kabul eder:

1.  Her 3 saatlik Kp değerinin üç ardışık saatlik satırda tekrarlandığı
    veri. Kod her üçlüde değerlerin aynı olduğunu doğrular ve ilk satırı
    alır.
2.  Doğrudan 3 saatlik kayıt. Zaman damgaları tam 3 saat aralıklı
    olmalıdır.

  Veri seti     Saatlik satır biçimi   3 saatlik kayıt biçimi
  ----------- ---------------------- ------------------------
  Set M                         2706                      902
  Set 1                         2880                      960
  Set 2                         2952                      984
  Set 3                         2928                      976

Kp zamanları 00, 03, 06, ..., 21 UTC başlangıçlarında olmalıdır. Kp
değerleri 0--9 aralığında olmalıdır. Kaynak dosyada değerler onda birim
biçimindeyse (ör. 30 = 3.0), maksimum değer 9'dan büyük olduğunda
program değerleri 10'a böler ve aralığı tekrar kontrol eder.

### 4. Çalıştırma adımları

1.  `run_Mathematics_R14_Manuscript.m` dosyasını MATLAB'ın erişebildiği
    klasöre kaydedin ve bu klasörü **Current Folder** olarak seçin.

2.  MATLAB Command Window'da çalıştırın:

    ``` matlab
    run_Mathematics_R14_Manuscript
    ```

3.  Ek eksik-veri kodlarını girin veya boş bırakın.

4.  Set N, A, M, 1, 2 ve 3 Excel dosyalarını istenen sırayla seçin.

5.  Her dosyada doğru çalışma sayfasını ve hız sütununu seçin.

6.  Set M, 1, 2 ve 3 Kp dosyalarını seçin.

7.  Çıktı klasörünü belirleyin ve analiz profilini seçin.

#### 4.1. Analiz profilleri

**Full manuscript run:** Nihai makale sonuçları için kullanılmalıdır.
GP/adaptif analizini çalıştırır; klasik yöntem bootstrap analizini 5000
tekrar, Bézier pertürbasyon analizini 1000 gerçekleştirim ve Kp
bootstrap analizini 5000 tekrar ile yürütür.

**Fast preview:** Ön kontrol ve hızlı görsel inceleme içindir. GP ve
genişletilmiş stokastik analizleri atlar; Kp bootstrap tekrar sayısını
300'e düşürür. Atlanan analizlerin Excel sayfalarında
`Not calculated in this run.` ifadesi bulunabilir. **Bu profilin
çıktıları nihai makale tabloları olarak kullanılmamalıdır.**

### 5. Hesaplama yöntemleri

#### 5.1. Bézier ve klasik interpolasyon

Temel analiz sekiz saatlik aralık içeren dokuz gözlemli pencereler
kullanır. Ardışık pencereler bir uç gözlemi paylaşır. Eksik değer içeren
pencereler pencere temelli analizlerden çıkarılır. Derece 2--6 Bézier
eğrilerinde uç noktalar sabitlenir ve iç kontrol noktaları en küçük
kareler yöntemiyle belirlenir.

Klasik yöntemler: doğrusal interpolasyon, kübik spline, PCHIP tabanlı
şekil koruyan kübik Hermite (kodda Hermite/PCHIP) ve Lagrange
interpolasyonudur. Klasik yöntemlerde destek düğümleri `0, 3, 5, 8`
olarak tanımlanır; uç değerler gözlenen uç noktalarla sabitlenir.

#### 5.2. Tutulan gözlem ve performans ölçütleri

Her geçerli pencerede uç noktalar korunur ve iç gözlemler sırayla birer
birer dışarıda bırakılarak yeniden kurulur. Örnek sayısı, RMSE, MAE,
MAPE ve R² hesaplanır.

#### 5.3. Süreklilik

Bézier segmentlerinin ortak düğüm noktalarındaki birinci türev
sıçramaları hesaplanır. Ayrıca ardışık geçerli pencerelerde ortak düğüm
eğimlerini birlikte en küçük karelerle belirleyen, uç noktalardan geçen
C1 kübik Hermite modeli oluşturulur.

#### 5.4. Yerel Aktivite İndeksi

LAI yalnızca Set M ve Set 1--3 için sekiz gözlemli, örtüşmeyen bloklarda
hesaplanır. Dört bileşen: standart sapma (STD), aralık (Range), ardışık
farkların mutlak değerlerinin ortalaması (MASD) ve maksimumu (MaxAD).
Bileşenlerin yüzde 25, 50 ve 75 kantilleriyle skorlar oluşturulur; LAI
dört bileşen skorunun ortalamasıdır. Sınıf eşikleri 0.75, 1.50 ve
2.25'tir. Kod ayrıca bileşen ağırlığı/eşik duyarlılığı, Pearson/Spearman
korelasyonları ve PC1 ağırlıkları hesaplar.

#### 5.5. Adaptif segmentasyon ve GP

Tam analizde her seri 24 saatlik/24 aralıklı bloklarda değerlendirilir.
Sabit kübik düğümler 0, 8, 16 ve 24'tür. Adaptif yaklaşım, izin verilen
iç düğüm konumlarını tarayarak eğitim hatasını en aza indirir.

GP, kareli üstel kovaryans fonksiyonu kullanır; eğitim verisinin
ortalamasıyla merkezlenir ve popülasyon standart sapmasıyla ölçeklenir.
Hiperparametreler, analitik gradyanlı, sınırlandırılmış, çok başlangıçlı
BFGS yöntemiyle optimize edilir. Optimizasyon kod içinde yazılmıştır.
Sınırlar: sinyal standart sapması 0.1--10, uzunluk ölçeği 0.5--24,
gürültü standart sapması 0.001--1. Yakınsama ve fallback tanılamaları
`GP_Optimizer_Diagnostics` sayfasına yazılır.

#### 5.6. Bootstrap, pertürbasyon ve Kp--LAI

Tam analizde klasik yöntem hareketli blok bootstrap'ı 5000 tekrar (seed
`4691220`), Bézier pertürbasyonu 1%, 3% ve 5% göreli standart sapma
düzeylerinde 1000 gerçekleştirim (seed `4691221`) ile yapılır. Kp
bootstrap seed'i `4691222`'dir.

Kp kayıtları sekiz saatlik LAI bloklarıyla zamansal örtüşmeye göre
eşleştirilir. Her blok için örtüşme süresiyle ağırlıklandırılmış
ortalama Kp ve maksimum Kp hesaplanır; LAI ile Spearman korelasyonu ve
24/72 saatlik hareketli blok bootstrap güven aralıkları elde edilir. Bu
analiz Set M ve Set 1--3 için uygulanır.

#### 5.7. Çalışma süresi

Her yöntem için üç ısınma çalıştırması ve 21 zamanlı tekrar yapılır.
Medyan ve yüzde 25--75 kantilleri raporlanır. Süreler bilgisayar
donanımı, işletim sistemi ve MATLAB sürümüne bağlıdır; farklı
bilgisayarlar arasında mutlak hız kıyaslaması olarak yorumlanmamalıdır.

### 6. Üretilen çıktılar

Seçilen çıktı klasöründe:

  -----------------------------------------------------------------------------------------
  Dosya/klasör                                          İçerik
  ----------------------------------------------------- -----------------------------------
  `SolarWindSpeed_Bezier_LAI_Manuscript_Results.xlsx`   Ana metin/ek sonuç tabloları,
                                                        tanılamalar ve kontrol tabloları

  `Figures/`                                            Figure 1--15 ve Figure A1--A12; her
                                                        biri 600 dpi PNG ve vektörel PDF

  `Figure_Index.csv`                                    Şekil kimlikleri, açıklamaları ve
                                                        dosya adları

  `Kp_3h_Combined.csv`                                  Dört Kp dosyasından birleştirilmiş,
                                                        UTC'ye göre sıralanmış 3 saatlik Kp
                                                        verisi

  `RUN_SUMMARY.txt`                                     MATLAB sürümü, bilgisayar mimarisi,
                                                        çalıştırma zamanı, girdi dosyaları,
                                                        kayıt/eksik değer sayıları ve
                                                        analiz profili
  -----------------------------------------------------------------------------------------

Excel çalışma kitabında `Table_01`--`Table_19`,
`Table_11a`--`Table_11c`, `Table_A1`--`Table_A11` (A5a/A5b, A8a/A8b ve
A9a/A9b alt sayfalarıyla), `Calibration_Offset_Check` ve
`GP_Optimizer_Diagnostics` sayfaları bulunur. `Table_20_Manual` yalnızca
Tablo 20'nin elle derlenen literatür karşılaştırması olduğunu belirten
not içerir; literatür değerleri program tarafından üretilmez. Bu sürüm
**Figure A12** üretir, ancak **Table A12** oluşturmaz. Hızlı ön izlemede
atlanan analiz sayfalarında `Not calculated in this run.` yazabilir.

### 7. Kalite kontrol ve sınırlılıklar

-   `RUN_SUMMARY.txt` içindeki kayıt sayısı, eksik değer, kaynak dosya,
    çalışma sayfası ve ölçüm sütunu bilgilerini kontrol edin.
-   Set M ve Set 1--3 zamanlarının saatlik ardışıklığını; Kp
    zamanlarının üç saatlik UTC başlangıçlarını doğrulayın.
-   Nihai tablolar için `Full manuscript run` kullanın.
-   GP sonuçlarını yorumlarken `GP_Optimizer_Diagnostics` sayfasındaki
    yakınsama ve fallback sayılarını inceleyin.
-   Set N ve A özgün zaman damgası eşlemesi olmadan gözlem sırasıyla
    değerlendirilir.
-   Eksik gözlemler enterpole edilmez; eksik değer içeren pencereler
    dışlanır.
-   LAI ve Kp--LAI analizleri yalnızca Set M ve Set 1--3 için yapılır.
-   Tablo A7 depolama değerleri, saklanan skaler parametre sayısından
    hesaplanan analitik tahminlerdir; ölçülmüş RAM veya tepe bellek
    kullanımı değildir.
-   Çalışma süresi değerleri yürütme ortamına bağlıdır.
-   Girdi dosyalarının bilimsel kökeni program tarafından doğrulanmaz;
    veri sağlayıcılarına ait atıflar gerçek veri kaynağına göre ayrıca
    verilmelidir.