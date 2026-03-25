/// $LUX — Singu family reward token for Eve U Luv Me games
module singuvault::lux {
    use sui::coin;

    /// One-time witness for LUX coin
    public struct LUX has drop {}

    fun init(witness: LUX, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            9,              // 9 decimals
            b"LUX",         // symbol
            b"Lux",         // name
            b"Singu family reward token \xe2\x80\x94 Eve U Luv Me",
            option::none(), // no icon URL yet
            ctx,
        );
        // Treasury cap goes to deployer; must be deposited into VaultState via vault::initialize()
        transfer::public_transfer(treasury_cap, ctx.sender());
        transfer::public_freeze_object(metadata);
    }
}
