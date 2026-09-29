"use strict";
// One Node process for the whole suite (tests/run_tests.py starts it). Every test file gets its own
// fresh Lua state, so globals do not leak between files exactly as when each ran in its own
// process, but Node and fengari start once instead of once per file.
//
//   node run_all.js test_a.lua test_b.lua     run from the tests directory
//
// Prints one JSON array on stdout: [{ name, ok, lines }], where lines is everything the test
// printed (print and error output) and ok is true when the file ran without a Lua error.
// A test that dies with an error contributes the error text as its last line.

const {
    to_luastring,
    lua: { LUA_OK, LUA_TSTRING, lua_createtable, lua_gettop, lua_insert, lua_pcall, lua_pop, lua_pushcfunction,
           lua_pushstring, lua_seti, lua_setglobal, lua_tojsstring, lua_type },
    lauxlib: { luaL_loadfile, luaL_newstate, luaL_traceback, luaL_tolstring },
    lualib: { luaL_openlibs },
} = require("fengari");

function runFile(name) {
    const lines = [];
    const L = luaL_newstate();
    luaL_openlibs(L);
    // print: tab-separated tostring of every argument, one line per call
    lua_pushcfunction(L, function (L) {
        const n = lua_gettop(L);
        const parts = [];
        for (let i = 1; i <= n; i++) {
            luaL_tolstring(L, i);
            parts.push(lua_tojsstring(L, -1));
            lua_pop(L, 1);
        }
        lines.push(parts.join("\t"));
        return 0;
    });
    lua_setglobal(L, to_luastring("print"));
    // arg[0] is the script name, as the fengari command line sets it
    lua_createtable(L, 0, 1);
    lua_pushstring(L, to_luastring(name));
    lua_seti(L, -2, 0);
    lua_setglobal(L, to_luastring("arg"));

    let status = luaL_loadfile(L, to_luastring(name));
    if (status === LUA_OK) {
        // message handler: text plus a traceback
        lua_pushcfunction(L, function (L) {
            const msg = lua_tojsstring(L, 1);
            luaL_traceback(L, L, to_luastring(msg === null ? "(error object is not a string)" : msg), 1);
            return 1;
        });
        // the chunk sits below the handler: reorder to handler, chunk
        lua_insert(L, -2);
        status = lua_pcall(L, 0, 0, -2);
    }
    if (status !== LUA_OK) {
        const msg = lua_type(L, -1) === LUA_TSTRING ? lua_tojsstring(L, -1) : "(error)";
        for (const l of msg.split("\n")) lines.push(l);
    }
    return { name, ok: status === LUA_OK, lines };
}

const results = process.argv.slice(2).map(runFile);
process.stdout.write(JSON.stringify(results));
