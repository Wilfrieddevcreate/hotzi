package com.hotzi.net

import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/**
 * Données de Hotzi : forfaits, tickets, ventes et réglages.
 *
 * Un seul propriétaire, côté Kotlin, pour que le service qui coupe les clients
 * y ait accès même quand l'app est fermée. Le schéma est celui de la première
 * version Flutter : les données déjà saisies sur le téléphone sont conservées.
 */
class HotziDatabase private constructor(context: Context) :
    SQLiteOpenHelper(context.applicationContext, NAME, null, VERSION), TicketPersistence {

    data class Plan(
        val id: Long?,
        val name: String,
        val durationMinutes: Int,
        val priceFcfa: Int,
        val active: Boolean,
        val description: String,
        val createdAt: Long,
    )

    data class Sale(
        val id: Long,
        val ticketId: Long,
        val soldAt: Long,
        val amountFcfa: Int,
        /** « cash », « mobileMoney » ou « other », noté par le vendeur. */
        val payment: String,
    )

    override fun onConfigure(db: SQLiteDatabase) {
        db.setForeignKeyConstraintsEnabled(true)
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """CREATE TABLE plans(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                duration_minutes INTEGER NOT NULL,
                price_fcfa INTEGER NOT NULL,
                active INTEGER NOT NULL DEFAULT 1,
                description TEXT NOT NULL DEFAULT '',
                created_at INTEGER NOT NULL
            )"""
        )
        db.execSQL(
            """CREATE TABLE tickets(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                code TEXT NOT NULL UNIQUE,
                plan_id INTEGER REFERENCES plans(id),
                plan_name TEXT NOT NULL,
                duration_minutes INTEGER NOT NULL,
                price_fcfa INTEGER NOT NULL,
                status TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                activated_at INTEGER,
                expires_at INTEGER,
                client_id TEXT
            )"""
        )
        db.execSQL(
            """CREATE TABLE sales(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ticket_id INTEGER NOT NULL REFERENCES tickets(id),
                sold_at INTEGER NOT NULL,
                amount_fcfa INTEGER NOT NULL,
                payment_method TEXT NOT NULL
            )"""
        )
        db.execSQL("CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        val now = System.currentTimeMillis()
        for ((name, minutes, price) in DEMO_PLANS) {
            db.insertOrThrow("plans", null, planValues(Plan(null, name, minutes, price, true, "", now)))
        }
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit

    fun plans(): List<Plan> =
        readableDatabase.query("plans", null, null, null, null, null, "duration_minutes, id").use { it.all(::plan) }

    fun savePlan(plan: Plan): Plan {
        val values = planValues(plan)
        if (plan.id == null) return plan.copy(id = writableDatabase.insertOrThrow("plans", null, values))
        writableDatabase.update("plans", values, "id = ?", arrayOf(plan.id.toString()))
        return plan
    }

    fun tickets(): List<Ticket> =
        readableDatabase.query("tickets", null, null, null, null, null, "created_at DESC, id DESC").use { it.all(::ticket) }

    fun sales(): List<Sale> =
        readableDatabase.query("sales", null, null, null, null, null, "sold_at DESC, id DESC").use { it.all(::sale) }

    /** Vend [quantity] tickets d'un forfait : tickets et ventes dans une seule transaction. */
    fun sell(planId: Long, quantity: Int, payment: String, at: Long): List<Ticket> {
        val plan = readableDatabase.query("plans", null, "id = ?", arrayOf(planId.toString()), null, null, null)
            .use { it.all(::plan).firstOrNull() } ?: throw IllegalArgumentException("Forfait inconnu : $planId")
        val db = writableDatabase
        db.beginTransaction()
        try {
            val sold = List(quantity) {
                val ticket = insertTicket(
                    db,
                    Ticket(
                        code = TicketCodes.generate(),
                        label = plan.name,
                        durationMs = plan.durationMinutes * 60_000L,
                        priceFcfa = plan.priceFcfa,
                        createdAt = at,
                        planId = plan.id,
                    ),
                )
                db.insertOrThrow(
                    "sales",
                    null,
                    ContentValues().apply {
                        put("ticket_id", ticket.id)
                        put("sold_at", at)
                        put("amount_fcfa", plan.priceFcfa)
                        put("payment_method", payment)
                    },
                )
                ticket
            }
            db.setTransactionSuccessful()
            return sold
        } finally {
            db.endTransaction()
        }
    }

    fun setting(key: String): String? =
        readableDatabase.query("settings", arrayOf("value"), "key = ?", arrayOf(key), null, null, null)
            .use { if (it.moveToFirst()) it.getString(0) else null }

    fun saveSetting(key: String, value: String) {
        writableDatabase.insertWithOnConflict(
            "settings",
            null,
            ContentValues().apply {
                put("key", key)
                put("value", value)
            },
            SQLiteDatabase.CONFLICT_REPLACE,
        )
    }

    fun hasPin(): Boolean = setting(KEY_PIN) != null

    /** Enregistre le code secret du vendeur ; seule son empreinte est gardée. */
    fun savePin(pin: String) = saveSetting(KEY_PIN, PinHash.create(pin))

    /** Vérifie le code secret. Un ancien code gardé en clair est remplacé par son empreinte au passage. */
    fun checkPin(pin: String): Boolean {
        val stored = setting(KEY_PIN) ?: return false
        val ok = PinHash.matches(pin, stored)
        if (ok && !PinHash.isHash(stored)) savePin(pin)
        return ok
    }

    override fun load(): List<Ticket> = tickets()

    override fun insert(ticket: Ticket): Ticket = insertTicket(writableDatabase, ticket)

    override fun update(ticket: Ticket) {
        writableDatabase.update(
            "tickets",
            ContentValues().apply {
                put("status", ticket.status.name.lowercase())
                putOrNull("activated_at", ticket.activatedAt)
                putOrNull("expires_at", ticket.expiresAt)
                if (ticket.clientIp == null) putNull("client_id") else put("client_id", ticket.clientIp)
            },
            "code = ?",
            arrayOf(ticket.code),
        )
    }

    private fun insertTicket(db: SQLiteDatabase, ticket: Ticket): Ticket {
        var candidate = ticket
        while (codeTaken(db, candidate.code)) candidate = candidate.copy(code = TicketCodes.generate())
        val id = db.insertOrThrow(
            "tickets",
            null,
            ContentValues().apply {
                put("code", candidate.code)
                putOrNull("plan_id", candidate.planId)
                put("plan_name", candidate.label)
                put("duration_minutes", candidate.durationMs / 60_000L)
                put("price_fcfa", candidate.priceFcfa)
                put("status", candidate.status.name.lowercase())
                put("created_at", candidate.createdAt)
                putOrNull("activated_at", candidate.activatedAt)
                putOrNull("expires_at", candidate.expiresAt)
                if (candidate.clientIp != null) put("client_id", candidate.clientIp)
            },
        )
        return candidate.copy(id = id)
    }

    private fun codeTaken(db: SQLiteDatabase, code: String): Boolean =
        db.query("tickets", arrayOf("id"), "code = ?", arrayOf(code), null, null, null, "1").use { it.moveToFirst() }

    private fun planValues(plan: Plan) = ContentValues().apply {
        put("name", plan.name)
        put("duration_minutes", plan.durationMinutes)
        put("price_fcfa", plan.priceFcfa)
        put("active", if (plan.active) 1 else 0)
        put("description", plan.description)
        put("created_at", plan.createdAt)
    }

    private fun plan(c: Cursor) = Plan(
        id = c.long("id"),
        name = c.string("name"),
        durationMinutes = c.int("duration_minutes"),
        priceFcfa = c.int("price_fcfa"),
        active = c.int("active") == 1,
        description = c.string("description"),
        createdAt = c.long("created_at"),
    )

    private fun ticket(c: Cursor) = Ticket(
        code = c.string("code"),
        label = c.string("plan_name"),
        durationMs = c.long("duration_minutes") * 60_000L,
        priceFcfa = c.int("price_fcfa"),
        createdAt = c.long("created_at"),
        status = TicketStatus.valueOf(c.string("status").uppercase()),
        activatedAt = c.longOrNull("activated_at"),
        expiresAt = c.longOrNull("expires_at"),
        clientIp = c.stringOrNull("client_id"),
        id = c.long("id"),
        planId = c.longOrNull("plan_id"),
    )

    private fun sale(c: Cursor) = Sale(
        id = c.long("id"),
        ticketId = c.long("ticket_id"),
        soldAt = c.long("sold_at"),
        amountFcfa = c.int("amount_fcfa"),
        payment = c.string("payment_method"),
    )

    companion object {
        private const val NAME = "hotzi.db"
        private const val VERSION = 1
        private const val KEY_PIN = "pin"

        /** Forfaits de démonstration du cahier des charges, modifiables par le vendeur. */
        private val DEMO_PLANS = listOf(
            Triple("Mini", 30, 50),
            Triple("Standard", 60, 100),
            Triple("Confort", 6 * 60, 300),
            Triple("Journée", 24 * 60, 500),
        )

        @Volatile
        private var instance: HotziDatabase? = null

        fun get(context: Context): HotziDatabase =
            instance ?: synchronized(this) { instance ?: HotziDatabase(context).also { instance = it } }
    }
}

private fun <T> Cursor.all(read: (Cursor) -> T): List<T> = buildList { while (moveToNext()) add(read(this@all)) }

private fun Cursor.string(column: String): String = getString(getColumnIndexOrThrow(column))

private fun Cursor.stringOrNull(column: String): String? =
    getColumnIndexOrThrow(column).let { if (isNull(it)) null else getString(it) }

private fun Cursor.int(column: String): Int = getInt(getColumnIndexOrThrow(column))

private fun Cursor.long(column: String): Long = getLong(getColumnIndexOrThrow(column))

private fun Cursor.longOrNull(column: String): Long? =
    getColumnIndexOrThrow(column).let { if (isNull(it)) null else getLong(it) }

private fun ContentValues.putOrNull(key: String, value: Long?) {
    if (value == null) putNull(key) else put(key, value)
}
