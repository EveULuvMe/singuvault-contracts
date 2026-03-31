/// $EVE — Singu family reward token for Eve U Luv Me games
module singuvault::eve {
    use sui::coin;

    /// One-time witness for EVE coin
    public struct EVE has drop {}

    fun init(witness: EVE, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            9,              // 9 decimals
            b"EVE",         // symbol
            b"Eve",         // name
            b"Singu family reward token for Eve U Luv Me",
            option::none(), // no icon URL yet
            ctx,
        );
        // Treasury cap goes to deployer; must be deposited into VaultState via vault::initialize()
        transfer::public_transfer(treasury_cap, ctx.sender());
        transfer::public_freeze_object(metadata);
    }
}
