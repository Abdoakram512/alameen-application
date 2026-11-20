import '../../core/di/injection_container.dart';
import '../../core/storage/course_local_cache.dart';
import '../../datasources/courses_remote_data_source.dart';
import '../../models/about_us_data.dart';
import '../../models/bootstrap_data.dart';
import '../../models/contact_info_data.dart';
import '../../models/faq_item.dart';
import '../../models/landing_page_cms_data.dart';
import '../../models/privacy_policy_data.dart';
import '../student_content_repository.dart';

class StudentContentRepositoryImpl implements StudentContentRepository {
  final CoursesRemoteDataSource? _explicitCoursesRemoteDataSource;
  final CourseLocalCache? _explicitLocalCache;

  StudentContentRepositoryImpl({
    CoursesRemoteDataSource? coursesRemoteDataSource,
    CourseLocalCache? localCache,
  })  : _explicitCoursesRemoteDataSource = coursesRemoteDataSource,
        _explicitLocalCache = localCache;

  CoursesRemoteDataSource? get _remote {
    if (_explicitCoursesRemoteDataSource != null) return _explicitCoursesRemoteDataSource;
    if (sl.isRegistered<CoursesRemoteDataSource>()) {
      return sl<CoursesRemoteDataSource>();
    }
    return null;
  }

