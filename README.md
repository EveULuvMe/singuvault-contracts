# Singu Vault Contracts

Sui Move contracts for the Singu Vault reward flow.

This repository is the on-chain backend for the Singu Vault product. It receives Singu Hunt achievement NFTs, verifies backend-signed redemption tickets, and routes the player into one of two outcomes:

1. immediate reward redemption
2. stake-pass issuance, followed by locked staking and later claim

The current player-facing dapp uses EVE wording for the immediate redemption path. Inside this Move package, the legacy code identifiers still use `lux`, such as `redeem_nft_for_lux` and `singuvault::lux::LUX`. Those names are still the current on-chain identifiers.

## English

### What This Package Does

- prevents the same achievement NFT from being redeemed twice
- verifies backend-issued signed tickets on-chain
- issues `StakePass` objects with per-mode requirements
- locks `SUI + USDC` through `activate_stake_pass<USDC>`
- returns principal and mints `EULM` through `claim_stake_position<USDC>`

### Repository Layout

`move-contracts/singuvault/sources/lux.move`
Immediate reward coin module currently used by the vault redemption function names.

`move-contracts/singuvault/sources/eulm.move`
Reward coin used for the locked-position claim path.

`move-contracts/singuvault/sources/vault.move`
Core shared state, replay protection, redemption, stake-pass issuance, activation, and claim.

`move-contracts/singuvault/sources/sig_verify.move`
Signature verification helpers for redemption tickets.

`move-contracts/singuvault/sources/klux.move`
Additional coin module present in the source tree.

### Main Objects

`VaultState`
Shared vault object holding treasury caps, counters, ticket signer address, redeemed NFT tracking, and used-ticket replay protection.

`AdminCap`
Admin capability used to configure privileged settings.

`StakePass`
Access object minted from an NFT redemption. Stores mode, minimum `SUI`, minimum `USDC`, `EULM` reward amount, and lock duration.

`StakePosition<USDC>`
Locked position minted when a pass is activated with `SUI + USDC`.

### Main Functions

`initialize`
Creates the shared vault and transfers the admin cap to the publisher.

`set_ticket_signer`
Sets the signer address expected by the redemption-ticket validation flow.

`redeem_nft_for_lux`
Consumes a valid ticket and redeems the NFT into the immediate reward path.

`redeem_nft_for_stake_pass`
Consumes a valid ticket and mints a `StakePass` instead of paying the immediate reward.

`activate_stake_pass<USDC>`
Consumes a `StakePass`, locks the supplied coins, and creates a `StakePosition<USDC>`.

`claim_stake_position<USDC>`
After unlock, returns principal and mints `EULM`.

### Contract Flow

```text
Singu Hunt Achievement NFT
  -> backend verifies ownership and mode
  -> backend signs redemption ticket
  -> player calls redeem_nft_for_lux()
     or
  -> player calls redeem_nft_for_stake_pass()
  -> player calls activate_stake_pass<USDC>()
  -> player calls claim_stake_position<USDC>()
```

### Frontend / App Relationship

This contract package is consumed by:

- `singuvault-app`
  Frontend and API layer for NFT redemption, stake-pass issuance, Stable Layer staking flow, and player wallet interactions.
- `singuhunt-contracts`
  Source of the `AchievementNFT` that is redeemed here.
- `singuhunt-app`
  Player-facing game frontend that mints the achievement NFTs later consumed by Singu Vault.

```text
singuhunt-contracts -> mints AchievementNFT
singuhunt-app       -> drives hunt gameplay and claim flow
singuvault-contracts -> redeems AchievementNFT and manages pass/position logic
singuvault-app      -> player UI for redeem / stake / claim
```

### Current App-Side IDs And Config

The current `singuvault-app` frontend defaults to:

- `VITE_VAULT_STATE_ID`
  `0x999d0a834e5b1a3be0e3cd2ce1eac68aee9018b555ebf7eac021015d4dac6d22`
- `VITE_SINGUVAULT_PACKAGE_ID`
  `0x6946b8a2576ed129aaae68e10df71d92d181cfd95e779fb681ab1d9bdb2aec91`
- `VITE_SUI_RPC_URL`
  `https://fullnode.testnet.sui.io:443`
- `VITE_REDEEM_API_URL`
  `/api/redeem-ticket`
- `VITE_EVE_COIN_TYPE`
  `0xf0446b93345c1118f21239d7ac58fb82d005219b2016e100f074e4d17162a465::EVE::EVE`
- `VITE_USDC_COIN_TYPE`
  `0xa1ec7fc00a6f40db9693ad1415d0c193ad3906494428cf252621037bd7117e29::usdc::USDC`

If you publish a new package or re-initialize the vault, the frontend must be updated to match the new package ID and shared-object ID.

### Build And Publish

```bash
cd move-contracts/singuvault
sui move build
sui client publish --gas-budget 200000000
```

After publish:

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

### Runtime Notes

- `VaultState` tracks redeemed NFTs and used tickets separately.
- `activate_stake_pass<USDC>` creates the `USDC` dynamic-field pool lazily on first use.
- `claim_stake_position<USDC>` destroys the position object and decrements the active position count.

## 中文

### 這個合約包現在負責什麼

- 防止同一張 Achievement NFT 被重複兌換
- 在鏈上驗證後端簽發的 redemption ticket
- 根據模式發放 `StakePass`
- 透過 `activate_stake_pass<USDC>` 鎖定 `SUI + USDC`
- 透過 `claim_stake_position<USDC>` 返還本金並發放 `EULM`

### 目前主要模組

`lux.move`
立即兌換路徑使用的代幣模組。雖然前端文案現在寫 EVE，鏈上函式名稱仍保留 `lux`。

`eulm.move`
鎖倉完成後 claim 的獎勵代幣模組。

`vault.move`
核心 Vault 共享狀態、票據驗證、NFT 兌換、StakePass 發放、啟動質押與 claim。

`sig_verify.move`
票據簽章驗證工具。

### 主要物件

`VaultState`
共享 Vault 物件，保存 treasury cap、計數器、簽名者地址、已兌換 NFT 與已使用 ticket。

`AdminCap`
管理員能力物件，用於設定 signer 等高權限操作。

`StakePass`
從 Achievement NFT 兌換而來的資格物件，保存最低 `SUI`、最低 `USDC`、`EULM` 獎勵與鎖定時間。

`StakePosition<USDC>`
實際鎖定後生成的倉位物件。

### 與前端倉庫的關係

- `singuhunt-contracts`
  產生會被此處兌換的 `AchievementNFT`
- `singuhunt-app`
  玩家遊戲前端，負責報名、收集、交付與 claim Achievement
- `singuvault-app`
  玩家兌換與質押前端，會呼叫本倉庫暴露的核心函式

### 目前前端需要對齊的設定

如果重新部署 package 或重建 vault，至少要同步更新 `singuvault-app` 的：

- `VITE_SINGUVAULT_PACKAGE_ID`
- `VITE_VAULT_STATE_ID`
- `VITE_EVE_COIN_TYPE`
- `VITE_USDC_COIN_TYPE`
- `VITE_REDEEM_API_URL`

### 部署流程

```bash
cd move-contracts/singuvault
sui move build
sui client publish --gas-budget 200000000
```

發佈後先 `initialize`，再 `set_ticket_signer`。

## License

MIT
