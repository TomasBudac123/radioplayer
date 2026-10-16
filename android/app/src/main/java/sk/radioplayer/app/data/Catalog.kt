package sk.radioplayer.app.data

import androidx.annotation.StringRes
import sk.radioplayer.app.R

/** Žáner – overený zoznam tagov (rovnaký ako web a iOS), surové tagy v databáze sú nejednotné. */
data class Genre(val tag: String, @StringRes val nameRes: Int) {
    companion object {
        val all = listOf(
            Genre("alternative", R.string.genre_alternative),
            Genre("pop", R.string.genre_pop),
            Genre("rock", R.string.genre_rock),
            Genre("hits", R.string.genre_hits),
            Genre("top 40", R.string.genre_top40),
            Genre("news", R.string.genre_news),
            Genre("talk", R.string.genre_talk),
            Genre("sport", R.string.genre_sport),
            Genre("dance", R.string.genre_dance),
            Genre("electronic", R.string.genre_electronic),
            Genre("house", R.string.genre_house),
            Genre("techno", R.string.genre_techno),
            Genre("trance", R.string.genre_trance),
            Genre("chillout", R.string.genre_chillout),
            Genre("lounge", R.string.genre_lounge),
            Genre("ambient", R.string.genre_ambient),
            Genre("jazz", R.string.genre_jazz),
            Genre("blues", R.string.genre_blues),
            Genre("soul", R.string.genre_soul),
            Genre("funk", R.string.genre_funk),
            Genre("rnb", R.string.genre_rnb),
            Genre("hip hop", R.string.genre_hiphop),
            Genre("classical", R.string.genre_classical),
            Genre("soundtrack", R.string.genre_soundtrack),
            Genre("oldies", R.string.genre_oldies),
            Genre("60s", R.string.genre_60s),
            Genre("70s", R.string.genre_70s),
            Genre("80s", R.string.genre_80s),
            Genre("90s", R.string.genre_90s),
            Genre("2000s", R.string.genre_2000s),
            Genre("disco", R.string.genre_disco),
            Genre("classic rock", R.string.genre_classicrock),
            Genre("metal", R.string.genre_metal),
            Genre("punk", R.string.genre_punk),
            Genre("indie", R.string.genre_indie),
            Genre("country", R.string.genre_country),
            Genre("folk", R.string.genre_folk),
            Genre("reggae", R.string.genre_reggae),
            Genre("latin", R.string.genre_latin),
            Genre("world", R.string.genre_world),
            Genre("christian", R.string.genre_christian),
            Genre("kids", R.string.genre_kids),
            Genre("comedy", R.string.genre_comedy),
            Genre("public radio", R.string.genre_publicradio),
        )

        fun named(tag: String?): Genre? = all.firstOrNull { it.tag == tag }
    }
}

data class Country(val code: String, val name: String, val stationCount: Int) {
    /** Vlajka z ISO kódu krajiny, napr. „SK“ → 🇸🇰. */
    val flag: String
        get() = if (code.length == 2 && code.all { it in 'A'..'Z' }) {
            code.map { String(Character.toChars(0x1F1A5 + it.code)) }.joinToString("")
        } else ""
}

/** Parametre hľadania v databáze rádií. */
data class StationQuery(
    val name: String = "",
    val countryCode: String? = null,
    val tag: String? = null,
    val offset: Int = 0,
    val limit: Int = PAGE_SIZE,
) {
    val isFiltered: Boolean get() = name.isNotBlank() || tag != null || countryCode != null

    companion object {
        const val PAGE_SIZE = 40
    }
}
