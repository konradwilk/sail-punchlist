// SPDX-License-Identifier: BSD-3-Clause
package com.sailpunchlist.app

import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.time.Instant

class SailStore(directory: File, val lists: JSONObject) {
    private val file = AtomicFile(File(directory, "native-sail.json"))
    var state: JSONObject = if (file.baseFile.exists() || File(directory, "native-sail.json.bak").exists()) {
        JSONObject(file.openRead().bufferedReader().use { it.readText() }).also { validate(it) }
    } else JSONObject().put("version", 1).put("phase", "pre").put("lastHours", JSONObject.NULL)
        .put("drafts", JSONObject().put("pre", emptyDraft()).put("post", emptyDraft())).put("records", JSONArray())
        private set
    val phase: String get() = state.getString("phase")
    val draft: JSONObject get() = state.getJSONObject("drafts").getJSONObject(phase)
    val records: JSONArray get() = state.getJSONArray("records")
    fun switchPhase(phase: String) { state.put("phase", phase); save() }
    fun save() {
        val bytes = state.toString(2).toByteArray(Charsets.UTF_8)
        val output = file.startWrite()
        try { output.write(bytes); file.finishWrite(output) }
        catch (e: Exception) { file.failWrite(output); throw e }
    }
    fun json(): String = state.toString(2)
    fun csv(): String = buildString {
        fun row(values: List<String>) { append(values.joinToString(",") { "\"" + it.replace("\"", "\"\"") + "\"" }); append("\r\n") }
        row(listOf("CompletedAt","Phase","FuelPercent","EngineHours","Item","Status","Note"))
        for (record in records.objects()) for (item in record.getJSONArray("items").objects()) {
            row(listOf(record.getString("date"), if (record.getString("phase") == "pre") "Pre-Sail" else "Post-Sail",
                record.get("fuel").toString(),record.get("hours").toString(),item.getString("label"),item.getString("status"),item.getString("note")))
        }
    }
    fun complete() {
        val items = JSONArray()
        for (group in lists.getJSONArray(phase).objects()) for (item in group.getJSONArray("items").objects()) {
            val answer = draft.getJSONObject("answers").optJSONObject(item.getString("id"))
            require(answer != null && answer.optString("status") in listOf("done", "issue")) { "Mark every item Done or Issue." }
            items.put(JSONObject().put("label", item.getString("label")).put("status", answer.getString("status"))
                .put("note", if (answer.getString("status") == "issue") answer.getString("note") else ""))
        }
        val fuel = draft.getString("fuel").toDoubleOrNull()
        val hours = draft.getString("hours").toDoubleOrNull()
        require(fuel != null && fuel.isFinite() && fuel in 0.0..100.0) { "Enter fuel from 0 to 100 percent." }
        require(hours != null && hours.isFinite() && hours >= 0) { "Enter valid engine hours." }
        require(state.isNull("lastHours") || hours >= state.getDouble("lastHours")) { "Engine hours cannot be below the last recorded reading." }
        val previous = state.toString()
        try {
            records.put(JSONObject().put("phase", phase).put("date", Instant.now().toString()).put("fuel", fuel).put("hours", hours).put("items", items))
            val previousSuggestion = if (state.isNull("lastHours")) "" else (state.getDouble("lastHours") + 1).toString()
            state.put("lastHours", hours)
            val next = if (phase == "pre") "post" else "pre"
            state.getJSONObject("drafts").put(phase, emptyDraft((hours + 1).toString()))
            val nextDraft = state.getJSONObject("drafts").getJSONObject(next)
            if (nextDraft.getString("hours").isBlank() || nextDraft.getString("hours") == previousSuggestion) nextDraft.put("hours", (hours + 1).toString())
            state.put("phase", next)
            save()
        } catch (e: Exception) { state = JSONObject(previous); throw e }
    }
    private fun validate(s: JSONObject) {
        require(s.getInt("version") == 1 && s.getString("phase") in listOf("pre", "post")) { "Unrecognized sail log." }
        if (!s.isNull("lastHours")) require(s.getDouble("lastHours").let { it.isFinite() && it >= 0 })
        for (phase in listOf("pre", "post")) {
            val d = s.getJSONObject("drafts").getJSONObject(phase)
            require(d.get("hours") is String && d.get("fuel") is String)
            val answers = d.getJSONObject("answers")
            for (key in answers.keys()) {
                val a = answers.getJSONObject(key)
                require(a.getString("status") in listOf("done", "issue") && a.get("note") is String)
            }
        }
        for (r in s.getJSONArray("records").objects()) {
            require(r.getString("phase") in listOf("pre", "post"))
            Instant.parse(r.getString("date"))
            require(r.getDouble("fuel").let { it.isFinite() && it in 0.0..100.0 })
            require(r.getDouble("hours").let { it.isFinite() && it >= 0 })
            for (i in r.getJSONArray("items").objects()) {
                require(i.get("label") is String && i.get("note") is String && i.getString("status") in listOf("done", "issue"))
            }
        }
    }
    companion object {
        private fun emptyDraft(hours: String = "") = JSONObject().put("answers", JSONObject()).put("fuel", "").put("hours", hours)
    }
}
fun JSONArray.objects(): List<JSONObject> = (0 until length()).map { getJSONObject(it) }
