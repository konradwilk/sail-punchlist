// SPDX-License-Identifier: BSD-3-Clause
package com.sailpunchlist.app

import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.content.Context
import android.content.res.ColorStateList
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import kotlin.math.*
import android.graphics.Color
import android.os.Bundle
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.view.MotionEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.view.View
import android.view.WindowInsets
import android.widget.*
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

class MainActivity : Activity() {
    private lateinit var store: SailStore
    private lateinit var content: LinearLayout
    private lateinit var status: TextView
    private lateinit var scroll: ScrollView
    private var history = false
    private val green = Color.rgb(18, 102, 88)
    private val red = Color.rgb(179, 31, 31)
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
    private fun column() = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
    private fun text(value: String, heading: Boolean = false) = TextView(this).apply {
        text = value; textSize = if (heading) 20f else 16f
        setTextColor(Color.rgb(21, 62, 54)); setPadding(0, dp(8), 0, dp(8))
        if (heading) setTypeface(null, android.graphics.Typeface.BOLD)
    }
    private fun button(label: String, action: () -> Unit) = Button(this).apply {
        text = label; isAllCaps = false; minHeight = dp(48); setTextColor(green)
        setOnClickListener { action() }
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        history = savedInstanceState?.getBoolean("history") ?: false
        val root = column().apply { setBackgroundColor(Color.rgb(243, 245, 240)) }
        setContentView(root)
        root.setOnApplyWindowInsetsListener { view, insets ->
            if (android.os.Build.VERSION.SDK_INT >= 30) {
                val edges = insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.ime())
                view.setPadding(dp(20) + edges.left, edges.top, dp(20) + edges.right, edges.bottom)
            } else {
                @Suppress("DEPRECATION")
                view.setPadding(dp(20) + insets.systemWindowInsetLeft, insets.systemWindowInsetTop,
                    dp(20) + insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            }
            insets
        }
        root.requestApplyInsets()
        root.addView(text("Sail Punchlist", true))
        val navigation = LinearLayout(this)
        navigation.addView(button("Checklist") { history = false; render() }, LinearLayout.LayoutParams(0, -2, 1f))
        navigation.addView(button("History") { history = true; render() }, LinearLayout.LayoutParams(0, -2, 1f))
        root.addView(navigation)
        status = text("Saved on device").apply { accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE }
        root.addView(status)
        scroll = ScrollView(this).apply { isFillViewport = true }
        content = column(); scroll.addView(content); root.addView(scroll, LinearLayout.LayoutParams(-1, 0, 1f))
        try {
            val lists = JSONObject(assets.open("checklists.json").bufferedReader().use { it.readText() })
            store = SailStore(filesDir, lists)
            render()
        } catch (e: Exception) {
            status.text = "Cannot open the sail log. The saved file has not been changed.\n${e.message}"
            for (i in 0 until navigation.childCount) navigation.getChildAt(i).isEnabled = false
        }
    }
    override fun onSaveInstanceState(outState: Bundle) { outState.putBoolean("history", history); super.onSaveInstanceState(outState) }
    private fun persist() {
        try { store.save(); status.text = "Saved on device" }
        catch (e: Exception) { status.text = "Save failed: ${e.message}. Use Retry save below." }
    }
    private fun field(label: String, value: String, numeric: Boolean, change: (String) -> Unit): EditText {
        return EditText(this).apply {
            hint = label; contentDescription = label; setText(value); textSize = 18f; minHeight = dp(48)
            inputType = if (numeric) InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
                else InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES or InputType.TYPE_TEXT_FLAG_MULTI_LINE
            addTextChangedListener(object : TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) { change(s.toString()); persist() }
                override fun afterTextChanged(s: Editable?) {}
            })
        }
    }
    private fun render() {
        if (!::store.isInitialized) return
        (getSystemService(INPUT_METHOD_SERVICE) as android.view.inputmethod.InputMethodManager)
            .hideSoftInputFromWindow(content.windowToken, 0)
        content.removeAllViews(); scroll.scrollTo(0, 0)
        if (history) { showHistory(); return }
        val phases = RadioGroup(this).apply { orientation = RadioGroup.HORIZONTAL }
        for (phase in listOf("pre", "post")) {
            val radio = RadioButton(this).apply {
                id = View.generateViewId(); text = title(phase); minHeight = dp(48); isChecked = store.phase == phase
                setTextColor(if (isChecked) Color.WHITE else green)
                buttonTintList = ColorStateList.valueOf(if (isChecked) Color.WHITE else green)
                background = android.graphics.drawable.GradientDrawable().apply {
                    cornerRadius = dp(12).toFloat(); setColor(if (isChecked) green else Color.TRANSPARENT)
                }
            }
            phases.addView(radio, RadioGroup.LayoutParams(0, -2, 1f))
            radio.setOnClickListener {
                try { store.switchPhase(phase); status.text = "Saved on device" }
                catch (e: Exception) { status.text = "Save failed: ${e.message}" }
                render()
            }
        }
        content.addView(phases)
        for (group in store.lists.getJSONArray(store.phase).objects()) {
            content.addView(text(group.getString("title"), true))
            for (item in group.getJSONArray("items").objects()) {
                val key = item.getString("id")
                val answers = store.draft.getJSONObject("answers")
                val answer = answers.optJSONObject(key)
                val row = column().apply { setPadding(dp(12), dp(8), dp(12), dp(16)); setBackgroundColor(Color.WHITE) }
                row.addView(text(item.getString("label")))
                val choices = RadioGroup(this).apply { orientation = RadioGroup.HORIZONTAL; contentDescription = item.getString("label") }
                val done = RadioButton(this).apply { id = View.generateViewId(); text = "✓ Done"; setTextColor(green); buttonTintList = ColorStateList.valueOf(green); minHeight = dp(48); isChecked = answer?.optString("status") == "done" }
                val issue = RadioButton(this).apply { id = View.generateViewId(); text = "✕ Issue"; setTextColor(red); buttonTintList = ColorStateList.valueOf(red); minHeight = dp(48); isChecked = answer?.optString("status") == "issue" }
                choices.addView(done, RadioGroup.LayoutParams(0, -2, 1f)); choices.addView(issue, RadioGroup.LayoutParams(0, -2, 1f))
                row.addView(choices)
                val note = field("Issue note (optional)", answer?.optString("note") ?: "", false) {
                    answers.getJSONObject(key).put("note", it)
                }.apply { visibility = if (answer?.optString("status") == "issue") View.VISIBLE else View.GONE }
                row.addView(note)
                choices.setOnCheckedChangeListener { _, checked ->
                    val value = if (checked == done.id) "done" else "issue"
                    answers.put(key, JSONObject().put("status", value).put("note", note.text.toString()))
                    note.visibility = if (value == "issue") View.VISIBLE else View.GONE
                    persist()
                }
                content.addView(row, LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(12) })
            }
        }
        content.addView(text("Fuel and engine", true))
        content.addView(text("Fuel level (0–100%)"))
        val gauge = FuelGauge(this).apply { value = store.draft.getString("fuel").toFloatOrNull() ?: -1f }
        content.addView(gauge, LinearLayout.LayoutParams(-1, dp(210)))
        gauge.onChange = { value -> store.draft.put("fuel", value.toInt().toString()); persist() }
        content.addView(text("Drag the fuel dial to set the level."))
        content.addView(field("Engine hours", store.draft.getString("hours"), true) { store.draft.put("hours", it) })
        if (!store.state.isNull("lastHours")) content.addView(text("Last engine reading: ${store.state.getDouble("lastHours")} hrs"))
        content.addView(button("Complete ${title(store.phase)}") {
            try { store.complete(); render(); status.text = "Checklist completed and saved." }
            catch (e: Exception) { AlertDialog.Builder(this).setTitle("Could not complete").setMessage(e.message).setPositiveButton("OK", null).show() }
        })
        content.addView(button("Retry save") { persist() })
    }
    private fun showHistory() {
        content.addView(text("Sail history", true))
        content.addView(button("Export JSON") { exportHistory(false) })
        content.addView(button("Export CSV") { exportHistory(true) })
        if (store.records.length() == 0) content.addView(text("No completed checklists yet."))
        val formatter = DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM).withZone(ZoneId.systemDefault())
        for (record in store.records.objects().reversed()) {
            content.addView(text("${title(record.getString("phase"))} · ${formatter.format(Instant.parse(record.getString("date")))}", true))
            content.addView(text("${record.getDouble("fuel")}% fuel · ${record.getDouble("hours")} engine hrs"))
            val issues = record.getJSONArray("items").objects().filter { it.getString("status") == "issue" }
            if (issues.isEmpty()) content.addView(text("✓ No issues recorded"))
            for (item in issues) content.addView(text("✕ ${item.getString("label")}\n${item.getString("note").ifBlank { "No comment." }}"))
        }
    }
    private fun exportHistory(csv: Boolean) {
        startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = if (csv) "text/csv" else "application/json"
            putExtra(Intent.EXTRA_TITLE, if (csv) "sail-history.csv" else "sail-punchlist.json")
        }, if (csv) 2 else 1)
    }
    @Deprecated("Platform activity result callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode !in listOf(1,2) || resultCode != RESULT_OK) return
        try {
            val uri = requireNotNull(data?.data)
            requireNotNull(contentResolver.openOutputStream(uri, "wt")).bufferedWriter().use { it.write(if (requestCode == 2) store.csv() else store.json()) }
            status.text = "Export saved."
        } catch (e: Exception) { status.text = "Export failed: ${e.message}" }
    }
    private fun title(phase: String) = if (phase == "pre") "Pre-Sail" else "Post-Sail"
}

