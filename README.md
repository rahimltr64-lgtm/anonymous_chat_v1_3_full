# دردشة مجهولة (anonymous_chat) — v1.2.0

مشروع Flutter كامل لتطبيق «دردشة مجهولة» بثيم جديد وأيقونة جديدة.

## الاستيراد في Klencode IDE
هذا الـ zip مشروع كامل يحتوي مجلد android (Gradle وManifest وMainActivity) ويُبنى مباشرة. لو أضفته لمشروعك القديم فاحتفظ بمجلد android القديم وانسخ منه الأيقونات وgoogle-services.json فقط.

1. فك الضغط وانسخ المحتوى إلى مشروعك (أو استورد الـ zip).
2. `lib/` + `pubspec.yaml` + `assets/` هي الأساس. نفس الحزم الأصلية: firebase_core / firebase_auth / cloud_firestore / shared_preferences / intl.
3. الأيقونة: `assets/icon/icon.png` (1024×1024)، ومجلدات `android/app/src/main/res/mipmap-*` جاهزة بكل الأحجام. إن كان Klencode يولّد مجلد android بنفسه فاستبدل مجلدات mipmap بها.
4. `android/app/google-services.json` بنفس مشروع Firebase الأصلي (spot-7ed0b، الحزمة com.klencod.compass). وإن لم يوجد أثناء البناء، `main.dart` يستخدم نفس الإعدادات تلقائيًا.

## ما الجديد
- ثيم داكن/فاتح (زر تبديل في الرئيسية، يُحفظ تلقائيًا) بألوان مستوحاة من الأيقونة.
- بطاقات زجاجية، أزرار متدرجة، فقاعات محادثة بتدرج أزرق، أسماء مجهولة بألوان وإيموجي حيوانات.
- أيقونة جديدة + شعار في الشاشة الرئيسية.
- زر لصق الكود، نسخ/حذف الرسالة بالضغط المطوّل، إزالة غرفة من القائمة الأخيرة.

## ملاحظات مهمة
- الكود مُعاد بناؤه من ملف APK (كود Dart مترجَم ولا يمكن استخراجه حرفيًا)، لذلك الشاشات والميزات مطابقة لما في التطبيق لكن الكود نفسه جديد.
- بنية Firestore المستخدمة: `rooms/{CODE}` بحقول `code, name, creatorId, createdAt` وداخلها `messages` بحقول `text, senderId, createdAt`. إن اختلفت أسماء الحقول في بياناتك القديمة فعدّلها في `lib/services.dart` و`lib/chat_screen.dart`.
- لم أستطع تشغيل `flutter build` هنا، فجرّب البناء في Klencode وأرسل لي أي خطأ يظهر.

## إرسال الصور والفيديوهات
يستخدم التطبيق Cloudinary (مجاني وبدون بطاقة). عدّل الثابتين `kCloudinaryCloudName` و `kCloudinaryUploadPreset` في `lib/media.dart`.
الحدود: صورة 10MB، فيديو 40MB.

## الرد والتفاعل
الضغط المطوّل على أي رسالة: شريط إيموجي للتفاعل + خيار «رد» (اقتباس).
الحقول: `replyTo` (خريطة) و `reactions` (خريطة uid → إيموجي). حدّث قواعد Firestore (انظر المحادثة).
