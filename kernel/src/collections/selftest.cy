import .collections.slot_map;
import { StaticSlotMap } from .collections.slot_map;
import .panic as panic_mod;

fn fail(name: string): void {
    println(name);
    panic_mod.panic();
}

fn run_static_slot_map_tests(): void {
    var map: StaticSlotMap<i32, 4> = StaticSlotMap<i32, 4> {
        values: [0] ** 4,
        live: [false] ** 4,
        generations: [0] ** 4,
        live_count: 0,
        last_status: slot_map.status_ok,
    };

    if map.capacity() != 4 {
        fail("selftest: static slot map capacity");
    }
    const first = map.insert(10);
    if first == slot_map.invalid_key {
        fail("selftest: static slot map first insert");
    }
    if map.index(first) != 0 {
        fail("selftest: static slot map first index");
    }
    if map.generation(first) != 0 {
        fail("selftest: static slot map first generation");
    }
    if !map.contains(first) {
        fail("selftest: static slot map first contains");
    }
    if map.get(first) is value {
        if value != 10 {
            fail("selftest: static slot map first get");
        }
    } else {
        fail("selftest: static slot map first get none");
    }
    if !map.set(first, 12) {
        fail("selftest: static slot map first set");
    }
    if map.get(first) is value {
        if value != 12 {
            fail("selftest: static slot map first set get");
        }
    } else {
        fail("selftest: static slot map first set get none");
    }

    const second = map.insert(20);
    const third = map.insert(30);
    const fourth = map.insert(40);
    if second == slot_map.invalid_key or third == slot_map.invalid_key or fourth == slot_map.invalid_key {
        fail("selftest: static slot map fill");
    }
    if map.count() != 4 {
        fail("selftest: static slot map filled count");
    }
    if map.insert(50) != slot_map.invalid_key {
        fail("selftest: static slot map rejects full insert");
    }
    if map.status() != slot_map.status_full {
        fail("selftest: static slot map full status");
    }

    if map.remove(first) is removed {
        if removed != 12 {
            fail("selftest: static slot map remove value");
        }
    } else {
        fail("selftest: static slot map remove none");
    }
    if map.contains(first) {
        fail("selftest: static slot map stale key contains");
    }
    if map.status() != slot_map.status_invalid_key {
        fail("selftest: static slot map stale key status");
    }

    const reused = map.insert(50);
    if reused == slot_map.invalid_key {
        fail("selftest: static slot map reused insert");
    }
    if map.index(reused) != 0 {
        fail("selftest: static slot map reused index");
    }
    if map.generation(reused) != 1 {
        fail("selftest: static slot map reused generation");
    }
    if map.contains(first) {
        fail("selftest: static slot map old generation rejected");
    }
    if map.get(reused) is reused_value {
        if reused_value != 50 {
            fail("selftest: static slot map reused value");
        }
    } else {
        fail("selftest: static slot map reused value none");
    }

    map.clear();
    if map.count() != 0 {
        fail("selftest: static slot map clear count");
    }
    if map.contains(reused) {
        fail("selftest: static slot map clear stale key");
    }
    const after_clear = map.insert(60);
    if map.generation(after_clear) != 2 {
        fail("selftest: static slot map clear generation");
    }
}

fn run_key_codec_tests(capacity: usize): void {
    const first = slot_map.key(capacity, 0, 0);
    if first == slot_map.invalid_key {
        fail("selftest: slot map first key");
    }
    if slot_map.index(capacity, first) != 0 {
        fail("selftest: slot map first index");
    }
    if slot_map.generation(capacity, first) != 0 {
        fail("selftest: slot map first generation");
    }
    const reused = slot_map.key(capacity, 0, 1);
    if reused == slot_map.invalid_key {
        fail("selftest: slot map reused key");
    }
    if slot_map.index(capacity, reused) != 0 {
        fail("selftest: slot map reused index");
    }
    if slot_map.generation(capacity, reused) != 1 {
        fail("selftest: slot map reused generation");
    }
    const last = slot_map.key(capacity, capacity - 1, 3);
    if last == slot_map.invalid_key {
        fail("selftest: slot map last key");
    }
    if slot_map.index(capacity, last) != capacity - 1 {
        fail("selftest: slot map last index");
    }
    if slot_map.generation(capacity, last) != 3 {
        fail("selftest: slot map last generation");
    }
    if slot_map.key(capacity, capacity, 0) != slot_map.invalid_key {
        fail("selftest: slot map invalid key");
    }
    if slot_map.index(capacity, slot_map.invalid_key) != capacity {
        fail("selftest: slot map invalid index");
    }
    if slot_map.generation(capacity, slot_map.invalid_key) != 0 {
        fail("selftest: slot map invalid generation");
    }
}

pub fn run_slot_map_tests(): void {
    run_static_slot_map_tests();
    run_key_codec_tests(8);
    run_key_codec_tests(16);
    run_key_codec_tests(32);

    if slot_map.key(0, 0, 0) != slot_map.invalid_key {
        fail("selftest: slot map zero capacity key");
    }
    if slot_map.index(0, slot_map.invalid_key) != 0 {
        fail("selftest: slot map zero capacity index");
    }
    if slot_map.generation(0, slot_map.invalid_key) != 0 {
        fail("selftest: slot map zero capacity generation");
    }
}
