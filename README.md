# Singu Vault Contracts

Sui Move contracts for the Singu Vault reward flow.

This package covers two contract-level paths for a Singu Hunt achievement NFT:

1. Immediate reward redemption
2. Stake-pass issuance, followed by principal-return staking and reward claim

## Current Scope

The repository contains the on-chain logic for:

- one-time NFT redemption protection
- signed redemption ticket verification
- stake-pass issuance with per-pass requirements
- vault activation with `SUI + USDC`
- locked position claim with principal return plus `EULM`

The player-facing dapp currently presents the immediate redemption route as an EVE exchange. In this Move package, the legacy module/function names still use `lux`, for example `redeem_nft_for_lux` and `singuvault::lux::LUX`. Treat those names as current code identifiers, not product copy.

## Package Layout

`move-contracts/singuvault/sources/eulm.move`
`EULM` reward coin witness and treasury initialization.

`move-contracts/singuvault/sources/lux.move`
Immediate redemption coin witness and treasury initialization.

`move-contracts/singuvault/sources/vault.move`
Core vault state, signed ticket validation, redemption, stake-pass activation, and locked-position claim.

`move-contracts/singuvault/sources/sig_verify.move`
Signature verification helpers used by redemption tickets.

`move-contracts/singuvault/sources/klux.move`
Additional coin module currently present in the package sources.

## Main Objects

`VaultState`
Shared vault object holding treasury caps, redemption counters, ticket signer, replay protection, and redeemed NFT tracking.

`AdminCap`
Admin capability used to configure privileged vault settings such as the ticket signer.

`StakePass`
Per-player access object created from an achievement redemption. Stores mode, minimum `SUI`, minimum `USDC`, reward amount, and lock duration.

`StakePosition<USDC>`
Locked staking position created when a pass is activated with coins.

## Main Functions

`initialize`
Creates the shared vault, stores treasury caps, and returns the admin capability.

`set_ticket_signer`
Sets the address that is allowed to sign redemption tickets.

`redeem_nft_for_lux`
Consumes a signed ticket and marks an achievement NFT as redeemed for the immediate reward path.

`redeem_nft_for_stake_pass`
Consumes a signed ticket and mints a `StakePass` instead of paying the immediate reward.

`activate_stake_pass<USDC>`
Consumes a `StakePass`, locks the required `SUI` and `USDC`, and creates a `StakePosition<USDC>`.

`claim_stake_position<USDC>`
After the lock expires, returns principal and mints the configured `EULM` reward.

## Contract Flow

```text
Achievement NFT
  -> signed backend ticket
  -> redeem_nft_for_lux()
     or
  -> redeem_nft_for_stake_pass()
  -> activate_stake_pass<USDC>()
  -> claim_stake_position<USDC>()
```

## Build And Publish

```bash
cd move-contracts/singuvault
sui move build
sui client publish --gas-budget 200000000
```

After publish, initialize the vault with the treasury caps produced by the coin modules:

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module vault \
  --function initialize \
  --args <LUX_TREASURY_CAP_ID> <EULM_TREASURY_CAP_ID>
```

Then configure the backend signer:

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module vault \
  --function set_ticket_signer \
  --args <ADMIN_CAP_ID> <VAULT_STATE_ID> <SIGNER_ADDRESS>
```

## Notes

- `VaultState` tracks redeemed NFTs and used tickets separately, so both NFT replay and ticket replay are blocked.
- Stake activation creates a dynamic-field `USDC` pool lazily for the first activation of a given `USDC` type.
- Claim burns the position object and decrements the live position counter.

## License

MIT
