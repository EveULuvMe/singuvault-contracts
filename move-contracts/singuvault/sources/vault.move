/// SinguVault — award NFT vault for the Singu family
///
/// Product flow:
///   1. A SinguHunt award NFT can be redeemed once
///   2. The holder chooses either:
///      - redeem to $EVE immediately, or
///      - redeem to a staking pass
///   3. A staking pass allows depositing $SUI + $USDC
///   4. After lock expiry, the player claims back principal plus $EULM reward
module singuvault::vault {
    use sui::balance::{Self, Balance};
    use sui::bcs;
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::dynamic_field;
    use sui::event;
    use sui::hash;
    use sui::sui::SUI;
    use sui::table::{Self, Table};

    use singuvault::eulm::EULM;
    use singuvault::eve::EVE;
    use singuvault::sig_verify;

    const E_ALREADY_REDEEMED: u64 = 1;
    const E_INVALID_TICKET: u64 = 2;
    const E_TICKET_EXPIRED: u64 = 3;
    const E_TICKET_REPLAY: u64 = 4;
    const E_ZERO_AMOUNT: u64 = 5;
    const E_TICKET_SIGNER_NOT_SET: u64 = 6;
    const E_NOT_PASS_OWNER: u64 = 7;
    const E_NOT_POSITION_OWNER: u64 = 8;
    const E_BELOW_PASS_REQUIREMENT: u64 = 9;
    const E_POSITION_STILL_LOCKED: u64 = 10;

    public struct SuiPoolKey has copy, drop, store {}
    public struct UsdcPoolKey has copy, drop, store {}

    public struct AdminCap has key, store {
        id: UID,
    }

    public struct VaultState has key {
        id: UID,
        eve_treasury_cap: TreasuryCap<EVE>,
        eulm_treasury_cap: TreasuryCap<EULM>,
        total_nfts_redeemed: u64,
        total_eve_minted: u64,
        total_eulm_minted: u64,
        total_passes_issued: u64,
        total_positions: u64,
        ticket_signer_address: address,
        used_tickets: Table<vector<u8>, bool>,
        redeemed_nfts: Table<ID, bool>,
    }

    public struct StakePass has key, store {
        id: UID,
        owner: address,
        mode: u8,
        min_sui_amount: u64,
        min_usdc_amount: u64,
        eulm_reward_amount: u64,
        lock_duration_ms: u64,
    }

    public struct StakePosition<phantom USDC> has key, store {
        id: UID,
        owner: address,
        mode: u8,
        sui_amount: u64,
        usdc_amount: u64,
        eulm_reward_amount: u64,
        unlock_at_ms: u64,
    }

    public struct VaultInitialized has copy, drop {
        vault_id: ID,
    }

    public struct NftRedeemedForEve has copy, drop {
        player: address,
        nft_id: ID,
        mode: u8,
        eve_amount: u64,
    }

    public struct StakePassIssued has copy, drop {
        player: address,
        nft_id: ID,
        mode: u8,
        pass_id: ID,
        min_sui_amount: u64,
        min_usdc_amount: u64,
        eulm_reward_amount: u64,
        lock_duration_ms: u64,
    }

    public struct StakePositionOpened has copy, drop {
        player: address,
        mode: u8,
        position_id: ID,
        sui_amount: u64,
        usdc_amount: u64,
        eulm_reward_amount: u64,
        unlock_at_ms: u64,
    }

    public struct StakePositionClaimed has copy, drop {
        player: address,
        mode: u8,
        sui_amount: u64,
        usdc_amount: u64,
        eulm_reward_amount: u64,
    }

    public fun initialize(
        eve_treasury_cap: TreasuryCap<EVE>,
        eulm_treasury_cap: TreasuryCap<EULM>,
        ctx: &mut TxContext,
    ) {
        let mut vault = VaultState {
            id: object::new(ctx),
            eve_treasury_cap,
            eulm_treasury_cap,
            total_nfts_redeemed: 0,
            total_eve_minted: 0,
            total_eulm_minted: 0,
            total_passes_issued: 0,
            total_positions: 0,
            ticket_signer_address: @0x0,
            used_tickets: table::new(ctx),
            redeemed_nfts: table::new(ctx),
        };

        dynamic_field::add(&mut vault.id, SuiPoolKey {}, balance::zero<SUI>());

        let admin_cap = AdminCap { id: object::new(ctx) };
        event::emit(VaultInitialized { vault_id: object::id(&vault) });
        transfer::share_object(vault);
        transfer::transfer(admin_cap, ctx.sender());
    }

    public fun set_ticket_signer(
        _admin: &AdminCap,
        vault: &mut VaultState,
        signer_address: address,
    ) {
        vault.ticket_signer_address = signer_address;
    }

