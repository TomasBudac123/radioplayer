package sk.tomasbudac.airwaves.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import sk.tomasbudac.airwaves.R
import sk.tomasbudac.airwaves.playback.Playback
import sk.tomasbudac.airwaves.ui.components.StationArtwork
import sk.tomasbudac.airwaves.ui.theme.Radius
import sk.tomasbudac.airwaves.ui.theme.AirwavesTheme
import sk.tomasbudac.airwaves.ui.theme.Spacing

/** Stavový text prehrávača („Naživo · Slovensko · 128 kbps“) v jazyku zariadenia. */
@Composable
fun Playback.statusText(): String = statusText(LocalResources.current)

/** Kompaktný prehrávač nad spodnou navigáciou. */
@Composable
fun MiniPlayer(playback: Playback, onOpen: () -> Unit, onTogglePlay: () -> Unit, modifier: Modifier = Modifier) {
    val station = playback.station ?: return
    val colors = AirwavesTheme.colors
    val nowPlayingDescription =
        stringResource(R.string.player_now_playing, station.name) + ", " + stringResource(R.string.player_opens_player)
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .padding(horizontal = Spacing.xs)
            .shadow(12.dp, RoundedCornerShape(Radius.card), ambientColor = colors.textPrimary.copy(alpha = 0.1f))
            .background(colors.surface, RoundedCornerShape(Radius.card))
            .border(0.5.dp, colors.border, RoundedCornerShape(Radius.card))
            .clickable(onClick = onOpen)
            .semantics { contentDescription = nowPlayingDescription }
            .padding(start = Spacing.xs, end = Spacing.xxs, top = Spacing.xs, bottom = Spacing.xs),
    ) {
        StationArtwork(station, Modifier.size(40.dp), cornerRadius = Radius.small)
        Spacer(Modifier.size(Spacing.s))
        Column(Modifier.weight(1f)) {
            Text(
                station.name,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = colors.textPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                playback.trackTitle ?: playback.statusText(),
                style = MaterialTheme.typography.bodySmall,
                color = if (playback.status == Playback.Status.Failed) colors.danger else colors.textSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        PlayPauseButton(playback, size = 44.dp, filled = false, onClick = onTogglePlay)
    }
}

@Composable
fun PlayPauseButton(playback: Playback, size: Dp, filled: Boolean, onClick: () -> Unit) {
    val colors = AirwavesTheme.colors
    val haptics = LocalHapticFeedback.current
    val tint = if (filled) colors.onAccent else colors.textPrimary
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .size(size)
            .then(if (filled) Modifier.background(colors.accent, CircleShape) else Modifier)
            .clickable(
                onClickLabel = stringResource(if (playback.isActive) R.string.player_pause else R.string.player_play),
                onClick = {
                    haptics.performHapticFeedback(HapticFeedbackType.ContextClick)
                    onClick()
                },
            ),
    ) {
        AnimatedContent(
            targetState = when {
                playback.status == Playback.Status.Loading -> 0
                playback.isActive -> 1
                else -> 2
            },
            transitionSpec = { fadeIn() togetherWith fadeOut() },
            label = "playPause",
        ) { state ->
            when (state) {
                0 -> CircularProgressIndicator(color = tint, strokeWidth = 2.5.dp, modifier = Modifier.size(size * 0.4f))
                1 -> Icon(painterResource(R.drawable.ic_pause), stringResource(R.string.player_pause), tint = tint, modifier = Modifier.size(size * 0.45f))
                else -> Icon(painterResource(R.drawable.ic_play), stringResource(R.string.player_play), tint = tint, modifier = Modifier.size(size * 0.45f))
            }
        }
    }
}

/** Celoobrazovkový prehrávač. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NowPlayingSheet(
    playback: Playback,
    isFavorite: Boolean,
    onDismiss: () -> Unit,
    onTogglePlay: () -> Unit,
    onNext: () -> Unit,
    onPrevious: () -> Unit,
    onToggleFavorite: () -> Unit,
) {
    val station = playback.station ?: return
    val colors = AirwavesTheme.colors
    val haptics = LocalHapticFeedback.current
    val artworkScale by animateFloatAsState(
        if (playback.status == Playback.Status.Playing) 1f else 0.94f,
        spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessLow),
        label = "artwork",
    )

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = colors.background,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.fillMaxWidth().navigationBarsPadding().padding(bottom = Spacing.l),
        ) {
            Text(
                stringResource(R.string.player_live).uppercase(),
                style = MaterialTheme.typography.labelMedium,
                color = colors.textSecondary,
                letterSpacing = MaterialTheme.typography.labelMedium.letterSpacing * 2,
            )
            Spacer(Modifier.size(Spacing.l))
            StationArtwork(
                station = station,
                cornerRadius = Radius.artworkLarge,
                modifier = Modifier
                    .padding(horizontal = Spacing.xl)
                    .widthIn(max = 320.dp)
                    .fillMaxWidth()
                    .scale(artworkScale)
                    .shadow(24.dp, RoundedCornerShape(Radius.artworkLarge)),
            )
            Spacer(Modifier.size(Spacing.xl))
            Row(
                verticalAlignment = Alignment.Top,
                modifier = Modifier.fillMaxWidth().padding(horizontal = Spacing.l),
            ) {
                Column(Modifier.weight(1f)) {
                    Text(
                        station.name,
                        style = MaterialTheme.typography.titleLarge,
                        color = colors.textPrimary,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        playback.trackTitle ?: station.tags.replaceFirstChar { it.uppercase() },
                        style = MaterialTheme.typography.bodyLarge,
                        color = colors.textSecondary,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        playback.statusText(),
                        style = MaterialTheme.typography.bodySmall,
                        color = if (playback.status == Playback.Status.Failed) colors.danger else colors.textTertiary,
                        maxLines = 1,
                    )
                }
                IconButton(onClick = {
                    haptics.performHapticFeedback(HapticFeedbackType.ContextClick)
                    onToggleFavorite()
                }) {
                    Icon(
                        painterResource(if (isFavorite) R.drawable.ic_star else R.drawable.ic_star_outline),
                        contentDescription = stringResource(if (isFavorite) R.string.favorites_remove else R.string.favorites_add),
                        tint = if (isFavorite) colors.accent else colors.textSecondary,
                        modifier = Modifier.size(28.dp),
                    )
                }
            }
            Spacer(Modifier.size(Spacing.xl))
            Row(
                horizontalArrangement = Arrangement.spacedBy(Spacing.xl),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SkipButton(R.drawable.ic_skip_previous, stringResource(R.string.player_previous), playback.canSkip, onPrevious)
                PlayPauseButton(playback, size = 76.dp, filled = true, onClick = onTogglePlay)
                SkipButton(R.drawable.ic_skip_next, stringResource(R.string.player_next), playback.canSkip, onNext)
            }
        }
    }
}

@Composable
private fun SkipButton(icon: Int, description: String, enabled: Boolean, onClick: () -> Unit) {
    IconButton(onClick = onClick, enabled = enabled, modifier = Modifier.size(64.dp)) {
        Icon(
            painterResource(icon),
            description,
            tint = AirwavesTheme.colors.textPrimary.copy(alpha = if (enabled) 1f else 0.3f),
            modifier = Modifier.size(36.dp),
        )
    }
}
