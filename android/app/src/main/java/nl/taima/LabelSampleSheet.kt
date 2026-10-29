package nl.taima

import android.content.Intent
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource

/** Opt-in offer, then preview, then an explicit system sharesheet action. */
@Composable internal fun LabelSampleSheet(sample:String,dismiss:()->Unit) {
    val context=LocalContext.current
    AlertDialog(onDismissRequest=dismiss,title={Text(context.coreText("Corrections"))},text={Column(Modifier.verticalScroll(rememberScrollState())) {
        Text(stringResource(R.string.sample_help));Text(sample)
    }},confirmButton={TaimaTextButton(onClick={context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT,sample),context.getString(R.string.share_card)))}) {Text(context.coreText("Share"))}},dismissButton={TaimaTextButton(onClick=dismiss) {Text(stringResource(R.string.done))}})
}
