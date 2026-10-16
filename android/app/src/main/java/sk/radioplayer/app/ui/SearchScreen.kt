package sk.radioplayer.app.ui

import android.content.Intent
import android.speech.RecognizerIntent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusManager
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import java.text.Normalizer
import sk.radioplayer.app.R
import sk.radioplayer.app.data.Genre
import sk.radioplayer.app.data.Station
import sk.radioplayer.app.playback.Playback
import sk.radioplayer.app.ui.components.EmptyState
import sk.radioplayer.app.ui.components.EqualizerBars
import sk.radioplayer.app.ui.components.PrimaryButton
import sk.radioplayer.app.ui.components.StationArtwork
import sk.radioplayer.app.ui.theme.Radius
import sk.radioplayer.app.ui.theme.RadioTheme
import sk.radioplayer.app.ui.theme.Spacing

private enum class FilterKind { Country, Genre }

@Composable
fun SearchScreen(
    state: SearchState,
    favorites: List<Station>,
    playback: Playback,
    contentPadding: PaddingValues,
    onQueryChange: (String) -> Unit,
    onSubmit: () -> Unit,
    onCountrySelected: (String?) -> Unit,
    onGenreSelected: (String?) -> Unit,
    onClearFilters: () -> Unit,
    onResultTap: (Station) -> Unit,
    onFavoriteTap: (Station) -> Unit,
    onLoadMore: () -> Unit,
    onRetry: () -> Unit,
    onVoiceResult: (String) -> Unit,
) {
    val colors = RadioTheme.colors
    val focusManager = LocalFocusManager.current
    var picker by remember { mutableStateOf<FilterKind?>(null) }
    val listState = rememberLazyListState()
    val favoriteIds = remember(favorites) { favorites.map { it.id }.toSet() }

    val shouldLoadMore by remember {
        derivedStateOf {
            val last = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
            last >= listState.layoutInfo.totalItemsCount - 5
        }
    }
    LaunchedEffect(shouldLoadMore, state.results.size) {
        if (shouldLoadMore && state.results.isNotEmpty()) onLoadMore()
    }

    Column(Modifier.fillMaxSize()) {
        LargeHeader(stringResource(R.string.tab_search))
        SearchField(state.query, stringResource(R.string.search_prompt), onQueryChange, onSubmit, focusManager, onVoiceResult = onVoiceResult)
        Row(
            horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = Spacing.m, vertical = Spacing.s),
        ) {
            FilterChip(
                title = state.selectedCountry?.let { "${it.flag} ${it.name}" } ?: stringResource(R.string.search_whole_world),
                icon = if (state.selectedCountry == null) R.drawable.ic_public else null,
                isActive = state.countryCode != null,
                onClick = { picker = FilterKind.Country },
            )
            FilterChip(
                title = Genre.named(state.genreTag)?.let { stringResource(it.nameRes) } ?: stringResource(R.string.search_all_genres),
                icon = R.drawable.ic_music_note,
                isActive = state.genreTag != null,
                onClick = { picker = FilterKind.Genre },
            )
            if (state.countryCode != null || state.genreTag != null) {
                TextButton(onClick = onClearFilters) { Text(stringResource(R.string.search_clear_filters), color = colors.textSecondary) }
            }
        }

        when {
            state.errorMessage != null && state.results.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                EmptyState(R.drawable.ic_wifi_off, stringResource(R.string.search_offline_title), stringResource(state.errorMessage)) {
                    PrimaryButton(stringResource(R.string.action_retry), onRetry)
                }
            }
            state.isLoading && state.results.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = colors.textSecondary)
            }
            state.results.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                EmptyState(R.drawable.ic_search, stringResource(R.string.search_no_results_title), stringResource(R.string.search_no_results_message))
            }
            else -> LazyColumn(
                state = listState,
                contentPadding = PaddingValues(bottom = contentPadding.calculateBottomPadding() + Spacing.m),
                modifier = Modifier.fillMaxSize(),
            ) {
                item {
                    Text(
                        stringResource(state.resultsTitle),
                        style = MaterialTheme.typography.labelLarge,
                        color = colors.textSecondary,
                        modifier = Modifier.padding(horizontal = Spacing.m, vertical = Spacing.xs),
                    )
                }
                items(state.results, key = { it.id }) { station ->
                    StationRow(
                        station = station,
                        playback = playback,
                        isFavorite = station.id in favoriteIds,
                        onTap = {
                            focusManager.clearFocus()
                            onResultTap(station)
                        },
                        onFavoriteTap = { onFavoriteTap(station) },
                    )
                    HorizontalDivider(color = colors.border, modifier = Modifier.padding(start = 76.dp))
                }
                if (state.isLoadingMore) {
                    item {
                        Box(Modifier.fillMaxWidth().padding(Spacing.m), contentAlignment = Alignment.Center) {
                            CircularProgressIndicator(color = colors.textSecondary, modifier = Modifier.size(24.dp))
                        }
                    }
                }
            }
        }
    }

    picker?.let { kind ->
        FilterPicker(
            kind = kind,
            state = state,
            onDismiss = { picker = null },
            onSelect = { value ->
                picker = null
                if (kind == FilterKind.Country) onCountrySelected(value) else onGenreSelected(value)
            },
        )
    }
}

