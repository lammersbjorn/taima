package nl.taima

import android.content.Context
import android.content.Intent
import android.graphics.*
import androidx.core.content.FileProvider
import com.google.gson.JsonObject
import java.io.File

object ShareCards {
    fun share(context: Context,year: JsonObject) {
        val bitmap=Bitmap.createBitmap(1080,1350,Bitmap.Config.ARGB_8888)
        val canvas=Canvas(bitmap);canvas.drawColor(Color.rgb(248,250,246))
        val paint=Paint(Paint.ANTI_ALIAS_FLAG).apply {color=Color.rgb(27,122,71);textSize=72f;typeface=Typeface.create("sans-serif-medium",Typeface.NORMAL)}
        canvas.drawText(context.getString(R.string.app_name),80f,160f,paint)
        canvas.drawText(year.text("year"),80f,270f,paint)
        paint.color=Color.rgb(24,32,24);paint.textSize=48f
        listOf("${year.number("count")!!.toInt()} ${context.getString(R.string.collection)}", "${number(year.number("grams"))} g", "${year.number("strains")!!.toInt()} ${context.getString(R.string.strains)}", "${year.number("growers")!!.toInt()} ${context.getString(R.string.growers)}").forEachIndexed { i,line ->canvas.drawText(line,80f,470f+i*130,paint)}
        val folder=File(context.cacheDir,"share").apply {mkdirs()};val file=File(folder,"Taima-year.png")
        file.outputStream().use {bitmap.compress(Bitmap.CompressFormat.PNG,100,it)};bitmap.recycle()
        val uri=FileProvider.getUriForFile(context,"${context.packageName}.files",file)
        context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("image/png").putExtra(Intent.EXTRA_STREAM,uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),context.getString(R.string.share_card)))
    }
}
