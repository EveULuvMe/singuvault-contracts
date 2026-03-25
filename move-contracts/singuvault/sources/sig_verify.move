/// ED25519 personal-message signature verification (reused from SinguHunt)
module singuvault::sig_verify {
    use sui::ed25519;
    use sui::hash;
    use sui::address;

    const E_INVALID_SIGNATURE: u64 = 100;
    const E_INVALID_SCHEME: u64 = 101;
    const E_INVALID_KEY_LENGTH: u64 = 102;

    /// Intent prefix for personal messages: [3, 0, 0]
    const INTENT_PERSONAL_MESSAGE: vector<u8> = x"030000";

    /// Verify an ED25519 signature over a personal message and check that
    /// the signer matches the expected address.
    public fun verify_personal_message_signature(
        signature: vector<u8>,
        message: vector<u8>,
        expected_signer: address,
    ): bool {
        // signature layout: [scheme_flag(1) | raw_sig(64) | public_key(32)]
        assert!(vector::length(&signature) == 97, E_INVALID_SIGNATURE);
        assert!(*vector::borrow(&signature, 0) == 0x00, E_INVALID_SCHEME); // 0x00 = ED25519

        let mut raw_sig = vector::empty<u8>();
        let mut public_key = vector::empty<u8>();
        let mut i = 1;
        while (i < 65) {
            vector::push_back(&mut raw_sig, *vector::borrow(&signature, i));
            i = i + 1;
        };
        while (i < 97) {
            vector::push_back(&mut public_key, *vector::borrow(&signature, i));
            i = i + 1;
        };
        assert!(vector::length(&public_key) == 32, E_INVALID_KEY_LENGTH);

        // Derive signer address: blake2b256([scheme_flag | pubkey])
        let mut to_hash = vector::empty<u8>();
        vector::push_back(&mut to_hash, 0x00);
        vector::append(&mut to_hash, public_key);
        let addr = address::from_bytes(hash::blake2b256(&to_hash));
        if (addr != expected_signer) return false;

        // Build intent message: intent_prefix ++ bcs(len) ++ message
        let msg_len = vector::length(&message);
        let mut intent_msg = INTENT_PERSONAL_MESSAGE;
        // BCS ULEB128 encoding for message length
        let mut len = msg_len;
        loop {
            let byte = ((len & 0x7F) as u8);
            len = len >> 7;
            if (len == 0) {
                vector::push_back(&mut intent_msg, byte);
                break
            } else {
                vector::push_back(&mut intent_msg, byte | 0x80);
            }
        };
        vector::append(&mut intent_msg, message);
        let digest = hash::blake2b256(&intent_msg);

        ed25519::ed25519_verify(&raw_sig, &public_key, &digest)
    }
}
