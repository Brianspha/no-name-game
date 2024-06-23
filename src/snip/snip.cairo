use openzeppelin::utils::snip12::{SNIP12Metadata, StructHash, OffchainMessageHashImpl};

use core::hash::HashStateExTrait;
use hash::{HashStateTrait, Hash};
use poseidon::PoseidonTrait;
use starknet::ContractAddress;

const MESSAGE_TYPE_HASH: felt252 =
    0x120ae1bdaf7c1e48349da94bb8dad27351ca115d6605ce345aee02d68d99ec1;

#[derive(Copy, Drop, Hash)]
struct Message {
    recipient: ContractAddress,
    amount: u256,
    nonce: felt252,
    expiry: u64
}

impl StructHashImpl of StructHash<Message> {
    fn hash_struct(self: @Message) -> felt252 {
        let hash_state = PoseidonTrait::new();
        hash_state.update_with(MESSAGE_TYPE_HASH).update_with(*self).finalize()
    }
}

impl SNIP12MetadataImpl of SNIP12Metadata {
    fn name() -> felt252 { 'DAPP_NAME' }
    fn version() -> felt252 { 'v1' }
}

fn get_hash(
    account: ContractAddress,
    recipient: ContractAddress,
    amount: u256,
    nonce: felt252,
    expiry: u64
) -> felt252 {
    let message = Message {
        recipient,
        amount,
        nonce,
        expiry
    };
    message.get_message_hash(account)
}