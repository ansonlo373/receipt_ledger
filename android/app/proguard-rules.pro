# ML Kit text recognition bundles only the Latin + Japanese models in this app
# (see the text-recognition-japanese dependency in build.gradle.kts). The
# google_mlkit_text_recognition plugin still references the optional Chinese,
# Korean and Devanagari recognizers, whose classes are not on the classpath.
# Without these rules, R8 aborts the release build on the missing classes
# instead of treating them as warnings.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
