# Testy

Automatický smoke test spustí **skutečný kód serveru i klienta** mimo Roblox
proti zjednodušenému mocku Roblox API (`mock_roblox.luau`):

- vygeneruje poušť (kontrola rozměrů voxelů a zarovnání regionů),
- načte hráče, kope, plní batoh, prodává, nakupuje, používá kódy,
- odkryje a otevře truhlu, ověří relikvii v ruinách,
- simuluje nákup gamepassů a developer produktů (včetně ochrany proti dvojímu připsání),
- rebirth, písečnou bouři, uložení a znovunačtení dat,
- postaví celé UI, otevře všechna okna a "klikne" na všechna tlačítka.

Mock neověřuje Roblox API do posledního detailu – finální test je vždy **Play ve Studiu**.

## Spuštění

Potřebuješ Luau runner – program, který spustí `.luau` soubor. Nejjednodušší je
malý Rust program s knihovnou `mlua`:

```toml
# Cargo.toml
[package]
name = "luaurun"
version = "0.1.0"
edition = "2021"

[dependencies]
mlua = { version = "0.10", features = ["luau", "vendored"] }
```

```rust
// src/main.rs
use mlua::prelude::*;
fn main() -> LuaResult<()> {
    let path = std::env::args().nth(1).expect("script path");
    let code = std::fs::read_to_string(&path).expect("read");
    Lua::new().load(&code).set_name(path).exec()
}
```

```bash
cargo build --release
LUAU_RUNNER=./target/release/luaurun python3 tests/run_tests.py
```

Očekávaný výsledek:

```
VÝSLEDEK: 81 OK, 0 CHYB
KLIENT: 13 OK, 0 CHYB
```

## Náhledové obrázky (lobby + UI)

```bash
LUAU_RUNNER=./target/release/luaurun python3 tests/run_tests.py --preview tools/graphics/out/preview
cd tools/graphics && npm install && npx playwright install chromium
node render.js out lobby_aerial lobby_ground ui_menu ui_hud ui_shop ui_store ui_top ui_index ui_rebirth ui_settings
```

Export spustí skutečný kód hry v mocku, uloží party lobby a strom UI do JSON
a `tools/graphics` je vykreslí (three.js pro 3D, HTML pro UI podle pravidel Roblox layoutu).
Je to přibližný náhled – finální vzhled ověř ve Studiu.
