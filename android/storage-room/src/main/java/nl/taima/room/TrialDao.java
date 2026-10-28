package nl.taima.room;
import androidx.room.*;
import java.util.List;
@Dao public interface TrialDao {
    @Insert(onConflict=OnConflictStrategy.REPLACE) void put(BagRow row);
    @Query("SELECT * FROM bag ORDER BY collected_on DESC") List<BagRow> all();
}
