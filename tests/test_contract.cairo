use starknet::storage_read_syscall;
use starknet::{
    contract_address_const, get_block_info, ContractAddress, Felt252TryIntoContractAddress, TryInto,
    Into, OptionTrait, class_hash::Felt252TryIntoClassHash, get_caller_address,
    get_contract_address,
};
use core::integer::BoundedInt;
use result::ResultTrait;
use serde::Serde;
use box::BoxTrait;
use integer::u256;
use openzeppelin::token::erc20::ERC20Component;
use snforge_std::{declare, cheat_caller_address, cheat_chain_id_global,ContractClassTrait, CheatSpan,cheat_caller_address_global,stop_cheat_caller_address_global,spy_events, SpyOn, EventSpy, EventFetcher,
    Event, EventAssertions};
use starknet_game::game::game::{Message,IGameSafeDispatcher,IGameSafeDispatcherTrait,IGameDispatcher,IGameDispatcherTrait};
use starknet_game::game::models::{PoolPrize,Prize,Player};
use array::{ArrayTrait, SpanTrait, ArrayTCloneImpl};
use starknet_game::erc20::erc20::GameERC20::{Event::ERC20Event};
use starknet_game::nft::nft::GameERC721::{Event::ERC721Event};
use starknet_game::nft::inft::{IERC721Dispatcher, IERC721SafeDispatcher, IERC721SafeDispatcherTrait, IERC721DispatcherTrait};
use starknet_game::erc20::ierc20::{IERC20Dispatcher, IERC20SafeDispatcher, IERC20SafeDispatcherTrait, IERC20DispatcherTrait};
use openzeppelin::utils::snip12::{STARKNET_DOMAIN_TYPE_HASH, StarknetDomain, StructHash, OffchainMessageHashImpl, SNIP12Metadata};
use core::hash::HashStateExTrait;
use hash::{HashStateTrait, Hash};
use poseidon::PoseidonTrait;
use poseidon::poseidon_hash_span;


fn deploy_game_contract(game_contract_name: ByteArray) -> ContractAddress {
    let contract = declare(game_contract_name).unwrap();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}
fn deploy_nft_contract(nft_contract_name: ByteArray,owner_address: ContractAddress) -> ContractAddress {
    let nft_class_hash = declare(nft_contract_name).unwrap();
    let NAME:ByteArray = "Token Name";
    let SYMBOL:ByteArray= "NNGT";
    let BASE_URI:ByteArray= "https://google.com";
    let mut calldata = ArrayTrait::new();
    NAME.serialize(ref calldata);
    SYMBOL.serialize(ref calldata);
    BASE_URI.serialize(ref calldata);
    let (contract_address, _) = nft_class_hash.deploy(@calldata).unwrap();
    contract_address
}

    fn deploy_token_contract(token_contract_name: ByteArray,owner_address: ContractAddress) -> ContractAddress {
            let token_class_hash = declare(token_contract_name).unwrap();
            let INITIAL_SUPPLY: u256 = 999999999999999999999;
            let mut NAME: ByteArray = "Token Name";
            let mut SYMBOL: ByteArray= "NNGT";
            let mut calldata = ArrayTrait::new();
            INITIAL_SUPPLY.serialize(ref calldata);
            owner_address.serialize(ref calldata);
            NAME.serialize(ref calldata);
            SYMBOL.serialize(ref calldata);
            let (contract_address, _) = token_class_hash.deploy(@calldata).unwrap();
            contract_address
    }

