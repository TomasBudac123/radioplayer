package sk.tomasbudac.airwaves.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import sk.tomasbudac.airwaves.R
import sk.tomasbudac.airwaves.data.Station
import sk.tomasbudac.airwaves.playback.Playback
import sk.tomasbudac.airwaves.ui.components.EmptyState
import sk.tomasbudac.airwaves.ui.components.EqualizerBars
import sk.tomasbudac.airwaves.ui.components.PrimaryButton
import sk.tomasbudac.airwaves.ui.components.StationArtwork
import sk.tomasbudac.airwaves.ui.theme.Radius
import sk.tomasbudac.airwaves.ui.theme.AirwavesTheme
import sk.tomasbudac.airwaves.ui.theme.Spacing

@Composable
fun FavoritesScreen(
    favorites: List<Station>,
    playback: Playback,
    isEditing: Boolean,
    contentPadding: PaddingValues,
    onTileTap: (Station) -> Unit,
    onEdit: () -> Unit,
    onDone: () -> Unit,
    onRemove: (Station) -> Unit,
    onMove: (Int, Int) -> Unit,
    onFindStations: () -> Unit,
) {
    Column(Modifier.fillMaxSize()) {
        LargeHeader(
            title = stringResource(R.string.tab_favorites),
            action = when {
                favorites.isEmpty() -> null
                isEditing -> ({ TextButton(onClick = onDone) { Text(stringResource(R.string.action_done), fontWeight = FontWeight.SemiBold) } })
                else -> ({ TextButton(onClick = onEdit) { Text(stringResource(R.string.action_edit)) } })
            },
        )
        when {
            favorites.isEmpty() -> Box(Modifier.fillMaxSize().padding(contentPadding), contentAlignment = Alignment.Center) {
                EmptyState(
                    icon = R.drawable.ic_star_outline,
                    title = stringResource(R.string.favorites_empty_title),
                    message = stringResource(R.string.favorites_empty_message),
                ) { PrimaryButton(stringResource(R.string.favorites_empty_action), onFindStations) }
            }
            isEditing -> EditingList(favorites, contentPadding, onRemove, onMove)
            else -> LazyVerticalGrid(
                columns = GridCells.Adaptive(104.dp),
                contentPadding = PaddingValues(
                    start = Spacing.m,
                    end = Spacing.m,
                    top = Spacing.s,
                    bottom = contentPadding.calculateBottomPadding() + Spacing.m,
                ),
                horizontalArrangement = Arrangement.spacedBy(Spacing.m),
                verticalArrangement = Arrangement.spacedBy(Spacing.l),
                modifier = Modifier.fillMaxSize(),
            ) {
                items(favorites, key = { it.id }) { station ->
                    FavoriteTile(
                        station = station,
                        playback = playback,
                        onTap = { onTileTap(station) },
                        onRemove = { onRemove(station) },
                        modifier = Modifier.animateItem(),
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun FavoriteTile(
    station: Station,
    playback: Playback,
    onTap: () -> Unit,
    onRemove: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = AirwavesTheme.colors
    val isCurrent = playback.isCurrent(station)
    val statusText = playback.statusText()
    var menuOpen by remember { mutableStateOf(false) }
    val haptics = LocalHapticFeedback.current
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) 0.96f else 1f, label = "press")

    Column(
        modifier = modifier
            .scale(scale)
            .combinedClickable(
                interactionSource = interaction,
                indication = null,
                role = Role.Button,
                onClick = onTap,
                onLongClick = {
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    menuOpen = true
                },
            )
            .semantics {
                contentDescription = station.name
                if (isCurrent) stateDescription = statusText
            },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box {
            StationArtwork(
                station = station,
                cornerRadius = Radius.tile,
                modifier = Modifier
                    .fillMaxWidth()
                    .then(
                        if (isCurrent) Modifier.border(2.dp, colors.accent, RoundedCornerShape(Radius.tile)) else Modifier,
                    ),
            )
            androidx.compose.animation.AnimatedVisibility(
                visible = isCurrent,
                enter = scaleIn() + fadeIn(),
                exit = scaleOut() + fadeOut(),
                modifier = Modifier.align(Alignment.BottomEnd).padding(Spacing.xs),
            ) {
                StatusBadge(playback)
            }
            DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                DropdownMenuItem(
                    text = { Text(stringResource(R.string.favorites_remove)) },
                    leadingIcon = { Icon(painterResource(R.drawable.ic_delete), null) },
                    onClick = {
                        menuOpen = false
                        onRemove()
                    },
                )
            }
        }
        Spacer(Modifier.size(Spacing.xs))
        Text(
            text = station.name,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = if (isCurrent) FontWeight.SemiBold else FontWeight.Normal,
            color = colors.textPrimary,
            maxLines = 2,
            minLines = 2,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun StatusBadge(playback: Playback) {
    val colors = AirwavesTheme.colors
    Box(
        modifier = Modifier.size(30.dp).background(colors.accent, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        when (playback.status) {
            Playback.Status.Loading -> CircularProgressIndicator(
                color = colors.onAccent,
                strokeWidth = 2.dp,
                modifier = Modifier.size(14.dp),
            )
            Playback.Status.Playing -> EqualizerBars(isAnimating = true, color = colors.onAccent)
            Playback.Status.Failed -> Text("!", color = colors.onAccent, fontWeight = FontWeight.Bold)
            else -> Icon(painterResource(R.drawable.ic_pause), null, tint = colors.onAccent, modifier = Modifier.size(16.dp))
        }
    }
}

@Composable
private fun EditingList(
    favorites: List<Station>,
    contentPadding: PaddingValues,
    onRemove: (Station) -> Unit,
    onMove: (Int, Int) -> Unit,
) {
    val colors = AirwavesTheme.colors
    LazyColumn(
        contentPadding = PaddingValues(bottom = contentPadding.calculateBottomPadding() + Spacing.m),
        modifier = Modifier.fillMaxSize(),
    ) {
        itemsIndexed(favorites, key = { _, station -> station.id }) { index, station ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .animateItem()
                    .fillMaxWidth()
                    .padding(start = Spacing.m, end = Spacing.xs, top = Spacing.xxs, bottom = Spacing.xxs),
            ) {
                IconButton(onClick = { onRemove(station) }) {
                    Icon(painterResource(R.drawable.ic_delete), stringResource(R.string.favorites_remove_station, station.name), tint = colors.danger)
                }
                StationArtwork(station, Modifier.size(40.dp), cornerRadius = Radius.small)
                Spacer(Modifier.width(Spacing.s))
                Text(
                    station.name,
                    modifier = Modifier.weight(1f),
                    color = colors.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                IconButton(onClick = { onMove(index, index - 1) }, enabled = index > 0) {
                    Icon(painterResource(R.drawable.ic_arrow_up), stringResource(R.string.favorites_move_up))
                }
                IconButton(onClick = { onMove(index, index + 1) }, enabled = index < favorites.lastIndex) {
                    Icon(painterResource(R.drawable.ic_arrow_down), stringResource(R.string.favorites_move_down))
                }
            }
            HorizontalDivider(color = colors.border, modifier = Modifier.padding(start = 72.dp))
        }
        item {
            Text(
                stringResource(R.string.favorites_reorder_hint),
                style = MaterialTheme.typography.bodySmall,
                color = colors.textSecondary,
                modifier = Modifier.padding(Spacing.m),
            )
        }
    }
}

/** Veľký nadpis obrazovky v štýle iOS, s voliteľnou akciou vpravo. */
@Composable
fun LargeHeader(title: String, action: (@Composable () -> Unit)? = null) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth().padding(start = Spacing.m, end = Spacing.xs, top = Spacing.m, bottom = Spacing.xs),
    ) {
        Text(
            title,
            style = MaterialTheme.typography.headlineLarge,
            color = AirwavesTheme.colors.textPrimary,
            modifier = Modifier.weight(1f),
        )
        action?.invoke()
    }
}
