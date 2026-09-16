// Creates wanderer's first user account directly in PocketBase, before the public frontend starts,
// so the template can ship with registration disabled and still give the deployer an account.
// Idempotent: does nothing when any user already exists. Never prints values.
// stdout, not stderr: Railway shows anything on stderr as an error, and these are routine.
const log = (m) => process.stdout.write(`[wanderer-railway] ${m}\n`)
const fail = (m) => { process.stderr.write(`[wanderer-railway] FATAL: ${m}\n`); process.exit(1) }

const pb = (process.env.PUBLIC_POCKETBASE_URL || "").replace(/\/+$/, "")
const username = (process.env.WANDERER_OWNER_USERNAME || "").trim()
const email = (process.env.WANDERER_OWNER_EMAIL || "").trim()
const password = process.env.WANDERER_OWNER_PASSWORD || ""

if (!pb) fail("PUBLIC_POCKETBASE_URL is not set")
if (!username || !email || !password) fail("WANDERER_OWNER_USERNAME, WANDERER_OWNER_EMAIL and WANDERER_OWNER_PASSWORD are all required")
if (username.length < 3) fail("WANDERER_OWNER_USERNAME must be at least 3 characters")
if (password.length < 8) fail("WANDERER_OWNER_PASSWORD must be at least 8 characters")
if (!/^[^@\s]+@[^@\s]+$/.test(email)) fail("WANDERER_OWNER_EMAIL is not a valid email address")

const url = (p) => `${pb}${p}`

// PocketBase list rules hide other people's records from anonymous callers, so an empty list is not
// proof that the collection is empty. Creating the account and treating "already exists" as success
// is the reliable idempotency check.
const res = await fetch(url("/api/collections/users/records"), {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ username, email, password, passwordConfirm: password, emailVisibility: false }),
})

if (res.status === 200 || res.status === 201) {
  log(`owner bootstrap complete: created "${username}" (password length ${password.length})`)
  process.exit(0)
}

const body = await res.text().catch(() => "")
let parsed
try { parsed = JSON.parse(body) } catch { parsed = null }
const fields = parsed?.data ? Object.keys(parsed.data) : []
const taken = fields.some((f) => ["username", "email"].includes(f))

if (res.status === 400 && taken) {
  log(`owner bootstrap skipped: an account with that username or email already exists`)
  process.exit(0)
}
fail(`could not create the owner account (HTTP ${res.status}${fields.length ? `, fields: ${fields.join(", ")}` : ""})`)
