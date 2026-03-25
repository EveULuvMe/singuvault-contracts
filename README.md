<div align="center">

# Singu Vault — Contracts

Sui Move smart contracts for the Singu family reward vault — redeem game-award NFTs for **$LUX** or unlock principal-protected staking that pays **$EULM**.

[![Built for EVE Frontier](https://img.shields.io/badge/Built%20for-EVE%20Frontier-blueviolet?style=flat-square)](https://evefrontier.com)
[![Sui](https://img.shields.io/badge/Chain-Sui%20Testnet-blue?style=flat-square)](https://sui.io)

</div>

---

## Overview

SinguVault is the reward hub for **Eve U Luv Me** (Singu family) games. Players who earn achievement NFTs in games like [Singu Hunt](https://github.com/EveULuvMe/singuhunt-contracts) can:

1. **Redeem** an award NFT for an immediate **$LUX** payout
2. **Redeem** the same award NFT instead for a **staking pass**
3. **Deposit** the required **$SUI + $USDC** under that pass
4. **Claim** principal back at unlock plus **$EULM** reward

---

## Modules

| Module | Description |
|--------|-------------|
| `lux` | $LUX fungible coin (9 decimals) via one-time witness |
| `eulm` | $EULM fungible coin (9 decimals) used for staking rewards |
| `vault` | NFT redemption, staking pass issuance, principal-return staking |
| `sig_verify` | ED25519 ticket signature verification |

## StableLayer Reuse Policy

This package should reuse StableLayer primitives when they already match the product need, instead of expanding custom Move by default.

- Reuse StableLayer factory, registry, and SDK patterns for fungible asset issuance and transaction composition.
- Keep local Move only for `singuvault`-specific flows that StableLayer does not expose yet.
- The currently custom pieces are the game-NFT redemption flow, signed ticket verification, and the paired `LUX`/`SUI` staking logic.
- If StableLayer later ships an equivalent vault or farming primitive for this flow, it should replace more of the local `vault` module before adding new custom Move code.

---

## Architecture

```
SinguHunt award NFT
        |
        v
Backend verifies NFT ownership + mode → issues signed ticket
        |
        v
Choice A: vault::redeem_nft_for_lux() → mints $LUX
        |
        v
Choice B: vault::redeem_nft_for_stake_pass() → StakePass
        |
        v
vault::activate_stake_pass() → locks $SUI + $USDC
        |
        v
vault::claim_stake_position() → returns principal + mints $EULM
```

---

## Deploy

```bash
cd move-contracts/singuvault
sui client publish --gas-budget 200000000
```

After publish:
```bash
# Initialize vault with both TreasuryCaps
sui client call --package <PKG> --module vault --function initialize --args <LUX_TREASURY_CAP_ID> <EULM_TREASURY_CAP_ID>
```

---

## License

MIT

---

<div align="center">

Built for the EVE Frontier community by **k66**

</div>
