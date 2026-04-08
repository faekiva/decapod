use std::path::{Path, PathBuf};
use std::process::Command;
use std::thread;
use std::time::Duration;
use sysinfo::System;
use tempfile::TempDir;

fn run_decapod(dir: &Path, args: &[&str]) -> std::process::Output {
    Command::new(env!("CARGO_BIN_EXE_decapod"))
        .current_dir(dir)
        .args(args)
        .output()
        .expect("run decapod")
}

fn setup_repo() -> (TempDir, PathBuf) {
    let tmp = TempDir::new().expect("tmpdir");
    let dir = tmp.path().to_path_buf();

    let git_init = Command::new("git")
        .current_dir(&dir)
        .args(["init", "-b", "master"])
        .output()
        .expect("git init");
    assert!(git_init.status.success(), "git init failed");

    let init = run_decapod(&dir, &["init", "--force"]);
    assert!(
        init.status.success(),
        "decapod init failed: {}",
        String::from_utf8_lossy(&init.stderr)
    );

    (tmp, dir)
}

fn running_decapod_pids(exe_path: &str) -> Vec<u32> {
    let mut sys = System::new();
    sys.refresh_processes(sysinfo::ProcessesToUpdate::All, true);
    let mut pids: Vec<u32> = sys
        .processes()
        .values()
        .filter(|proc| {
            let cmd = proc.cmd().iter().map(|s| s.to_string_lossy()).collect::<Vec<_>>().join(" ");
            cmd.contains(exe_path)
        })
        .map(|proc| proc.pid().as_u32())
        .collect();
    pids.sort();
    pids
}

#[test]
fn decapod_has_no_lingering_background_process() {
    let (_tmp, dir) = setup_repo();
    let exe_path = env!("CARGO_BIN_EXE_decapod");

    let before = running_decapod_pids(exe_path);

    for args in [
        vec!["version"],
        vec!["capabilities", "--format", "json"],
        vec!["docs", "show", "core/DECAPOD.md"],
    ] {
        let out = run_decapod(&dir, &args);
        assert!(
            out.status.success(),
            "decapod command {:?} failed: {}",
            args,
            String::from_utf8_lossy(&out.stderr)
        );
    }

    thread::sleep(Duration::from_millis(150));
    let after = running_decapod_pids(exe_path);

    assert_eq!(
        before, after,
        "daemonless contract violated: unexpected lingering decapod process(es)"
    );
}