    public fun redeem_nft_for_eve(
        vault: &mut VaultState,
        nft_id: ID,
        mode: u8,
        eve_amount: u64,
        expires_at_ms: u64,
        nonce: vector<u8>,
        signature: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let sender = ctx.sender();
        assert!(vault.ticket_signer_address != @0x0, E_TICKET_SIGNER_NOT_SET);
        assert!(!table::contains(&vault.redeemed_nfts, nft_id), E_ALREADY_REDEEMED);
        assert!(clock::timestamp_ms(clock) <= expires_at_ms, E_TICKET_EXPIRED);
        assert!(eve_amount > 0, E_ZERO_AMOUNT);

        let msg = build_eve_ticket_message(sender, nft_id, mode, eve_amount, expires_at_ms, nonce);
        let ticket_hash = hash::blake2b256(&msg);
        assert!(!table::contains(&vault.used_tickets, ticket_hash), E_TICKET_REPLAY);
        assert!(
            sig_verify::verify_personal_message_signature(
                signature,
                msg,
                vault.ticket_signer_address,
            ),
            E_INVALID_TICKET,
        );

        table::add(&mut vault.redeemed_nfts, nft_id, true);
        table::add(&mut vault.used_tickets, ticket_hash, true);

        let minted = coin::mint(&mut vault.eve_treasury_cap, eve_amount, ctx);
        vault.total_nfts_redeemed = vault.total_nfts_redeemed + 1;
        vault.total_eve_minted = vault.total_eve_minted + eve_amount;

        event::emit(NftRedeemedForEve {
            player: sender,
            nft_id,
            mode,
            eve_amount,
        });
        transfer::public_transfer(minted, sender);
    }

    public fun redeem_nft_for_stake_pass(
        vault: &mut VaultState,
        nft_id: ID,
        mode: u8,
        min_sui_amount: u64,
        min_usdc_amount: u64,
        eulm_reward_amount: u64,
        lock_duration_ms: u64,
        expires_at_ms: u64,
        nonce: vector<u8>,
        signature: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let sender = ctx.sender();
        assert!(vault.ticket_signer_address != @0x0, E_TICKET_SIGNER_NOT_SET);
        assert!(!table::contains(&vault.redeemed_nfts, nft_id), E_ALREADY_REDEEMED);
        assert!(clock::timestamp_ms(clock) <= expires_at_ms, E_TICKET_EXPIRED);
        assert!(min_sui_amount > 0 && min_usdc_amount > 0 && eulm_reward_amount > 0, E_ZERO_AMOUNT);

        let msg = build_pass_ticket_message(
            sender,
            nft_id,
            mode,
            min_sui_amount,
            min_usdc_amount,
            eulm_reward_amount,
            lock_duration_ms,
            expires_at_ms,
            nonce,
        );
        let ticket_hash = hash::blake2b256(&msg);
        assert!(!table::contains(&vault.used_tickets, ticket_hash), E_TICKET_REPLAY);
        assert!(
            sig_verify::verify_personal_message_signature(
                signature,
                msg,
                vault.ticket_signer_address,
            ),
            E_INVALID_TICKET,
        );

        table::add(&mut vault.redeemed_nfts, nft_id, true);
        table::add(&mut vault.used_tickets, ticket_hash, true);

        let pass = StakePass {
            id: object::new(ctx),
            owner: sender,
            mode,
            min_sui_amount,
            min_usdc_amount,
            eulm_reward_amount,
            lock_duration_ms,
        };

        vault.total_nfts_redeemed = vault.total_nfts_redeemed + 1;
        vault.total_passes_issued = vault.total_passes_issued + 1;

        event::emit(StakePassIssued {
            player: sender,
            nft_id,
            mode,
            pass_id: object::id(&pass),
            min_sui_amount,
            min_usdc_amount,
            eulm_reward_amount,
            lock_duration_ms,
        });
        transfer::transfer(pass, sender);
    }

    public fun activate_stake_pass<USDC>(
        vault: &mut VaultState,
        pass: StakePass,
        sui: Coin<SUI>,
        usdc: Coin<USDC>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let StakePass {
            id,
            owner,
            mode,
            min_sui_amount,
            min_usdc_amount,
            eulm_reward_amount,
            lock_duration_ms,
        } = pass;
        object::delete(id);

        assert!(owner == ctx.sender(), E_NOT_PASS_OWNER);

        let sui_amount = coin::value(&sui);
        let usdc_amount = coin::value(&usdc);
        assert!(sui_amount >= min_sui_amount && usdc_amount >= min_usdc_amount, E_BELOW_PASS_REQUIREMENT);

        let sui_pool = dynamic_field::borrow_mut<SuiPoolKey, Balance<SUI>>(&mut vault.id, SuiPoolKey {});
        balance::join(sui_pool, coin::into_balance(sui));

        if (!dynamic_field::exists_(&vault.id, UsdcPoolKey {})) {
            dynamic_field::add(&mut vault.id, UsdcPoolKey {}, balance::zero<USDC>());
        };
        let usdc_pool = dynamic_field::borrow_mut<UsdcPoolKey, Balance<USDC>>(&mut vault.id, UsdcPoolKey {});
        balance::join(usdc_pool, coin::into_balance(usdc));

        let unlock_at_ms = clock::timestamp_ms(clock) + lock_duration_ms;
        let position = StakePosition<USDC> {
            id: object::new(ctx),
            owner,
            mode,
            sui_amount,
            usdc_amount,
            eulm_reward_amount,
            unlock_at_ms,
        };

        vault.total_positions = vault.total_positions + 1;

        event::emit(StakePositionOpened {
            player: owner,
            mode,
            position_id: object::id(&position),
            sui_amount,
            usdc_amount,
            eulm_reward_amount,
            unlock_at_ms,
        });
        transfer::transfer(position, owner);
    }

