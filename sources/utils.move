module aptos_arena::utils {

    use std::string::{Self, String};
    use std::vector;
    use aptos_framework::timestamp;

    public fun u64_to_string(value: u64): String {
        if (value == 0) {
            return string::utf8(b"0")
        };
        let buffer = vector::empty<u8>();
        while (value != 0) {
            vector::push_back(&mut buffer, ((48 + value % 10) as u8));
            value = value / 10;
        };
        vector::reverse(&mut buffer);
        string::utf8(buffer)
    }

    public fun rand_int(num_vals: u64): u64 {
        timestamp::now_seconds() % num_vals
    }
}
