package nl.taima.room;
import androidx.annotation.NonNull;
import androidx.room.*;
@Entity(tableName="producer_key")
public class ProducerRow { @PrimaryKey @NonNull public String key=""; @NonNull public String producer=""; }