    public fun claim_stake_position<USDC>(
        vault: &mut VaultState,
        position: StakePosition<USDC>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let StakePosition {
            id,
            owner,
            mode,
            sui_amount,
            usdc_amount,
            eulm_reward_amount,
            unlock_at_ms,
        } = position;
        object::delete(id);

        assert!(owner == ctx.sender(), E_NOT_POSITION_OWNER);
        assert!(clock::timestamp_ms(clock) >= unlock_at_ms, E_POSITION_STILL_LOCKED);

        let sui_out = {
            let sui_pool = dynamic_field::borrow_mut<SuiPoolKey, Balance<SUI>>(&mut vault.id, SuiPoolKey {});
            balance::split(sui_pool, sui_amount)
        };
        let usdc_out = {
            let usdc_pool = dynamic_field::borrow_mut<UsdcPoolKey, Balance<USDC>>(&mut vault.id, UsdcPoolKey {});
            balance::split(usdc_pool, usdc_amount)
        };
        let eulm_reward = coin::mint(&mut vault.eulm_treasury_cap, eulm_reward_amount, ctx);

        transfer::public_transfer(coin::from_balance(sui_out, ctx), owner);
        transfer::public_transfer(coin::from_balance(usdc_out, ctx), owner);
        transfer::public_transfer(eulm_reward, owner);

        vault.total_eulm_minted = vault.total_eulm_minted + eulm_reward_amount;
        vault.total_positions = vault.total_positions - 1;

        event::emit(StakePositionClaimed {
            player: owner,
            mode,
            sui_amount,
            usdc_amount,
            eulm_reward_amount,
        });
    }

    fun build_eve_ticket_message(
        sender: address,
        nft_id: ID,
        mode: u8,
        eve_amount: u64,
        expires_at_ms: u64,
        nonce: vector<u8>,
    ): vector<u8> {
        let mut msg = vector::empty<u8>();
        vector::append(&mut msg, b"eve");
        vector::append(&mut msg, object::id_to_bytes(&nft_id));
        vector::append(&mut msg, bcs::to_bytes(&sender));
        vector::append(&mut msg, bcs::to_bytes(&mode));
        vector::append(&mut msg, bcs::to_bytes(&eve_amount));
        vector::append(&mut msg, bcs::to_bytes(&expires_at_ms));
        vector::append(&mut msg, nonce);
        msg
    }

    fun build_pass_ticket_message(
        sender: address,
        nft_id: ID,
        mode: u8,
        min_sui_amount: u64,
        min_usdc_amount: u64,
        eulm_reward_amount: u64,
        lock_duration_ms: u64,
        expires_at_ms: u64,
        nonce: vector<u8>,
    ): vector<u8> {
        let mut msg = vector::empty<u8>();
        vector::append(&mut msg, b"stake_pass");
        vector::append(&mut msg, object::id_to_bytes(&nft_id));
        vector::append(&mut msg, bcs::to_bytes(&sender));
        vector::append(&mut msg, bcs::to_bytes(&mode));
        vector::append(&mut msg, bcs::to_bytes(&min_sui_amount));
        vector::append(&mut msg, bcs::to_bytes(&min_usdc_amount));
        vector::append(&mut msg, bcs::to_bytes(&eulm_reward_amount));
        vector::append(&mut msg, bcs::to_bytes(&lock_duration_ms));
        vector::append(&mut msg, bcs::to_bytes(&expires_at_ms));
        vector::append(&mut msg, nonce);
        msg
    }

    public fun total_nfts_redeemed(vault: &VaultState): u64 { vault.total_nfts_redeemed }
    public fun total_eve_minted(vault: &VaultState): u64 { vault.total_eve_minted }
    public fun total_eulm_minted(vault: &VaultState): u64 { vault.total_eulm_minted }
    public fun total_passes_issued(vault: &VaultState): u64 { vault.total_passes_issued }
    public fun total_positions(vault: &VaultState): u64 { vault.total_positions }
    public fun is_nft_redeemed(vault: &VaultState, nft_id: ID): bool {
        table::contains(&vault.redeemed_nfts, nft_id)
    }
}
