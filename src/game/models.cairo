use core::traits::Into;
use starknet::{ContractAddress, ClassHash};

use snforge_std::{declare, ContractClassTrait};

#[derive(Drop, Copy, starknet::Store, Serde, PartialEq)]
enum Prize {
    TOKEN,
    NFT
}


#[derive(Drop, Copy, starknet::Store, Serde, PartialEq)]
struct PoolPrize {
    prize_type:Prize, 
    amount: u256 
}

#[derive(Drop, Copy, starknet::Store, Serde, PartialEq)]
struct PlayToken {
    #[key]
    owner: ContractAddress,
    expiry: u256
}

#[derive(Drop, Copy, starknet::Store, Serde, PartialEq)]
struct Player {
    collected: u32,
    #[key]
    player: ContractAddress,
    score:u256,
    index:u256,
    active:bool,
    blacklisted:bool,
    play_token:PlayToken
}


