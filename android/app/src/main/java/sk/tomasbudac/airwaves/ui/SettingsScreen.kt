package sk.tomasbudac.airwaves.ui

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import sk.tomasbudac.airwaves.BuildConfigInfo
import sk.tomasbudac.airwaves.R
import sk.tomasbudac.airwaves.ui.components.PrimaryButton
import sk.tomasbudac.airwaves.ui.theme.Radius
import sk.tomasbudac.airwaves.ui.theme.AirwavesTheme
import sk.tomasbudac.airwaves.ui.theme.Spacing

@Composable
fun SettingsScreen(viewModel: SettingsViewModel, contentPadding: PaddingValues) {
    val colors = AirwavesTheme.colors
    val context = LocalContext.current
    val resources = LocalResources.current
    val focusManager = LocalFocusManager.current
    val scope = rememberCoroutineScope()
    var alert by remember { mutableStateOf<Pair<String, String>?>(null) }
    var name by rememberSaveable { mutableStateOf("") }
    var url by rememberSaveable { mutableStateOf("") }
    val isValid = name.isNotBlank() && SettingsViewModel.isValidStreamUrl(url)

    val exportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        scope.launch {
            val ok = runCatching {
                withContext(Dispatchers.IO) {
                    context.contentResolver.openOutputStream(uri)?.use { it.write(viewModel.exportJson().toByteArray()) }
                }
            }.isSuccess
            alert = if (ok) resources.getString(R.string.backup_exported_title) to resources.getString(R.string.backup_exported_message)
            else resources.getString(R.string.backup_export_failed_title) to resources.getString(R.string.backup_export_failed_message)
        }
    }
    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        uri ?: return@rememberLauncherForActivityResult
        scope.launch {
            val text = runCatching {
                withContext(Dispatchers.IO) { context.contentResolver.openInputStream(uri)?.use { it.readBytes().decodeToString() } }
            }.getOrNull()
            val added = text?.let(viewModel::import)
            alert = when {
                added == null -> resources.getString(R.string.backup_invalid_title) to resources.getString(R.string.backup_invalid_message)
                added == 0 -> resources.getString(R.string.backup_imported_title) to resources.getString(R.string.backup_imported_none)
                else -> resources.getString(R.string.backup_imported_title) to resources.getString(R.string.backup_imported_count, added.toString())
            }
        }
    }

    Column(
        Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(bottom = contentPadding.calculateBottomPadding() + Spacing.m),
    ) {
        LargeHeader("Nastavenia")

        SectionTitle(stringResource(R.string.settings_backup_header))
        Card {
            SettingsRow(R.drawable.ic_upload, stringResource(R.string.settings_export)) { exportLauncher.launch("airwaves-favorites.json") }
            HorizontalDivider(color = colors.border, modifier = Modifier.padding(start = 52.dp))
            SettingsRow(R.drawable.ic_download, stringResource(R.string.settings_import)) {
                importLauncher.launch(arrayOf("application/json", "text/plain", "application/octet-stream"))
            }
        }
        Footer(stringResource(R.string.settings_backup_footer))

        SectionTitle(stringResource(R.string.settings_manual_header))
        Card {
            Column(Modifier.padding(Spacing.m), verticalArrangement = Arrangement.spacedBy(Spacing.s)) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text(stringResource(R.string.settings_manual_name)) },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next),
                    colors = fieldColors(),
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = url,
                    onValueChange = { url = it },
                    label = { Text(stringResource(R.string.settings_manual_url)) },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri, imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = { focusManager.clearFocus() }),
                    colors = fieldColors(),
                    modifier = Modifier.fillMaxWidth(),
                )
                PrimaryButton(
                    text = stringResource(R.string.favorites_add),
                    enabled = isValid,
                    modifier = Modifier.fillMaxWidth(),
                    onClick = {
                        viewModel.addManual(name, url)?.let { station ->
                            focusManager.clearFocus()
                            name = ""
                            url = ""
                            alert = resources.getString(R.string.favorites_added_title) to resources.getString(R.string.favorites_added_message, station.name)
                        }
                    },
                )
            }
        }
        Footer(stringResource(R.string.settings_manual_footer))

        SectionTitle(stringResource(R.string.voice_header))
        Card {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(Spacing.m),
            ) {
                Icon(painterResource(R.drawable.ic_mic), null, tint = colors.textPrimary, modifier = Modifier.size(22.dp))
                Spacer(Modifier.width(Spacing.m))
                Text(
                    stringResource(
                        R.string.voice_assistant_footer,
                        stringResource(R.string.voice_example),
                        stringResource(R.string.app_name),
                    ),
                    color = colors.textPrimary,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }

        SectionTitle(stringResource(R.string.settings_about_header))
        Card {
            SettingsRow(R.drawable.ic_public, stringResource(R.string.settings_database), detail = "radio-browser.info") {
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.radio-browser.info")))
            }
            HorizontalDivider(color = colors.border, modifier = Modifier.padding(start = 52.dp))
            SettingsRow(R.drawable.ic_settings, stringResource(R.string.settings_version), detail = BuildConfigInfo.versionName(context), onClick = null)
        }
    }

    alert?.let { (title, message) ->
        AlertDialog(
            onDismissRequest = { alert = null },
            confirmButton = { TextButton(onClick = { alert = null }) { Text(stringResource(R.string.action_ok)) } },
            title = { Text(title) },
            text = { Text(message) },
            containerColor = colors.surface,
        )
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text.uppercase(),
        style = MaterialTheme.typography.labelMedium,
        color = AirwavesTheme.colors.textSecondary,
        modifier = Modifier.padding(start = Spacing.l, end = Spacing.m, top = Spacing.l, bottom = Spacing.xs),
    )
}

@Composable
private fun Footer(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.bodySmall,
        color = AirwavesTheme.colors.textSecondary,
        modifier = Modifier.padding(horizontal = Spacing.l, vertical = Spacing.xs),
    )
}

@Composable
private fun Card(content: @Composable () -> Unit) {
    Column(
        Modifier
            .padding(horizontal = Spacing.m)
            .fillMaxWidth()
            .clip(RoundedCornerShape(Radius.card))
            .background(AirwavesTheme.colors.surface),
    ) { content() }
}

@Composable
private fun SettingsRow(icon: Int, title: String, detail: String? = null, onClick: (() -> Unit)?) {
    val colors = AirwavesTheme.colors
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = Spacing.m)
            .height(52.dp),
    ) {
        Icon(painterResource(icon), null, tint = colors.textPrimary, modifier = Modifier.size(22.dp))
        Spacer(Modifier.width(Spacing.m))
        Text(title, color = colors.textPrimary, modifier = Modifier.weight(1f))
        detail?.let { Text(it, color = colors.textSecondary, style = MaterialTheme.typography.bodyMedium) }
    }
}

@Composable
private fun fieldColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = AirwavesTheme.colors.accent,
    unfocusedBorderColor = AirwavesTheme.colors.border,
    focusedLabelColor = AirwavesTheme.colors.textPrimary,
    cursorColor = AirwavesTheme.colors.accent,
)
