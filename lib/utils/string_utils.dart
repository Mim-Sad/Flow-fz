class StringUtils {
  /// Normalizes Persian/Arabic strings by:
  /// 1. Removing diacritics (Fatha, Damma, Kasra, Shadda, etc.)
  /// 2. Removing Kashida (Tatweel)
  /// 3. Normalizing characters (Arabic Yeh/Keh to Persian)
  /// 4. Removing extra spaces and trimming
  /// 5. Converting to lowercase
  static String normalize(String input) {
    if (input.isEmpty) return input;

    String result = input.trim();

    // Normalize characters
    result = result.replaceAll('ي', 'ی'); // Arabic Yeh to Persian Yeh
    result = result.replaceAll('ك', 'ک'); // Arabic Keh to Persian Keh
    result = result.replaceAll('أ', 'ا'); // Arabic Alef with Hamza to Alef
    result = result.replaceAll('إ', 'ا'); // Arabic Alef with Hamza below to Alef
    result = result.replaceAll('آ', 'ا'); // Arabic Alef with Madda to Alef
    
    // Normalize Persian digits to English for comparison consistency if needed, 
    // but usually tags are text. Let's keep digits as they are for now but normalize them to one format.
    const persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(persianDigits[i], englishDigits[i]);
      result = result.replaceAll(arabicDigits[i], englishDigits[i]);
    }

    // Remove diacritics
    final diacritics = [
      '\u064B', // Fathatayn
      '\u064C', // Dammatayn
      '\u064D', // Kasratayn
      '\u064E', // Fatha
      '\u064F', // Damma
      '\u0650', // Kasra
      '\u0651', // Shadda
      '\u0652', // Sukun
      '\u0640', // Tatweel/Kashida
    ];

    for (var d in diacritics) {
      result = result.replaceAll(d, '');
    }

    // Normalize spaces (remove multiple spaces, replace with single space)
    result = result.replaceAll(RegExp(r'\s+'), ''); // Removing all spaces for strict duplicate check as requested

    return result.toLowerCase();
  }

  /// Checks if two strings are duplicates after normalization
  static bool areTagsDuplicate(String tag1, String tag2) {
    return normalize(tag1) == normalize(tag2);
  }
  
  /// Checks if a list of tags contains a tag (normalized)
  static bool containsTag(List<String> tags, String newTag) {
    final normalizedNewTag = normalize(newTag);
    return tags.any((tag) => normalize(tag) == normalizedNewTag);
  }
}