@Composable
private fun SearchField(
    query: String,
    placeholder: String,
    onQueryChange: (String) -> Unit,
    onSubmit: () -> Unit,
    focusManager: FocusManager,
    onVoiceResult: ((String) -> Unit)? = null,
) {
    val colors = RadioTheme.colors
    val speech = rememberSpeechRecognizer { onVoiceResult?.invoke(it) }
    TextField(
        value = query,
        onValueChange = onQueryChange,
        placeholder = { Text(placeholder, maxLines = 1, overflow = TextOverflow.Ellipsis) },
        leadingIcon = { Icon(painterResource(R.drawable.ic_search), null) },
        trailingIcon = {
            when {
                query.isNotEmpty() -> IconButton(onClick = { onQueryChange("") }) {
                    Icon(painterResource(R.drawable.ic_close), stringResource(R.string.search_clear))
                }
                onVoiceResult != null && speech.isAvailable -> IconButton(onClick = speech::listen) {
                    Icon(painterResource(R.drawable.ic_mic), stringResource(R.string.search_voice))
                }
            }
        },
        singleLine = true,
        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
        keyboardActions = KeyboardActions(onSearch = {
            focusManager.clearFocus()
            onSubmit()
        }),
        shape = RoundedCornerShape(Radius.control),
        colors = TextFieldDefaults.colors(
            focusedContainerColor = colors.surfaceMuted,
            unfocusedContainerColor = colors.surfaceMuted,
            focusedIndicatorColor = androidx.compose.ui.graphics.Color.Transparent,
            unfocusedIndicatorColor = androidx.compose.ui.graphics.Color.Transparent,
            focusedLeadingIconColor = colors.textSecondary,
            unfocusedLeadingIconColor = colors.textSecondary,
            focusedPlaceholderColor = colors.textTertiary,
            unfocusedPlaceholderColor = colors.textTertiary,
            cursorColor = colors.accent,
        ),
        modifier = Modifier.fillMaxWidth().padding(horizontal = Spacing.m),
    )
}

@Composable
private fun FilterChip(title: String, icon: Int?, isActive: Boolean, onClick: () -> Unit) {
    val colors = RadioTheme.colors
    Surface(
        onClick = onClick,
        shape = CircleShape,
        color = if (isActive) colors.accent else colors.surface,
        contentColor = if (isActive) colors.onAccent else colors.textPrimary,
        border = if (isActive) null else BorderStroke(1.dp, colors.border),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.height(36.dp).padding(horizontal = Spacing.s),
        ) {
            if (icon != null) {
                Icon(painterResource(icon), null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
            }
            Text(title, style = MaterialTheme.typography.labelLarge, maxLines = 1)
            Spacer(Modifier.width(4.dp))
            Icon(painterResource(R.drawable.ic_chevron_down), null, modifier = Modifier.size(18.dp))
        }
    }
}

