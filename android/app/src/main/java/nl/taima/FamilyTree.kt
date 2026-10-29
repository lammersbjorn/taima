package nl.taima

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.google.gson.JsonObject

/** Branches use measured node positions so text and tap targets can grow with font scale. */
@Composable internal fun FamilyTree(data: JsonObject, select:(String)->Unit) {
    val strain=data.getAsJsonObject("strain") ?: return
    val parents=strain.array("parents").map {it.asString}
    val children=data.array("children").map {it.asJsonObject.text("name")}
    val ancestors=data.array("ancestors").map {it.asJsonObject}
    val bounds=remember(data) {mutableStateMapOf<String,Rect>()}
    var origin by remember {mutableStateOf(Offset.Zero)}
    val line=MaterialTheme.colorScheme.outline
    Box(Modifier.fillMaxWidth().onGloballyPositioned {origin=it.boundsInRoot().topLeft}) {
        Canvas(Modifier.matchParentSize()) {
            fun connect(a:String,b:String) {
                val from=bounds[a] ?: return;val to=bounds[b] ?: return
                val start=Offset(from.center.x,from.bottom)-origin;val end=Offset(to.center.x,to.top)-origin
                val mid=(start.y+end.y)/2
                drawLine(line,start,Offset(start.x,mid),2.dp.toPx());drawLine(line,Offset(start.x,mid),Offset(end.x,mid),2.dp.toPx());drawLine(line,Offset(end.x,mid),end,2.dp.toPx())
            }
            ancestors.forEachIndexed {i,parent ->parent.array("parents").forEachIndexed {j,_ ->connect("g$i-$j","p$i")}}
            parents.indices.forEach {connect("p$it","self")}
            children.indices.forEach {connect("self","c$it")}
        }
        @Composable fun node(id:String,name:String,current:Boolean=false) {
            if(current) FilledTonalButton(onClick={},enabled=false,modifier=Modifier.onGloballyPositioned {bounds[id]=it.boundsInRoot()}) {Text(name)}
            else OutlinedButton(onClick={select(name)},modifier=Modifier.onGloballyPositioned {bounds[id]=it.boundsInRoot()}) {Text(name)}
        }
        Column(verticalArrangement=Arrangement.spacedBy(32.dp)) {
            if(ancestors.any {it.array("parents").isNotEmpty()}) {
                Text(stringResource(R.string.grandparents),style=MaterialTheme.typography.titleSmall)
                FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp)) {ancestors.forEachIndexed {i,parent ->parent.array("parents").forEachIndexed {j,n ->node("g$i-$j",n.asString)}}}
            }
            if(parents.isNotEmpty()) {
                Text(stringResource(R.string.parents),style=MaterialTheme.typography.titleSmall)
                FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp)) {parents.forEachIndexed {i,n ->node("p$i",n)}}
            }
            FlowRow {node("self",strain.text("name"),true)}
            if(children.isNotEmpty()) {
                FlowRow(horizontalArrangement=Arrangement.spacedBy(8.dp)) {children.forEachIndexed {i,n ->node("c$i",n)}}
                Text(stringResource(R.string.children),style=MaterialTheme.typography.titleSmall)
            }
        }
    }
    if(parents.isEmpty() && children.isEmpty()) Text(stringResource(R.string.no_lineage))
}
