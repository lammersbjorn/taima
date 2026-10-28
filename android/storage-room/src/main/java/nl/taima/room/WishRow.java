package nl.taima.room;
import androidx.annotation.NonNull;
import androidx.room.*;
@Entity(tableName="wishlist")
public class WishRow { @PrimaryKey @NonNull public String key=""; @NonNull public String name=""; @ColumnInfo(name="added_at") public double addedAt; }
