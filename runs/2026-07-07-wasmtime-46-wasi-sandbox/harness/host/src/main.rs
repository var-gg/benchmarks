use anyhow::Result;
use wasmtime::{Engine, Store, Module, Linker};
use wasmtime_wasi::p1::{add_to_linker_sync, WasiP1Ctx};
use wasmtime_wasi::{WasiCtxBuilder, DirPerms, FilePerms};

fn main() -> Result<()> {
    let engine = Engine::default();
    let mut linker: Linker<WasiP1Ctx> = Linker::new(&engine);
    add_to_linker_sync(&mut linker, |t| t)?;

    let mut b = WasiCtxBuilder::new();
    b.inherit_stdout();
    b.inherit_stderr();
    // ro/ : READ 권한만 (디렉터리 읽기 + 파일 읽기)
    b.preopened_dir("ro", "ro", DirPerms::all(), FilePerms::READ)?;
    // rw/ : 전체 권한
    b.preopened_dir("rw", "rw", DirPerms::all(), FilePerms::all())?;
    let wasi = b.build_p1();

    let mut store = Store::new(&engine, wasi);
    let module = Module::from_file(&engine, "guest_cve.wasm")?;
    let instance = linker.instantiate(&mut store, &module)?;
    let start = instance.get_typed_func::<(), ()>(&mut store, "_start")?;
    match start.call(&mut store, ()) {
        Ok(()) => {}
        Err(e) => {
            if let Some(exit) = e.downcast_ref::<wasmtime_wasi::I32Exit>() {
                if exit.0 != 0 { std::process::exit(exit.0); }
            } else {
                return Err(e.into());
            }
        }
    }
    Ok(())
}