#[test]
fn test_play() {
    let owner_address: ContractAddress = contract_address_const::<1>();
    cheat_caller_address_global( owner_address);
    let contract_address= deploy_game_contract("Game");
    let dispatcher = IGameDispatcher { contract_address };
    let token_contract_address = deploy_token_contract("GameERC20",owner_address);
    let nft_contract_address = deploy_nft_contract("GameERC721",owner_address);
    let mut prize_pool= ArrayTrait::<PoolPrize>::new();
    prize_pool.append(PoolPrize { amount: 1, prize_type: Prize::NFT });
    prize_pool.append(PoolPrize { amount: 3, prize_type: Prize::NFT });
    prize_pool.append(PoolPrize { amount: 100, prize_type: Prize::TOKEN });
    prize_pool.append(PoolPrize { amount: 1000, prize_type: Prize::TOKEN });
    dispatcher.set_token_config(token_contract_address,nft_contract_address,prize_pool);
    dispatcher.set_play_cost(1000000);
    stop_cheat_caller_address_global();
    let player_address: ContractAddress = contract_address_const::<2>();
    let token_contract = IERC20Dispatcher { contract_address: token_contract_address };
    token_contract.mint(player_address, 100000000000000000000);
    assert(token_contract.balance_of(player_address)==100000000000000000000, 'Tokens not minted');
    cheat_caller_address_global(player_address);
    token_contract.approve(contract_address, BoundedInt::max());
    assert(token_contract.allowance(player_address, contract_address)==BoundedInt::max(), 'Tokens not approved');
    dispatcher.play();
    let player_instance = dispatcher.get_player(player_address);
    assert(player_instance.player==player_address, 'User not played');
    stop_cheat_caller_address_global();
}

#[test]
#[should_panic(expected: ('Tokens not Configured',))]
fn test_fail_play() {
    let owner_address: ContractAddress = contract_address_const::<1>();
    cheat_caller_address_global( owner_address);
    let contract_address= deploy_game_contract("Game");
    let dispatcher = IGameDispatcher { contract_address };
    stop_cheat_caller_address_global();
    let player_address: ContractAddress = contract_address_const::<2>();
    cheat_caller_address_global(player_address);
    dispatcher.play();
    let player_instance = dispatcher.get_player(player_address);
    assert(player_instance.player==player_address, 'User not played');
    stop_cheat_caller_address_global();
}

#[test]
#[should_panic(expected: ('Insufficient funds to play',))]
fn test_insufficient_funds_play() {
    let owner_address: ContractAddress = contract_address_const::<1>();
    let player_address: ContractAddress = contract_address_const::<2>();
    cheat_caller_address_global( owner_address);
    let contract_address= deploy_game_contract("Game");
    let dispatcher = IGameDispatcher { contract_address };
    let token_contract_address = deploy_token_contract("GameERC20",owner_address);
    let nft_contract_address = deploy_nft_contract("GameERC721",owner_address);
    let mut prize_pool= ArrayTrait::<PoolPrize>::new();
    prize_pool.append(PoolPrize { amount: 1, prize_type: Prize::NFT });
    prize_pool.append(PoolPrize { amount: 3, prize_type: Prize::NFT });
    prize_pool.append(PoolPrize { amount: 100, prize_type: Prize::TOKEN });
    prize_pool.append(PoolPrize { amount: 1000, prize_type: Prize::TOKEN });
    dispatcher.set_token_config(token_contract_address,nft_contract_address,prize_pool);
    dispatcher.set_play_cost(1000000);
    stop_cheat_caller_address_global();
    cheat_caller_address_global(player_address);
    dispatcher.play();
}

