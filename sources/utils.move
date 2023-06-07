module aptos_arena::utils {

    use aptos_framework::timestamp;

    public fun rand_int(num_vals: u64): u64 {
        timestamp::now_seconds() % num_vals
    }
}
