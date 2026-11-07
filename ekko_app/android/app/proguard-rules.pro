# ML Kit ships optional script recognisers we don't bundle (Latin only).
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-keep class net.zetetic.database.** { *; }
-keep class net.sqlcipher.** { *; }