@Composable
fun StationRow(
    station: Station,
    playback: Playback,
    isFavorite: Boolean,
    onTap: () -> Unit,
    onFavoriteTap: () -> Unit,
) {
    val colors = RadioTheme.colors
    val isCurrent = playback.isCurrent(station)
    val haptics = LocalHapticFeedback.current
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onTap)
            .padding(start = Spacing.m, end = Spacing.xxs, top = Spacing.xs, bottom = Spacing.xs),
    ) {
        StationArtwork(station, Modifier.size(48.dp))
        Spacer(Modifier.width(Spacing.s))
        Column(Modifier.weight(1f)) {
            Text(
                station.name,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = if (isCurrent) FontWeight.SemiBold else FontWeight.Normal,
                color = colors.textPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                if (isCurrent) playback.statusText() else station.subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = if (isCurrent && playback.status == Playback.Status.Failed) colors.danger else colors.textSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        if (isCurrent) {
            when (playback.status) {
                Playback.Status.Loading -> CircularProgressIndicator(
                    color = colors.textSecondary,
                    strokeWidth = 2.dp,
                    modifier = Modifier.size(18.dp),
                )
                Playback.Status.Playing -> EqualizerBars(isAnimating = true)
                else -> EqualizerBars(isAnimating = false, color = colors.textTertiary)
            }
        }
        IconButton(onClick = {
            haptics.performHapticFeedback(HapticFeedbackType.ContextClick)
            onFavoriteTap()
        }) {
            Icon(
                painterResource(if (isFavorite) R.drawable.ic_star else R.drawable.ic_star_outline),
                contentDescription = stringResource(if (isFavorite) R.string.favorites_remove else R.string.favorites_add),
                tint = if (isFavorite) colors.accent else colors.textTertiary,
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FilterPicker(
    kind: FilterKind,
    state: SearchState,
    onDismiss: () -> Unit,
    onSelect: (String?) -> Unit,
) {
    val colors = RadioTheme.colors
    val resources = LocalResources.current
    val wholeWorld = stringResource(R.string.search_whole_world)
    val allGenres = stringResource(R.string.search_all_genres)
    var filter by remember { mutableStateOf("") }
    data class Option(val value: String?, val title: String, val detail: String?)

    val all = remember(kind, state.countries) {
        when (kind) {
            FilterKind.Country -> listOf(Option(null, "🌍 $wholeWorld", null)) +
                state.countries.map { Option(it.code, "${it.flag} ${it.name}", it.stationCount.toString()) }
            FilterKind.Genre -> listOf(Option(null, allGenres, null)) + Genre.all.map { Option(it.tag, resources.getString(it.nameRes), null) }
        }
    }
    val options = remember(all, filter) {
        val needle = filter.trim().foldDiacritics()
        if (needle.isEmpty()) all else all.filter { it.title.foldDiacritics().contains(needle) }
    }
    val selected = if (kind == FilterKind.Country) state.countryCode else state.genreTag

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = colors.background,
    ) {
        Text(
            stringResource(if (kind == FilterKind.Country) R.string.search_country else R.string.search_genre),
            style = MaterialTheme.typography.titleLarge,
            color = colors.textPrimary,
            modifier = Modifier.padding(horizontal = Spacing.m),
        )
        Spacer(Modifier.height(Spacing.s))
        SearchField(
            filter,
            stringResource(if (kind == FilterKind.Country) R.string.search_find_country else R.string.search_find_genre),
            { filter = it },
            {},
            LocalFocusManager.current,
        )
        Spacer(Modifier.height(Spacing.xs))
        LazyColumn(Modifier.fillMaxWidth()) {
            items(options, key = { it.value ?: "" }) { option ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onSelect(option.value) }
                        .padding(horizontal = Spacing.m, vertical = 14.dp),
                ) {
                    Text(option.title, color = colors.textPrimary, modifier = Modifier.weight(1f))
                    option.detail?.let { Text(it, style = MaterialTheme.typography.bodySmall, color = colors.textTertiary) }
                    if (option.value == selected) {
                        Spacer(Modifier.width(Spacing.s))
                        Icon(painterResource(R.drawable.ic_check), stringResource(R.string.search_selected), tint = colors.accent)
                    }
                }
            }
        }
    }
}

private fun String.foldDiacritics(): String =
    Normalizer.normalize(lowercase(), Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "")

/** Systémové rozpoznávanie reči (Google) – výsledok sa vloží do hľadania. */
class SpeechRecognizerLauncher(val isAvailable: Boolean, private val launch: () -> Unit) {
    fun listen() = launch()
}

@Composable
private fun rememberSpeechRecognizer(onResult: (String) -> Unit): SpeechRecognizerLauncher {
    val context = LocalContext.current
    val prompt = stringResource(R.string.search_voice)
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        result.data
            ?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
            ?.firstOrNull()
            ?.takeIf { it.isNotBlank() }
            ?.let(onResult)
    }
    return remember(launcher) {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_PROMPT, prompt)
        val isAvailable = intent.resolveActivity(context.packageManager) != null
        SpeechRecognizerLauncher(isAvailable) { launcher.launch(intent) }
    }
}
