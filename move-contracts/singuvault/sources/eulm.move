/// $EULM — Eve U Luv Me ecosystem reward token
module singuvault::eulm {
    use sui::coin;

    public struct EULM has drop {}

    fun init(witness: EULM, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            9,
            b"EULM",
            b"Eve U Luv Me",
            b"Eve U Luv Me staking reward token",
            option::none(),
            ctx,
        );

        transfer::public_transfer(treasury_cap, ctx.sender());
        transfer::public_freeze_object(metadata);
    }
}
