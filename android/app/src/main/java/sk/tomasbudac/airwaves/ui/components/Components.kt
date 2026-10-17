package sk.tomasbudac.airwaves.ui.components

import androidx.annotation.DrawableRes
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import java.util.concurrent.ConcurrentHashMap
import sk.tomasbudac.airwaves.data.Station
import sk.tomasbudac.airwaves.data.iconCandidates
import sk.tomasbudac.airwaves.ui.theme.Radius
import sk.tomasbudac.airwaves.ui.theme.AirwavesTheme
import sk.tomasbudac.airwaves.ui.theme.Spacing

/** Výsledok hľadania loga podľa rádia – index kandidáta, ktorý funguje (-1 = žiadny). */
private val resolvedIcons = ConcurrentHashMap<String, Int>()

/** Menšie ikony (napr. 16px favicon) by boli rozmazané. */
private const val MIN_ICON_PX = 40

/** Logo rádia. Kým sa nenačíta (alebo ak žiadne nie je), ukazuje iniciály na neutrálnom pozadí. */
@Composable
fun StationArtwork(
    station: Station,
    modifier: Modifier = Modifier,
    cornerRadius: Dp = Radius.control,
) {
    val colors = AirwavesTheme.colors
    val key = "${station.id}|${station.favicon}|${station.homepage}"
    val candidates = remember(key) { station.iconCandidates() }
    var index by remember(key) { mutableIntStateOf(resolvedIcons[key] ?: 0) }
    var isLoaded by remember(key) { mutableStateOf(false) }
    val shape = RoundedCornerShape(cornerRadius)

    BoxWithConstraints(
        modifier = modifier
            .aspectRatio(1f)
            .clip(shape)
            .background(colors.surfaceMuted)
            .border(0.5.dp, colors.border, shape),
        contentAlignment = Alignment.Center,
    ) {
        val side = maxWidth
        if (!isLoaded) {
            Text(
                text = station.initials,
                color = colors.textSecondary,
                fontWeight = FontWeight.SemiBold,
                style = MaterialTheme.typography.titleMedium.copy(
                    fontSize = with(LocalDensity.current) { (side * 0.34f).toSp() },
                ),
                maxLines = 1,
            )
        }
        if (index in candidates.indices) {
            AsyncImage(
                model = candidates[index],
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = Modifier.fillMaxSize().padding(side * 0.12f),
                onSuccess = { state ->
                    val image = state.result.image
                    if (minOf(image.width, image.height) >= MIN_ICON_PX) {
                        resolvedIcons[key] = index
                        isLoaded = true
                    } else {
                        index += 1
                    }
                },
                onError = {
                    index += 1
                    if (index >= candidates.size) resolvedIcons[key] = -1
                },
            )
        }
    }
}

/** Animovaný ekvalizér – znak, že rádio práve hrá. */
@Composable
fun EqualizerBars(
    isAnimating: Boolean,
    modifier: Modifier = Modifier,
    color: Color = AirwavesTheme.colors.accent,
) {
    val transition = rememberInfiniteTransition(label = "equalizer")
    val durations = listOf(420, 560, 380, 640)
    val rest = listOf(0.4f, 0.7f, 0.55f, 0.35f)
    Row(
        modifier = modifier.size(width = 18.dp, height = 14.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
        verticalAlignment = Alignment.Bottom,
    ) {
        durations.forEachIndexed { index, duration ->
            val fraction = if (isAnimating) {
                transition.animateFloat(
                    initialValue = 0.2f,
                    targetValue = 1f,
                    animationSpec = infiniteRepeatable(tween(duration), RepeatMode.Reverse),
                    label = "bar$index",
                ).value
            } else {
                rest[index]
            }
            Box(
                Modifier
                    .width(3.dp)
                    .fillMaxHeight(fraction)
                    .clip(RoundedCornerShape(2.dp))
                    .background(color),
            )
        }
    }
}

@Composable
fun EmptyState(
    @DrawableRes icon: Int,
    title: String,
    message: String,
    modifier: Modifier = Modifier,
    action: (@Composable () -> Unit)? = null,
) {
    val colors = AirwavesTheme.colors
    Column(
        modifier = modifier.fillMaxWidth().padding(Spacing.xl),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(painterResource(icon), contentDescription = null, tint = colors.textTertiary, modifier = Modifier.size(48.dp))
        Spacer(Modifier.height(Spacing.m))
        Text(title, style = MaterialTheme.typography.titleMedium, color = colors.textPrimary, textAlign = TextAlign.Center)
        Spacer(Modifier.height(Spacing.xs))
        Text(message, style = MaterialTheme.typography.bodyMedium, color = colors.textSecondary, textAlign = TextAlign.Center)
        if (action != null) {
            Spacer(Modifier.height(Spacing.l))
            action()
        }
    }
}

@Composable
fun PrimaryButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier.height(48.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = AirwavesTheme.colors.accent,
            contentColor = AirwavesTheme.colors.onAccent,
        ),
        contentPadding = PaddingValues(horizontal = Spacing.l),
    ) {
        Text(text, style = MaterialTheme.typography.labelLarge)
    }
}
