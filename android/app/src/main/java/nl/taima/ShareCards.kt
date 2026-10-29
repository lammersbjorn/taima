package nl.taima

import android.content.Context
import android.content.Intent
import android.graphics.*
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import androidx.core.content.FileProvider
import com.google.gson.JsonObject
import java.io.File

object ShareCards {
    /** An allowlist: codes, price, shop, notes and usage never enter the card. */
    fun itemLines(context:Context,bag:JsonObject):List<String> = buildList {
        add(bag.text("name"));bag.text("producer").takeIf(String::isNotBlank)?.let(::add)
        listOf("thc" to "THC","cbd" to "CBD").forEach {(key,label) ->bag.getAsJsonObject(key)?.number("percent")?.let {add("$label ${number(it)}%")}}
        bag.number("grams")?.let {add(amountLabel(context,bag,it))}
        if(isEdible(bag)) bag.number("thcMilligrams")?.let {add("${context.getString(R.string.thc_per_piece)}: ${number(it)} mg")}
        bag.text("strainType").takeIf(String::isNotBlank)?.let {add(context.coreText(it.replaceFirstChar(Char::uppercase)))}
        (bag.number("score") ?: bag.number("rating")?.times(2))?.let {add("${number(it)} / 10")}
        listOf("effects","flavors").forEach {key ->bag.array(key).take(5).map {context.coreText(it.asString)}.joinToString(" · ").takeIf(String::isNotBlank)?.let(::add)}
        bag.text("packedOn").takeIf(String::isNotBlank)?.let {add("${context.getString(R.string.packed)}: ${date(it)}")}
    }
    fun renderItem(context:Context,bag:JsonObject):File {
        val photo=BagDatabase(context).use {db ->Domain.view(bag).text("mainPhoto").takeIf(String::isNotBlank)?.let(db::photo)}
        return render(context,"Taima-item.png",itemLines(context,bag),photo)
    }
    private fun render(context:Context,name:String,lines:List<String>,photo:ByteArray?=null):File {
        val paint=TextPaint(Paint.ANTI_ALIAS_FLAG).apply {color=Color.rgb(24,32,24);textSize=48f;typeface=Typeface.create("sans-serif",Typeface.NORMAL)}
        fun layout(line:String)=StaticLayout.Builder.obtain(line,0,line.length,paint,920).setAlignment(Layout.Alignment.ALIGN_NORMAL).setIncludePad(false).build()
        val layouts=(listOf(context.getString(R.string.app_name))+lines).map {layout(it)}
        val bitmap=Bitmap.createBitmap(1080,200+layouts.sumOf {it.height+42}+(if(photo!=null) 600 else 0),Bitmap.Config.ARGB_8888)
        try {
            val canvas=Canvas(bitmap);canvas.drawColor(Color.rgb(248,250,246));var y=80f
            if(photo!=null) {
                val image=Photos.decode(photo)
                try {val scale=minOf(920f/image.width,560f/image.height);canvas.drawBitmap(image,null,RectF(80f,y,80f+image.width*scale,y+image.height*scale),null)} finally {image.recycle()}
                y+=600
            }
            layouts.forEach {text ->canvas.save();canvas.translate(80f,y);text.draw(canvas);canvas.restore();y+=text.height+42}
            val folder=File(context.cacheDir,"share").apply {mkdirs()}
            return File(folder,name).also {file ->file.outputStream().use {check(bitmap.compress(Bitmap.CompressFormat.PNG,100,it))}}
        } finally {bitmap.recycle()}
    }
    fun send(context:Context,file:File) {
        val uri=FileProvider.getUriForFile(context,"${context.packageName}.files",file)
        context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("image/png").putExtra(Intent.EXTRA_STREAM,uri).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),context.getString(R.string.share_card)))
    }
    fun share(context:Context,year:JsonObject) {
        val lines=listOf(year.text("year"),"${year.number("count")!!.toInt()} ${context.getString(R.string.collection)}", "${number(year.number("grams"))} g", "${year.number("strains")!!.toInt()} ${context.getString(R.string.strains)}", "${year.number("growers")!!.toInt()} ${context.getString(R.string.growers)}",year.text("favourite"),year.text("topGrower")).filter(String::isNotBlank)
        send(context,render(context,"Taima-year.png",lines))
    }
}
