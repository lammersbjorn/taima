package nl.taima.room;
import androidx.annotation.NonNull;
import androidx.room.*;
@Entity(tableName="bag", indices={@Index(value={"collected_on"},name="bag_collected",orders={Index.Order.DESC})})
public class BagRow {
    @PrimaryKey @NonNull public String id = "";
    @ColumnInfo(name="collected_on") public double collectedOn;
    @NonNull public String body = "";
}
