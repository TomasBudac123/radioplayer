# kotlinx.serialization – modely sa kódujú cez vygenerované serializéry.
-keepattributes *Annotation*, InnerClasses
-keepclassmembers @kotlinx.serialization.Serializable class sk.radioplayer.app.** {
    *** Companion;
    kotlinx.serialization.KSerializer serializer(...);
}