// Direct dial tracking, with equivalent accessibility adjustment.
class FuelGauge(context: Context) : View(context) {
    var value: Float = -1f
        set(value) {
            field = if (!value.isFinite() || value < 0) -1f else value.coerceAtMost(100f).roundToInt().toFloat()
            contentDescription = if (field < 0) "Fuel level, not set" else "Fuel level, ${field.toInt()} percent"
            invalidate()
        }
    var onChange: ((Float) -> Unit)? = null
    init { isFocusable = true; isClickable = true; contentDescription = "Fuel level, not set" }
    private fun adjustTo(percent: Float) {
        value = percent.coerceIn(0f,100f)
        onChange?.invoke(value)
    }
    private fun moveTo(x: Float, y: Float) {
        val dx = x-width/2f
        val dy = height-32*scale-y
        if (hypot(dx,dy) < 12*scale) return
        adjustTo(((1-atan2(max(0f,dy).toDouble(),dx.toDouble())/PI)*100).toFloat())
    }
    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                val cy = height-32*scale
                val radius = min(width/2f-24*scale,cy-18*scale)
                if (event.y > cy+20*scale || hypot(event.x-width/2f,event.y-cy) > radius+24*scale) return false
                parent?.requestDisallowInterceptTouchEvent(true)
                moveTo(event.x,event.y)
            }
            MotionEvent.ACTION_MOVE -> moveTo(event.x,event.y)
            MotionEvent.ACTION_UP -> { moveTo(event.x,event.y); parent?.requestDisallowInterceptTouchEvent(false); performClick() }
            MotionEvent.ACTION_CANCEL -> parent?.requestDisallowInterceptTouchEvent(false)
            else -> return false
        }
        return true
    }
    override fun performClick(): Boolean { super.performClick(); return true }
    override fun onInitializeAccessibilityNodeInfo(info: AccessibilityNodeInfo) {
        super.onInitializeAccessibilityNodeInfo(info)
        info.className = SeekBar::class.java.name; info.isScrollable = true
        info.rangeInfo = AccessibilityNodeInfo.RangeInfo.obtain(AccessibilityNodeInfo.RangeInfo.RANGE_TYPE_INT,0f,100f,value.coerceAtLeast(0f))
        info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SET_PROGRESS)
        info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_FORWARD)
        info.addAction(AccessibilityNodeInfo.AccessibilityAction.ACTION_SCROLL_BACKWARD)
    }
    override fun performAccessibilityAction(action: Int, arguments: Bundle?): Boolean {
        when (action) {
            AccessibilityNodeInfo.ACTION_SCROLL_FORWARD -> adjustTo(if (value < 0) 0f else value+1)
            AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD -> adjustTo(if (value < 0) 0f else value-1)
            android.R.id.accessibilityActionSetProgress -> {
                if (arguments == null || !arguments.containsKey(AccessibilityNodeInfo.ACTION_ARGUMENT_PROGRESS_VALUE)) return false
                val percent = arguments.getFloat(AccessibilityNodeInfo.ACTION_ARGUMENT_PROGRESS_VALUE)
                if (!percent.isFinite()) return false
                adjustTo(percent)
            }
            else -> return super.performAccessibilityAction(action,arguments)
        }
        sendAccessibilityEvent(android.view.accessibility.AccessibilityEvent.TYPE_VIEW_SELECTED)
        return true
    }
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val scale = resources.displayMetrics.density
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width / 2f
        val cy = height - 32 * scale
        val radius = min(width / 2f - 24 * scale, cy - 18 * scale)
        val arc = RectF(cx-radius, cy-radius, cx+radius, cy+radius)
        paint.style = Paint.Style.STROKE; paint.strokeWidth = 12 * scale; paint.strokeCap = Paint.Cap.ROUND
        paint.color = Color.LTGRAY; canvas.drawArc(arc, 180f, 180f, false, paint)
        if (value >= 0) {
            paint.color = if (value < 20) Color.rgb(179,31,31) else Color.rgb(18,102,88)
            canvas.drawArc(arc, 180f, value / 100 * 180, false, paint)
            val angle = PI + value / 100 * PI
            paint.color = Color.rgb(21,62,54); paint.strokeWidth = 3 * scale
            canvas.drawLine(cx,cy,cx+(radius-48*scale)*cos(angle).toFloat(),cy+(radius-48*scale)*sin(angle).toFloat(),paint)
            paint.style = Paint.Style.FILL; canvas.drawCircle(cx,cy,5*scale,paint)
        }
        paint.style = Paint.Style.FILL; paint.color = Color.rgb(21,62,54); paint.textAlign = Paint.Align.CENTER
        paint.textSize = android.util.TypedValue.applyDimension(android.util.TypedValue.COMPLEX_UNIT_SP, 12f, resources.displayMetrics)
        for (percent in 0..100 step 25) {
            val angle = PI + percent / 100.0 * PI
            val x = cx+(radius-28*scale)*cos(angle).toFloat()
            val y = cy+(radius-28*scale)*sin(angle).toFloat()-(paint.ascent()+paint.descent())/2
            canvas.drawText("$percent%",x,y,paint)
        }
        paint.textSize = android.util.TypedValue.applyDimension(android.util.TypedValue.COMPLEX_UNIT_SP, 18f, resources.displayMetrics)
        canvas.drawText(if (value < 0) "Select fuel level" else "${value.roundToInt()}%",cx,cy+26*scale,paint)
    }
}
