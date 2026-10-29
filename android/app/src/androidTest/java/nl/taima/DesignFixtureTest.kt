package nl.taima

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.google.gson.*
import org.junit.Test
import org.junit.Assert.*
import org.junit.runner.RunWith
import java.time.Instant
import java.time.temporal.ChronoUnit

/** Opt-in local visual fixture. Never included in the application APK. */
@RunWith(AndroidJUnit4::class)
class DesignFixtureTest {
    @Test fun seedSyntheticCollection() {
        val args=InstrumentationRegistry.getArguments()
        org.junit.Assume.assumeTrue("Only seed a disposable, owned emulator",args.getString("designFixture")=="true")
        val context=InstrumentationRegistry.getInstrumentation().targetContext
        val core=Core(context)
        val names=listOf("Northern Lights","Lemon Haze","Blue Dream","Moroccan Gold","Rosin No. 4","Evening Bites","White Widow","Purple Sunset")
        val forms=listOf("bag","jar","preroll","hash","rosin","edible","bag","jar")
        val growers=listOf("North Garden","Glasshouse","North Garden","Atlas Works","Glasshouse","Kitchen Lab","Atlas Works","North Garden")
        val now=Instant.now().truncatedTo(ChronoUnit.SECONDS)
        BagDatabase(context).use {db ->
            db.eraseAll()
            names.forEachIndexed {i,name ->
                val id="00000000-0000-4000-8000-${(i+100).toString().padStart(12,'0')}"
                val photo="00000000-0000-4000-8000-${(i+200).toString().padStart(12,'0')}.heic"
                val log=JsonArray()
                if(i!=5) repeat(if(i==0) 5 else 2) {j ->log.add(obj("id" to java.util.UUID.randomUUID().toString(),"date" to now.minus((j*2+i).toLong(),ChronoUnit.DAYS).toString(),"grams" to 0.25,"method" to if(i==4) "dab" else "vape","note" to "Synthetic session"))}
                val bag=core.call("bag.new").asJsonObject.apply {
                    addProperty("id",id);addProperty("name",name);addProperty("producer",growers[i]);addProperty("productForm",forms[i]);addProperty("grams",if(i==5) 10.0 else 5.0)
                    addProperty("collectedOn",now.minus((i*23).toLong(),ChronoUnit.DAYS).toString())
                    addProperty("stockState",if(i==0) "open" else if(i==7) "empty" else "full")
                    addProperty("remainingGrams",if(i==0) 3.75 else if(i==7) 0.0 else 5.0)
                    if(i==5) addProperty("thcMilligrams",5.0) else add("thc",obj("percent" to if(i==3) 38.0 else if(i==4) 65.0 else 18.5+i,"isUpperBound" to false))
                    addProperty("priceEuros",35+i*2);addProperty("photoName",photo);add("usageLog",log)
                }
                db.put(bag)
                val bitmap=Bitmap.createBitmap(360,440,Bitmap.Config.ARGB_8888)
                val canvas=Canvas(bitmap);val paint=Paint(Paint.ANTI_ALIAS_FLAG)
                canvas.drawColor(Color.rgb(219-i*5,221-i*4,212-i*3))
                paint.color=Color.rgb(247,246,239);canvas.drawRoundRect(35f,26f,325f,414f,18f,18f,paint)
                paint.color=Color.rgb(48,68,52);canvas.drawRect(55f,52f,305f,140f,paint)
                paint.color=Color.WHITE;paint.textSize=20f;paint.isFakeBoldText=true;canvas.drawText("SYNTHETIC",72f,105f,paint)
                paint.color=Color.DKGRAY;paint.textSize=25f;canvas.drawText(name.substringBefore(" "),56f,205f,paint)
                paint.textSize=20f;paint.isFakeBoldText=false;canvas.drawText(name.substringAfter(" ",""),56f,238f,paint)
                paint.textSize=14f;canvas.drawText(growers[i],56f,285f,paint);canvas.drawText("LOCAL DESIGN FIXTURE",56f,366f,paint)
                val bytes=java.io.ByteArrayOutputStream().also {bitmap.compress(Bitmap.CompressFormat.JPEG,90,it)}.toByteArray();bitmap.recycle();db.putPhoto(photo,bytes)
            }
            assertEquals(8,db.all().size)
            assertEquals(8,db.photos().size)
            val d=core.call("dashboard","bags" to db.all()).asJsonObject
            assertTrue(d.number("sessions")!!>0)
        }
        context.getSharedPreferences("taima",0).edit().putString("inUse","00000000-0000-4000-8000-000000000100").putInt("onboarding.build",BuildConfig.VERSION_CODE).putString("party.names","Sam, Alex, Robin").commit()
    }
}
