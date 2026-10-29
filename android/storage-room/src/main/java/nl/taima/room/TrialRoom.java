package nl.taima.room;
import androidx.room.*;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;
@Database(entities={BagRow.class, ProducerRow.class, WishRow.class},version=2,exportSchema=true)
public abstract class TrialRoom extends RoomDatabase {
    public abstract TrialDao bags();
    public static final Migration V1_V2 = new Migration(1,2) {
        @Override public void migrate(SupportSQLiteDatabase db) {
            db.execSQL("CREATE TABLE IF NOT EXISTS wishlist (key TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL, added_at REAL NOT NULL)");
        }
    };
}
