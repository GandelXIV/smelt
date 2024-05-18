/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

use mlua::AnyUserData;
use mlua::Error;
use mlua::Function;
use mlua::OwnedTable;
use mlua::Table;
use mlua::UserData;
use mlua::UserDataFields;
use mlua::UserDataMethods;
use mlua::{self, Lua};
use std::env::current_dir;
use std::env::set_current_dir;
use std::fs;
use std::fs::File;
use std::fs::OpenOptions;
use std::io::prelude::*;
use std::io::BufRead;
use std::io::BufReader;
use std::path::Path;
use std::path::PathBuf;

const CACHE_PATH: &str = ".cache";

fn lx_cache_search(_: &Lua, id: String) -> Result<bool, Error> {
    drop(File::create_new(CACHE_PATH));
    let cache = File::open(CACHE_PATH)?;
    let reader = BufReader::new(cache);

    for line in reader.lines() {
        if line? == id {
            return Ok(true);
        }
    }
    Ok(false)
}

fn lx_cache_add(_: &Lua, id: String) -> Result<(), Error> {
    let mut cache = OpenOptions::new()
        .write(true)
        .append(true)
        .open(CACHE_PATH)
        .unwrap();

    writeln!(cache, "{}", id)?;

    Ok(())
}

// TODO: d must be relativized
fn lx_smelt(lua: &Lua, d: String) -> Result<OwnedTable, Error> {
    let s = d.split_once(':').unwrap();
    let (pkg_str, target) = s;
    let pkg = Path::new(pkg_str);
    Ok(run_task(&pkg, target))
}

// not fully functional
fn lx_hash_function(_lua: &Lua, f: Function) -> Result<String, Error> {
    todo!("hash_function() should not be used");
    let hash = md5::compute(f.dump(false));
    Ok(format!("{:x}", hash))
}

trait Entity {
    fn exists(&self) -> bool;
    fn identify(&self) -> String;
    fn reset(self);
}

fn lx_file(lua: &Lua, name: String) -> Result<AnyUserData, Error> {
    Ok(lua.create_userdata(FileEntity::new(&name))?)
}

fn lx_file_tree(lua: &Lua, directory: String) -> Result<Table, Error> {
    let previous_work_dir = current_dir().unwrap();
    set_current_dir(&directory).unwrap();

    let table = lua.create_table()?;
    for path in fs::read_dir("./")? {
        let path = path?;
        let name = path.file_name().into_string().unwrap();
        let isfile = path.file_type()?.is_file();
        let isdir = path.file_type()?.is_dir();

        if isfile {
            table.set(name.clone(), lx_file(lua, name)?)?;
        } else if isdir {
            table.set(name.clone(), lx_file_tree(lua, name)?)?;
        }
    }
    set_current_dir(previous_work_dir).unwrap();
    Ok(table)
}

struct FileEntity {
    name: String,
    path: PathBuf,
}

impl FileEntity {
    fn new(name: &str) -> Self {
        Self {
            name: name.to_string(),
            path: std::env::current_dir().unwrap().join(name),
        }
    }
}

impl Entity for FileEntity {
    fn exists(&self) -> bool {
        self.path.exists()
    }

    fn identify(&self) -> String {
        let mut hash = String::new();
        hash.push_str(&format!("{:x}", md5::compute(self.path.to_str().unwrap())));
        hash.push_str(&format!(
            "{:x}",
            md5::compute(fs::read(&self.path).unwrap())
        ));
        hash
    }

    fn reset(self) {}
}

impl UserData for FileEntity {
    fn add_fields<'lua, F: UserDataFields<'lua, Self>>(fields: &mut F) {
        fields.add_field_method_get("name", |_, this| Ok(this.name.clone()));
    }

    fn add_methods<'lua, M: UserDataMethods<'lua, Self>>(methods: &mut M) {
        methods.add_method("exists", |_, this, _: ()| -> Result<bool, Error> {
            Ok(this.exists())
        });

        methods.add_method("identify", |_, this, _: ()| -> Result<String, Error> {
            Ok(this.identify())
        });
    }
}

fn run_task(pkg: &Path, target: &str) -> OwnedTable {
    let lua = Lua::new();
    let globals = lua.globals();

    println!("[STARTING TASK] {} : {}", pkg.display(), target);

    // setup

    globals
        .set("file", lua.create_function(lx_file).unwrap())
        .unwrap();

    globals
        .set("file_tree", lua.create_function(lx_file_tree).unwrap())
        .unwrap();

    globals
        .set(
            "cache_search",
            lua.create_function(lx_cache_search).unwrap(),
        )
        .unwrap();

    globals
        .set("cache_add", lua.create_function(lx_cache_add).unwrap())
        .unwrap();

    globals
        .set(
            "hash_function",
            lua.create_function(lx_hash_function).unwrap(),
        )
        .unwrap();

    globals
        .set("smelt", lua.create_function(lx_smelt).unwrap())
        .unwrap();

    lua.load(include_str!("prelude.lua"))
        .exec()
        .expect("Error running prelude.lua");

    // run task

    let previous_work_dir = current_dir().unwrap();
    set_current_dir(pkg).unwrap();

    lua.load(fs::read_to_string("SMELT.lua").unwrap())
        .exec()
        .expect("Error running SMELT.lua");

    let artifacts: Table = globals
        .get::<_, Function>(target)
        .expect("Target not defined in SMELT.lua")
        .call::<_, _>(())
        .unwrap();

    set_current_dir(previous_work_dir).unwrap();

    return artifacts.into_owned();
}

fn main() {
    for arg in std::env::args() {
        if arg.contains(':') {
            let s = arg.split_once(':').unwrap();
            let (pkg_str, target) = s;
            let pkg = Path::new(pkg_str);
            run_task(&pkg, target);
        }
    }
}
