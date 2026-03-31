/// $kLUX — capped Sui reward coin for SinguVault redemptions
module singuvault::klux {
    use sui::coin;

    public struct KLUX has drop {}

    fun init(witness: KLUX, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            9,
            b"kLUX",
            b"Kilo Lux",
            b"Capped SinguVault redemption coin",
            option::none(),
            ctx,
        );

        transfer::public_transfer(treasury_cap, ctx.sender());
        transfer::public_freeze_object(metadata);
    }
}
