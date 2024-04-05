module self::random {

    use std::bcs;
    use std::error;
    use std::hash;
    use std::vector;
    use aptos_std::from_bcs;

    use aptos_framework::block;
    use aptos_framework::timestamp;
    use aptos_framework::transaction_context;

    const EHIGH_ARG_GREATER_THAN_LOW_ARG: u64 = 1;

    struct Seed has drop {
        seed: vector<u8>,
    }

    /// Acquire a seed using: the hash of the counter, block height, timestamp, and script hash.
    fun raw_seed_no_sender(): vector<u8> {
        let height: u64 = block::get_current_block_height();
        let height_bytes: vector<u8> = bcs::to_bytes(&height);

        let timestamp: u64 = timestamp::now_microseconds();
        let timestamp_bytes: vector<u8> = bcs::to_bytes(&timestamp);

        let script_hash: vector<u8> = transaction_context::get_script_hash();

        let info: vector<u8> = vector::empty<u8>();
        vector::append<u8>(&mut info, height_bytes);
        vector::append<u8>(&mut info, timestamp_bytes);
        vector::append<u8>(&mut info, script_hash);
        info
    }

    public fun seed_no_sender(): Seed {
        let raw_seed = raw_seed_no_sender();
        let hash: vector<u8> = hash::sha3_256(raw_seed);
        // Ths is for incrementing counter in the future
        vector::push_back(&mut hash, 0);
        Seed {
            seed: hash
        }
    }

    public fun increment_seed(seed: &mut Seed) {
        *seed = Seed {
            seed: hash::sha3_256(seed.seed)
        };
    }

    /// Generate a random u64
    public fun rand_u64(seed: &mut Seed): u64 {
        let seed_bytes = seed.seed;
        while (vector::length(&seed_bytes) > 8) {
            vector::pop_back(&mut seed_bytes);
        };

        let num = from_bcs::to_u64(seed_bytes);
        increment_seed(seed);
        num
    }

    /// Generate a random integer range in [low, high).
    public fun rand_u64_range(seed: &mut Seed, low: u64, high: u64): u64 {
        assert!(high > low, error::invalid_argument(EHIGH_ARG_GREATER_THAN_LOW_ARG));
        let value = rand_u64(seed);
        (value % (high - low)) + low
    }

    /// Shuffle a vector in place using the Fisher-Yates algorithm
    public fun shuffle<T>(seed: &mut Seed, data: &mut vector<T>) {
        let i = vector::length(data);
        while (i > 1) {
            i = i - 1;
            let j = rand_u64_range(seed, 0, i);
            vector::swap(data, i, j);
        }
    }

    #[test_only]
    public fun init_for_test(aptos: &signer) {
        use std::signer;
        use aptos_framework::account;

        account::create_account_for_test(signer::address_of(aptos));
        block::initialize_for_test(aptos, 10000);
        timestamp::set_time_has_started_for_testing(aptos);
    }

    #[test(aptos = @0x1)]
    fun test_rand_u64_range(aptos: &signer) {
        init_for_test(aptos);

        let seed = seed_no_sender();
        let low = 10;
        let high = 20;
        let i = 0;
        while (i < 100) {
            let value = rand_u64_range(&mut seed, low, high);
            assert!(value >= low, 0);
            assert!(value < high, 1);
            i = i + 1;
        };
    }
}
