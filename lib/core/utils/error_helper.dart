import 'dart:io';
import 'package:pocketbase/pocketbase.dart';

class ErrorHelper {
  /// Converts raw exceptions (e.g. SocketException, ClientException) to clean user-facing Arabic messages.
  static String getFriendlyErrorMessage(dynamic e, {String defaultMessage = 'حدث خطأ غير متوقع. يرجى المحاولة لاحقاً.'}) {
    if (e == null) return defaultMessage;

    final errorStr = e.toString().toLowerCase();

    // Connection & Socket issues (Offline / DNS Lookup failures)
    if (e is SocketException || 
        errorStr.contains('socketexception') || 
        errorStr.contains('failed host lookup') || 
        errorStr.contains('network is unreachable') ||
        errorStr.contains('connection timed out') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('software caused connection abort')) {
      return 'تعذر الاتصال بالخادم. يرجى التحقق من اتصالك بالإنترنت والمحاولة مجدداً.';
    }

    // Handshake / Security issues
    if (errorStr.contains('handshakeexception') || errorStr.contains('certificatedatedinvalid')) {
      return 'فشل إنشاء اتصال آمن بالخادم. يرجى التحقق من ضبط الوقت والتاريخ على جهازك.';
    }

    // PocketBase ClientException
    if (e is ClientException) {
      if (e.statusCode == 0 || e.isAbort) {
        return 'تعذر الاتصال بالخادم. يرجى التحقق من اتصالك بالإنترنت والمحاولة مجدداً.';
      }
      if (e.statusCode == 401 || e.statusCode == 403) {
        return 'عذراً، لا تملك الصلاحية للقيام بهذا الإجراء أو انتهت صلاحية الجلسة.';
      }
      if (e.statusCode == 404) {
        return 'عذراً، لم يتم العثور على البيانات المطلوبة.';
      }
      if (e.statusCode == 408 || e.statusCode == 504) {
        return 'انتهت مهلة الاتصال بالخادم. يرجى المحاولة مجدداً.';
      }
      if (e.statusCode >= 500) {
        return 'عذراً، حدث خلل في خادم الخدمة. يرجى المحاولة لاحقاً.';
      }
      
      // Look at nested originalError
      if (e.originalError != null) {
        return getFriendlyErrorMessage(e.originalError, defaultMessage: defaultMessage);
      }
    }

    // Specific file validation errors
    if (errorStr.contains('validation_file_size_limit')) {
      return 'حجم الملف الصوتي كبير جداً. الحد الأقصى المسموح به حالياً على الخادم هو 5 ميجابايت.';
    }
    if (errorStr.contains('validation_file_mime_type')) {
      return 'نوع الملف الصوتي غير مدعوم على الخادم.';
    }

    return defaultMessage;
  }
}