#[test]
#[should_panic(expected: ('Player is blacklisted',))]
fn test_blacklisted_play() {
    let owner_address: ContractAddress = contract_address_const::<1>();
    let player_address: ContractAddress = contract_address_const::<2>();
    cheat_caller_address_global( owner_address);
    let contract_address= deploy_game_contract("Game");
    let dispatcher = IGameDispatcher { contract_address };
    let token_contract_address = deploy_token_contract("GameERC20",owner_address);
    let nft_contract_address = deploy_nft_contract("GameERC721",owner_address);
    let mut prize_pool= ArrayTrait::<PoolPrize>::new();
    prize_pool.append(PoolPrize { amount: 1, prize_type: Prize::NFT });
    prize_pool.append(PoolPrize { amount: 3, prize_type: Prize::NFT });
    prize_pool.append(PoolPrize { amount: 100, prize_type: Prize::TOKEN });
    prize_pool.append(PoolPrize { amount: 1000, prize_type: Prize::TOKEN });
    dispatcher.set_token_config(token_contract_address,nft_contract_address,prize_pool);
    dispatcher.set_play_cost(1000000);
    stop_cheat_caller_address_global();
    let token_contract = IERC20Dispatcher { contract_address: token_contract_address };
    token_contract.mint(player_address, 100000000000000000000);
    assert(token_contract.balance_of(player_address)==100000000000000000000, 'Tokens not minted');
    cheat_caller_address_global(player_address);
    token_contract.approve(contract_address, BoundedInt::max());
    assert(token_contract.allowance(player_address, contract_address)==BoundedInt::max(), 'Tokens not approved');
    dispatcher.play();
    stop_cheat_caller_address_global();
    cheat_caller_address_global( owner_address);
    dispatcher.blacklist_player(player_address);
    stop_cheat_caller_address_global();
    cheat_caller_address_global(player_address);
    dispatcher.play();
}

#[test]
fn test_play_get_players() {
    let owner_address: ContractAddress = contract_address_const::<1>();
    let player_address1: ContractAddress = contract_address_const::<2>();
    let player_address2: ContractAddress = contract_address_const::<3>();
    cheat_chain_id_global(12);
    let mut message = Message { recipient: player_address1, amount: 100, nonce: 0, expiry: 1000 };
    let mut domain = StarknetDomain { name: 'Game', version: 'v1', chain_id: 12, revision: 1 };
    let mut signature = poseidon_hash_span(
        array!['StarkNet Message', domain.hash_struct(), owner_address.into(), message.hash_struct()]
            .span()
    );
    cheat_caller_address_global( owner_address);
    let contract_address= deploy_game_contract("Game");
    let dispatcher = IGameDispatcher { contract_address };
    let token_contract_address = deploy_token_contract("GameERC20",owner_address);
    let nft_contract_address = deploy_nft_contract("GameERC721",owner_address);
    let mut prize_pool= ArrayTrait::<PoolPrize>::new();
    prize_pool.append(PoolPrize { amount: 1, prize_type: Prize::NFT });
    prize_pool.append(PoolPrize { amount: 1, prize_type: Prize::NFT });
    prize_pool.append(PoolPrize { amount: 100, prize_type: Prize::TOKEN });
    prize_pool.append(PoolPrize { amount: 1000, prize_type: Prize::TOKEN });
    dispatcher.set_token_config(token_contract_address,nft_contract_address,prize_pool);
    dispatcher.set_play_cost(1000000);
    stop_cheat_caller_address_global();
    let token_contract = IERC20Dispatcher { contract_address: token_contract_address };
    token_contract.mint(player_address1, 100000000000000000000);
    token_contract.mint(player_address2, 100000000000000000000);
    assert(token_contract.balance_of(player_address1)==100000000000000000000, 'Tokens not minted');
    cheat_caller_address_global(player_address1);
    token_contract.approve(contract_address, BoundedInt::max());
    assert(token_contract.allowance(player_address1, contract_address)==BoundedInt::max(), 'Tokens not approved');
    dispatcher.play();
    dispatcher.submit_score(1010,10);
    stop_cheat_caller_address_global();
    cheat_caller_address_global(player_address2);
    token_contract.approve(contract_address, BoundedInt::max());
    assert(token_contract.allowance(player_address2, contract_address)==BoundedInt::max(), 'Tokens not approved');
    dispatcher.play();
    dispatcher.submit_score(100,10);
    stop_cheat_caller_address_global();
    let players=dispatcher.get_players();
    assert(players.len()==2, 'Players not fetched');
}