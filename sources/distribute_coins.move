module self::distribute_coins {
    use std::vector;
    use aptos_std::math64::min;
    use aptos_framework::aptos_account;
    use aptos_framework::coin;
    use self::random;

    /// Not enough coins to distribute with the given minimum
    const ENOT_ENOUGH_COIN: u64 = 1;


    public entry fun randomly_distribute<CoinType>(
        user: &signer,
        num_coins: u64,
        min_coins_per_person: u64,
        addresses: vector<address>
    ) {
        let num_people = vector::length(&addresses);

        let min_coins_used = num_people * min_coins_per_person;
        assert!(num_coins >= min_coins_used, ENOT_ENOUGH_COIN);

        // Initially distribute the minimum amount of coins to each person
        let distributions: vector<u64> = vector[];
        let i = 0;
        while (i < num_people) {
            vector::push_back(&mut distributions, min_coins_per_person);
            i = i + 1;
        };
        let remaining_coins = num_coins - min_coins_used;

        let rand_seed = random::seed_no_sender();

        // Randomly distribute the remaining coins
        let quarter_rem = remaining_coins/4;
        while (remaining_coins > 0) {
            let i = 0;
            while (i < num_people) {
                if (remaining_coins == 0) {
                    break
                };

                let extra_coin = if (remaining_coins == 1) {
                    1
                } else {
                    random::rand_u64_range(&mut rand_seed, 0, min(remaining_coins, quarter_rem))
                };
                remaining_coins = remaining_coins - extra_coin;

                let c = vector::borrow_mut(&mut distributions, i);
                *c = *c + extra_coin;
                i = i + 1;
            }
        };

        let coins = coin::withdraw<CoinType>(user, num_coins);

        // Shuffle the addresses
        random::shuffle(&mut rand_seed, &mut addresses);
        vector::zip(addresses, distributions, |address, amount| {
            let deposit = coin::extract(&mut coins, amount);
            aptos_account::deposit_coins(address, deposit);
        });
        coin::destroy_zero(coins);
    }

    #[test(aptos = @0x1, u1 = @0x00701, u2 = @0x00702, u3 = @0x00703)]
    fun test_distribute_coins(
        aptos: &signer,
        u1: &signer,
        u2: &signer,
        u3: &signer,
    ) {
        use aptos_framework::account;
        use std::signer;
        use aptos_framework::aptos_coin;

        random::init_for_test(aptos);

        let (burn, mint) = aptos_coin::initialize_for_test(aptos);
        let coins = coin::mint(1000000, &mint);
        aptos_account::deposit_coins(@0x1, coins);
        coin::destroy_burn_cap(burn);
        coin::destroy_mint_cap(mint);

        account::create_account_for_test(signer::address_of(u1));
        account::create_account_for_test(signer::address_of(u2));
        account::create_account_for_test(signer::address_of(u3));

        let u1_addr = signer::address_of(u1);
        let u2_addr = signer::address_of(u2);
        let u3_addr = signer::address_of(u3);

        randomly_distribute<aptos_coin::AptosCoin>(aptos, 1000000, 1000, vector[
            u1_addr, u2_addr, u3_addr
        ]);
    }
}
