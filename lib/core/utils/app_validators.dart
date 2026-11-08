/// Centralized validation and formatting helper for the Student App
class AppValidators {
  AppValidators._();

  /// Converts Arabic-Indic / Persian digits (٠-٩, ۰-۹) to standard Western digits (0-9).
  static String normalizeDigits(String? input) {
    if (input == null) return '';
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    const western = '0123456789';

    var result = input.trim();
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(arabicIndic[i], western[i]);
      result = result.replaceAll(persian[i], western[i]);
    }
    return result;
  }

  /// Normalizes and cleans phone numbers (strips spaces, dashes, +20/0020 prefix).
  static String cleanEgyptianPhone(String? input) {
    var phone = normalizeDigits(input).replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (phone.startsWith('+20')) {
      phone = '0${phone.substring(3)}';
    } else if (phone.startsWith('0020')) {
      phone = '0${phone.substring(4)}';
    } else if (phone.startsWith('20') && phone.length == 12) {
      phone = '0${phone.substring(2)}';
    }
    return phone;
  }

  /// Validates required text fields.
  static String? validateRequired(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null ? 'يرجى إدخال $fieldName' : 'هذا الحقل مطلوب';
    }
    return null;
  }

  /// Validates Egyptian mobile phone numbers (Vodafone, Orange, Etisalat, WE).
  static String? validateEgyptianPhone(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null ? 'يرجى إدخال $fieldName' : 'يرجى إدخال رقم الهاتف';
    }
    final cleaned = cleanEgyptianPhone(value);
    final phoneRegex = RegExp(r'^01[0125][0-9]{8}$');
    if (!phoneRegex.hasMatch(cleaned)) {
      return 'رقم هاتف غير صحيح (يجب أن يبدأ بـ 010 أو 011 أو 012 أو 015 ويتكون من 11 رقماً)';
    }
    return null;
  }

  /// Validates mobile wallet number with optional specific provider check.
  static String? validateWalletNumber(String? value, {String? provider}) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال رقم المحفظة الإلكترونية المحول منها';
    }
    final cleaned = cleanEgyptianPhone(value);
    final generalValid = RegExp(r'^01[0125][0-9]{8}$').hasMatch(cleaned);
    if (!generalValid) {
      return 'رقم المحفظة غير صحيح (يجب أن يكون رقماً مصرياً مكوناً من 11 رقماً)';
    }

    if (provider != null) {
      final p = provider.trim().toLowerCase();
      if ((p.contains('فودافون') || p.contains('vodafone')) && !cleaned.startsWith('010')) {
        return 'رقم محفظة فودافون كاش يجب أن يبدأ بـ 010';
      }
      if ((p.contains('أورنج') || p.contains('اورنج') || p.contains('orange')) && !cleaned.startsWith('012')) {
        return 'رقم محفظة أورنج كاش يجب أن يبدأ بـ 012';
      }
      if ((p.contains('اتصالات') || p.contains('etisalat')) && !cleaned.startsWith('011')) {
        return 'رقم محفظة اتصالات كاش يجب أن يبدأ بـ 011';
      }
      if ((p.contains('وي') || p.contains('we')) && !cleaned.startsWith('015')) {
        return 'رقم محفظة وي باي يجب أن يبدأ بـ 015';
      }
    }
    return null;
  }

  /// Validates InstaPay account (either username@instapay / username@bank or Egyptian phone).
  static String? validateInstaPay(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال عنوان الدفع اللحظي (IPA) أو رقم هاتف إنستاباي';
    }
    final norm = normalizeDigits(value).trim();
    // Check if it's a mobile phone number
    final cleanedPhone = cleanEgyptianPhone(norm);
    if (RegExp(r'^01[0125][0-9]{8}$').hasMatch(cleanedPhone)) {
      return null;
    }
    // Check if it's an IPA: user@bank or user@instapay
    final ipaRegex = RegExp(r'^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+$');
    if (ipaRegex.hasMatch(norm)) {
      return null;
    }
    return 'يرجى إدخال عنوان إنستاباي صحيح (مثل: name@instapay) أو رقم هاتف مصري مسجل';
  }

  /// Validates payment identifier based on method (wallet, instapay, bank, etc.).
  static String? validatePaymentIdentifier(String? value, String paymentMethod) {
    final method = paymentMethod.toLowerCase();
    if (method.contains('محفظة') || method.contains('كاش') || method.contains('wallet')) {
      return validateWalletNumber(value, provider: paymentMethod);
    }
    if (method.contains('انستاباي') || method.contains('إنستاباي') || method.contains('instapay')) {
      return validateInstaPay(value);
    }
    if (method.contains('بنك') || method.contains('bank') || method.contains('حساب')) {
      if (value == null || value.trim().length < 6) {
        return 'يرجى إدخال رقم الحساب البنكي أو رقم مرجع التحويل';
      }
      return null;
    }
    return validateRequired(value, 'بيانات التحويل');
  }

  /// Validates email address format.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال البريد الإلكتروني';
    }
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }
    return null;
  }

  /// Validates password length and complexity.
  static String? validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى إدخال كلمة المرور';
    }
    if (value.trim().length < 6) {
      return 'كلمة المرور يجب ألا تقل عن 6 أحرف';
    }
    return null;
  }

  /// Validates password confirmation match.
  static String? validateConfirmPassword(String? value, String? originalPassword) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى تأكيد كلمة المرور';
    }
    if (value != originalPassword) {
      return 'كلمتا المرور غير متطابقتين';
    }
    return null;
  }

  /// Validates numeric positive integers.
  static String? validateNumber(String? value, [String? fieldName, int? min, int? max]) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null ? 'يرجى إدخال $fieldName' : 'هذا الحقل مطلوب';
    }
    final norm = normalizeDigits(value);
    final parsed = int.tryParse(norm);
    if (parsed == null) {
      return 'يرجى إدخال رقم صحيح';
    }
    if (min != null && parsed < min) {
      return 'القيمة يجب ألا تقل عن $min';
    }
    if (max != null && parsed > max) {
      return 'القيمة يجب ألا تزيد عن $max';
    }
    return null;
  }

  /// Validates course/lesson duration in minutes.
  static String? validateDurationMinutes(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'يرجى تحديد المدة بالدقائق';
    }
    final norm = normalizeDigits(value).replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(norm);
    if (parsed == null || parsed <= 0) {
      return 'يرجى إدخال مدة صحيحة أكبر من الصفر';
    }
    return null;
  }

  /// Formats lesson or video duration to Arabic with units (e.g. "30 دقيقة", "ساعة واحدة").
  static String formatDurationArabic(dynamic minutesOrString) {
    if (minutesOrString == null) return '';
    final str = minutesOrString.toString().trim();
    if (str.isEmpty) return '';

    // If it already contains Arabic units, normalize digits and return
    if (str.contains('دقيقة') || str.contains('ساعة') || str.contains('ثانية')) {
      return str;
    }

    final norm = normalizeDigits(str).replaceAll(RegExp(r'[^0-9]'), '');
    final minutes = int.tryParse(norm);
    if (minutes == null) return str;

    if (minutes == 1) return 'دقيقة واحدة';
    if (minutes == 2) return 'دقيقتان';
    if (minutes >= 3 && minutes <= 10) return '$minutes دقائق';
    if (minutes >= 11 && minutes < 60) return '$minutes دقيقة';
    if (minutes == 60) return 'ساعة واحدة';
    if (minutes == 120) return 'ساعتان';

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return hours >= 3 && hours <= 10 ? '$hours ساعات' : '$hours ساعة';
    }
    return '$hours ساعة و $remainingMinutes دقيقة';
  }

  /// Validates external URLs (Drive, YouTube, Docs, etc.).
  static String? validateUrl(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null ? 'يرجى إدخال رابط $fieldName' : 'يرجى إدخال الرابط';
    }
    final trimmed = value.trim();
    final urlRegex = RegExp(r'^(http|https):\/\/[^ "]+$');
    if (!urlRegex.hasMatch(trimmed)) {
      return 'يرجى إدخال رابط إنترنت صحيح يبدأ بـ https:// أو http://';
    }
    return null;
  }
}