  CourseLocalCache get _cache {
    if (_explicitLocalCache != null) return _explicitLocalCache;
    if (sl.isRegistered<CourseLocalCache>()) {
      return sl<CourseLocalCache>();
    }
    return CourseLocalCacheImpl();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // P3 REST API + LOCAL CACHE IMPLEMENTATIONS
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<BootstrapData?> getBootstrapConfig() async {
    final remote = _remote;
    if (remote != null) {
      try {
        final bootstrap = await remote.getBootstrapConfig();
        await _cache.saveBootstrap(bootstrap);
        return bootstrap;
      } catch (_) {
        return await _cache.getBootstrap();
      }
    }
    return await _cache.getBootstrap();
  }

  @override
  Future<LandingPageCmsData?> getLandingPageData() async {
    final remote = _remote;
    if (remote != null) {
      try {
        return await remote.getLandingPageData();
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<ContactInfoData?> getContactInfo() async {
    final remote = _remote;
    if (remote != null) {
      try {
        final contact = await remote.getContactInfo();
        await _cache.saveContactInfo(contact);
        return contact;
      } catch (_) {
        return await _cache.getContactInfo();
      }
    }
    return await _cache.getContactInfo();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CMS / INFORMATIONAL PAGES (REST API / PUBLIC HOME + VERIFIED OFFLINE DEFAULTS)
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<AboutUsData> getAboutUs() async {
    try {
      final landingData = await getLandingPageData();
      final hero = landingData?.hero;
      final title = (hero != null && hero.title.trim().isNotEmpty)
          ? hero.title.trim()
          : 'مركز الأمين للتخاطب والتأهيل';
      final subtitle = hero?.subtitle;
      final pillars = landingData?.aboutPillars ?? [];

      String content = '';
      if (subtitle != null && subtitle.trim().isNotEmpty) {
        content += '$subtitle\n\n';
      }
      if (pillars.isNotEmpty) {
        for (final p in pillars) {
          if (p.title.isNotEmpty) {
            content += '• ${p.title}: ${p.description}\n';
          }
        }
      }
      if (content.trim().isNotEmpty) {
        return AboutUsData(
          title: title,
          content: content.trim(),
          pillars: pillars,
        );
      }
    } catch (_) {}

    return const AboutUsData(
      title: 'مركز الأمين للتخاطب والتأهيل',
      content: 'مرحباً بكم في مركز الأمين للتخاطب والتأهيل.\n\nصرح تدريبي واستشاري رائد ومتخصص في إعداد وتأهيل أخصائيي التخاطب وصعوبات التعلم وتعديل السلوك وتنمية المهارات بأعلى معايير الجودة المهنية.\n\nيقدم المركز برامج تدريبية ودورات معتمدة بإشراف نخبة من كبار الخبراء والاستشاريين بهدف تزويد المتدربين بالمهارات التطبيقية والعملية اللازمة للتميز في سوق العمل وخدمة أصحاب الهمم وأولياء الأمور بكفاءة واقتدار.',
    );
  }

  @override
  Future<List<FaqItem>> getFaqs() async {
    try {
      final landingData = await getLandingPageData();
      final faqs = landingData?.faqs;
      if (faqs != null && faqs.isNotEmpty) {
        return faqs;
      }
    } catch (_) {}

    return const [
      FaqItem(
        question: 'كيف أحصل على شهادة التخرج واجتياز الكورس؟',
        answer:
            'تحصل على الشهادة المعتمدة تلقائياً عند إتمامك لكافة المحاضرات بنسبة 100%، وتسليم جميع التكليفات والمهام المقررة واعتماد درجاتها من قِبل إدارة المركز.',
      ),
      FaqItem(
        question: 'هل المحاضرات مسجلة أم بث مباشر؟',
        answer:
            'المحاضرات مسجلة بجودة عالية ومرفوعة على خوادم آمنة لتتمكن من دراستها والرجوع إليها في أي وقت يناسب جدولك اليومي.',
      ),
      FaqItem(
        question: 'كيف أقوم بتسليم التكليفات والتطبيقات العملية؟',
        answer:
            'من داخل صفحة كل درس، ستجد نموذج تسليم التكليف المطلوب. قم برفع رابط أو نص الحل وسيتم تصحيحه من قِبل الإدارة ورصد الدرجة فوراً في ملفك التدريبي.',
      ),
      FaqItem(
        question: 'هل يمكنني تغيير اسمي المسجل في الشهادة؟',
        answer:
            'الاسم المسجل معتمد رسمياً في استخراج الشهادات لمنع التلاعب. في حال وجود خطأ إملائي، يرجى التواصل فوراً مع الدعم الفني لتعديله بعد التحقق من الهوية.',
      ),
      FaqItem(
        question: 'كيف أتواصل مع الدعم الفني وإدارة المركز؟',
        answer:
            'يمكنك التواصل عبر محادثة واتساب المباشرة أو الاتصال على الرقم: 01115240237 طوال أيام الأسبوع.',
      ),
    ];
  }

  @override
  Future<PrivacyPolicyData> getPrivacyPolicy() async {
    return const PrivacyPolicyData(
      title: 'سياسة الخصوصية والأمان',
      content: 'نولي في مركز الأمين للتخاطب والتأهيل أولوية قصوى لحماية خصوصيتك وسرية بياناتك الشخصية.\n\n١. جمع البيانات:\nنقوم بجمع بيانات الاسم ورقم الهاتف والبريد الإلكتروني فقط لأغراض التوثيق الأكاديمي، إصدار الشهادات المعتمدة، وتوفير الدعم الفني اللازم.\n\n٢. سرية المحتوى والأمان:\nجميع الدروس والمحاضرات الرقمية والتسجيلات محمية بحقوق ملكية فكرية بموجب القانون. يُمنع تصوير الشاشة أو تسجيل المحاضرات أو مشاركة الحسابات مع أطراف أخرى.\n\n٣. مشاركة البيانات:\nنلتزم التزاماً كاملاً بعدم بيع أو مشاركة بياناتك الشخصية مع أي أطراف ثالثة أو شركات تسويقية إطلاقاً.\n\n٤. حذف الحساب والبيانات:\nيحق للمتدرب في أي وقت طلب حذف حسابه بالكامل من التطبيق عبر الذهاب للملف الشخصي واختيار "حذف الحساب نهائياً"، وسيتم مسح جميع بياناته فوراً وبشكل دائم.',
    );
  }
}
