Life System - X1Studios (Havoc Sheriff)


--- What Is This Script? ---

The X1Studios Life System is one massive script to make roleplay better. Includes:
Character creation/selection + spawn selector + duty/dispatch/panic + a full
CAD/MDT, combined into one standalone FiveM resource. Built from your
existing **X1S-AdvDutySystem** and **X1S-SpawnSelector**, whose UI,
behaviour, and permissions (Discord-role duty verification, department
webhooks, 911/panic, spawn locations) are preserved exactly as they were and
now shared across every system instead of living in two separate resources.

Concretely: the duty/supervisor/911/panic menus are your original
`X1S-AdvDutySystem` HTML/CSS/JS, kept as its own self-contained piece (s/ee
`html/duty.js` and the `#duty-system` block in `html/index.html`/`style.css`)
rather than redesigned - only pointed at the same shared notification
styling. Same for the spawn selector's look and location images. The new
pieces (character creator/selector, CAD/MDT) get their own consistent look
without touching either original.


--- Dependency ---

oxmysql

Everything else is standalone (no ESX/QBCore/Qbox/vRP, no framework player
objects, no framework jobs). Characters and CAD records need to persist in a
real database, though, so this resource requires oxmysql (https://github.com/overextended/oxmysql
purely as a database driver — it doesn't impose a framework on top of this
resource. Install it and put it above this resource in your server.cfg:

--- server.cfg setup ---
ensure oxmysql
ensure X1S-LifeSystem


--- Install ---

1. Copy the `X1S-LifeSystem` folder into your `resources` directory.
2. Import `sql/database.sql` into the database your oxmysql connection
   string points to.
3. Open `server_config.lua` and paste in your real Discord bot token, guild
   ID, role IDs, and webhook URLs (see below).
4. The original spawn location screenshots (`html/images/*.png`) and
   `html/logo.png` are already included, carried over as-is from
   X1S-SpawnSelector.
5. `ensure oxmysql` then `ensure X1S-LifeSystem` in `server.cfg`.


--- Commands / Keybinds ---

| Command | Who | What |
|---|---|---|
| `/switchcharacter` | anyone in-world | re-opens the character selector |
| `/dutymenu` | anyone with a loaded character | go on duty |
| `/offduty` | on-duty | go off duty |
| `/supervisormenu` | Discord supervisor role | force officers off duty |
| `/911` | anyone | file an emergency report |
| `/911calls` | on-duty | view/dismiss the active call queue |
| `/panic` | on-duty | silent panic alert to all on-duty officers |
| `/cad` or **F6** | on-duty, CAD-flagged department | open the CAD/MDT |
| `/spawnselector` | anyone with a character loaded | manually reopen spawn picker |
| `/registervehicle` | anyone with a character loaded | civilian self-service vehicle registration (brand/type/color/plate) |
| `/handid` | anyone with a character loaded | hand your state ID card to nearby players |
| `/handdriverlicense`, `/handmotorcyclelicense`, `/handcdl`, `/handweaponlicense`, `/handhuntinglicense`, `/handboatinglicense`, `/handpilotlicense` | holder of that valid license | hand that license's card to nearby players |

`Config.CAD.keybind` is rebindable per-player in FiveM's own keybind
settings (Settings → Key Bindings → FiveM), since it's registered through
`RegisterKeyMapping`.


--- Configuration ---

Everything gameplay-facing is in `config.lua` (shared, safe to send to
clients): departments, notification style, character limits/age/height
bounds, appearance ranges, spawn locations, CAD access list, CAD search
limits, and the predefined charge list officers pick from when filing an
arrest/citation. `server_config.lua` (server-only) holds Discord role IDs,
webhooks, and per-action cooldowns.

`Config.Departments[key].cad = true/false` controls whether that
department's on-duty members can open the CAD at all; `Config.CAD.accessDepartments`
is a second, independent filter on top of that if you want a narrower CAD
allow-list without changing duty behaviour.