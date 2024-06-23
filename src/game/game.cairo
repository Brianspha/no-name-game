use core::traits::Into;
use array::ArrayTrait;
use result::ResultTrait;
use option::OptionTrait;
use starknet_game::game::models::{Player, Prize, PlayToken, PoolPrize};
use debug::PrintTrait;
use zeroable::Zeroable;
use starknet::{ContractAddress, ClassHash, get_caller_address, get_contract_address, get_block_number};
use openzeppelin::utils::snip12::{SNIP12Metadata, StructHash, OffchainMessageHashImpl};
use core::hash::HashStateExTrait;
use hash::{HashStateTrait, Hash};
use poseidon::PoseidonTrait;

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

#[starknet::interface]
pub trait IGame<TContractState> {
    fn play(ref self: TContractState);
    fn submit_score(ref self: TContractState, score: u256, collected: u32);
    fn submit_score_v2(ref self: TContractState, score: u256, collected: u32, nonce: felt252,
        expiry: u64, signature: Array<felt252>);
    fn whitelist_player(ref self: TContractState, player: ContractAddress);
    fn blacklist_player(ref self: TContractState, player: ContractAddress);
    fn set_token_config(ref self: TContractState, play_token: ContractAddress, nft_token: ContractAddress, prize_pool: Array<PoolPrize>);
    fn get_player(ref self: TContractState, player: ContractAddress) -> Player;
    fn set_play_cost(ref self: TContractState, cost: u256);
    fn game_configured(ref self: TContractState) -> bool;
    fn get_players(ref self: TContractState) -> Array<Player>;
    fn player_blacklisted(ref self: TContractState, player: ContractAddress) -> bool;
}

#[starknet::contract]
mod Game {
    use core::traits::Into;
    use array::ArrayTrait;
    use result::ResultTrait;
    use option::OptionTrait;
    use starknet_game::game::models::{Player, Prize, PlayToken, PoolPrize};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::ERC20Component;
    use openzeppelin::token::erc721::ERC721Component;
    use starknet::{ContractAddress, ClassHash, get_caller_address, get_contract_address, get_block_number};
    use starknet_game::nft::inft::{IERC721Dispatcher, IERC721SafeDispatcher, IERC721SafeDispatcherTrait, IERC721DispatcherTrait};
    use starknet_game::erc20::ierc20::{IERC20Dispatcher, IERC20SafeDispatcher, IERC20SafeDispatcherTrait, IERC20DispatcherTrait};
    use core::hash::HashStateExTrait;
    use hash::{HashStateTrait, Hash};
    use poseidon::PoseidonTrait;
    use openzeppelin::account::dual_account::{DualCaseAccount, DualCaseAccountABI};
    use openzeppelin::utils::cryptography::nonces::NoncesComponent;
    use super::{Message, OffchainMessageHashImpl, SNIP12Metadata};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: NoncesComponent, storage: nonces, event: NoncesEvent);

    // Ownable Mixin
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl NoncesImpl = NoncesComponent::NoncesImpl<ContractState>;
    impl NoncesInternalImpl = NoncesComponent::InternalImpl<ContractState>;

    pub mod Errors {
        pub const GAME_NOT_CONFIGURED: felt252 = 'Tokens not Configured';
        pub const ZERO_ADDRESS_CALLER: felt252 = 'Caller is the zero address';
        pub const ALREADY_BLACKLISTED: felt252 = 'Player already blacklisted';
        pub const INSUFFICIENT_FUNDS: felt252 = 'Insufficient funds to play';
        pub const PLAYER_BLACKLISTED: felt252 = 'Player is blacklisted';
        pub const INVALID_PRIZE_POOL: felt252 = 'At least one prize';
        pub const INVALID_SIGNATURE: felt252 = 'Invalid Signature';
    }

    #[storage]
    struct Storage {
        player_info: LegacyMap<ContractAddress, Player>,
        players: LegacyMap<u256, Player>,
        total_players: u256,
        play_token: ContractAddress,
        play_cost: u256,
        nft_token: ContractAddress,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        prize_pool: LegacyMap<u32, PoolPrize>,
        prize_pool_length: u32,
        #[substorage(v0)]
        nonces: NoncesComponent::Storage,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct GameStarted {
        #[key]
        pub player: ContractAddress,
        #[key]
        pub token: PlayToken,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        GameStarted: GameStarted,
        #[flat]
        NoncesEvent: NoncesComponent::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        let owner = get_caller_address();
        self.ownable.initializer(owner);
    }

    /// Required for hash computation.
    impl SNIP12MetadataImpl of SNIP12Metadata {
        fn name() -> felt252 {
            'Game'
        }
        fn version() -> felt252 {
            'v1'
        }
    }

    #[abi(embed_v0)]
    impl GameImpl of super::IGame<ContractState> {
        fn play(ref self: ContractState) {
            let player_sender = get_caller_address();
            let play_token = IERC20Dispatcher { contract_address: self.play_token.read() };
            assert(!player_sender.is_zero(), Errors::ZERO_ADDRESS_CALLER);
            assert(self.game_configured(), Errors::GAME_NOT_CONFIGURED);
            let existing_player = self.player_info.read(player_sender);
            assert(!self.player_blacklisted(player_sender), Errors::PLAYER_BLACKLISTED);
            let current_block: u256 = get_block_number().into();
            let play_token_instance = PlayToken {
                owner: player_sender,
                expiry: current_block + 86400, // @dev valid for one day
            };

            let balance = play_token.balance_of(player_sender);
            let play_cost = self.play_cost.read();

            if !existing_player.active && balance >= play_cost {
                let transferred = play_token.transfer(get_contract_address(), play_cost);
                assert(transferred, Errors::INSUFFICIENT_FUNDS);

                let player = Player {
                    collected: 0,
                    player: player_sender,
                    score: 0,
                    index: self.total_players.read(),
                    active: true,
                    blacklisted: false,
                    play_token: play_token_instance,
                };

                self.player_info.write(player_sender, player);
                self.players.write(self.total_players.read(), player);
                self.total_players.write(self.total_players.read() + 1);
            } else {
                if existing_player.play_token.expiry < current_block && balance >= play_cost {
                    let transferred = play_token.transfer(get_contract_address(), play_cost);
                    assert(transferred, Errors::INSUFFICIENT_FUNDS);
                    self.player_info.write(player_sender, Player {
                        blacklisted: false,
                        player: player_sender,
                        score: 0,
                        collected: 0,
                        index: existing_player.index,
                        active: true,
                        play_token: play_token_instance,
                    });
                } else {
                    assert(false, Errors::INSUFFICIENT_FUNDS);
                }
            }
            self.emit(GameStarted { player: player_sender, token: play_token_instance });
        }

        fn set_token_config(ref self: ContractState, play_token: ContractAddress, nft_token: ContractAddress, prize_pool: Array<PoolPrize>) {
            self.ownable.assert_only_owner();
            let length = prize_pool.len().into();
            assert(length > 0, Errors::INVALID_PRIZE_POOL);
            self.play_token.write(play_token);
            self.nft_token.write(nft_token);
            let mut index = 0;
            loop {
                if index == length {
                    break;
                }
                self.prize_pool.write(index, *prize_pool.at(index));
                index += 1;
            };
            self.prize_pool_length.write(self.prize_pool_length.read() + length);
        }

        fn submit_score(ref self: ContractState, score: u256, collected: u32) {
            let player_sender = get_caller_address();
            let player = self.player_info.read(player_sender);
            if player.active && !player.blacklisted {
                self.player_info.write(player_sender, Player {
                    blacklisted: player.blacklisted,
                    player: player_sender,
                    score: score,
                    collected: collected,
                    index: player.index,
                    active: player.active,
                    play_token: player.play_token,
                });

                self.players.write(player.index, Player {
                    blacklisted: player.blacklisted,
                    player: player_sender,
                    score: score,
                    collected: collected,
                    index: player.index,
                    active: player.active,
                    play_token: player.play_token,
                });
                let length = self.prize_pool_length.read();
                let mut range_index: u32 = 0;
                let mut index: u32 = 0;
                loop {
                    if range_index == collected {
                        break;
                    }
                    let prize = self.prize_pool.read(index);
                    if prize.prize_type == Prize::NFT {
                        let nft = IERC721Dispatcher { contract_address: self.nft_token.read() };
                        nft.mint_token(player_sender);
                    } else if prize.prize_type == Prize::TOKEN {
                        let token = IERC20Dispatcher { contract_address: self.play_token.read() };
                        token.transfer(player_sender, prize.amount);
                    }
                    index %= length;
                    range_index += 1;
                };
            }
        }

        fn submit_score_v2(ref self: ContractState, score: u256, collected: u32, nonce: felt252,
        expiry: u64, signature: Array<felt252>) {
            let player_sender = get_caller_address();
            let player = self.player_info.read(player_sender);
            let message = Message { recipient: player_sender, amount: score, nonce, expiry };
            let owner = self.ownable.owner();

            // Check and increase nonce
            self.nonces.use_checked_nonce(owner, message.nonce);
            let hash = message.get_message_hash(owner);

            let is_valid_signature_felt = DualCaseAccount { contract_address: owner }
                .is_valid_signature(hash, signature);

            // Check either 'VALID' or True for backwards compatibility
            let is_valid_signature = is_valid_signature_felt == starknet::VALIDATED
                || is_valid_signature_felt == 1;
            assert(is_valid_signature, Errors::INVALID_SIGNATURE);
            if player.active {
                self.player_info.write(player_sender, Player {
                    blacklisted: player.blacklisted,
                    player: player_sender,
                    score: score,
                    collected: collected,
                    index: player.index,
                    active: player.active,
                    play_token: player.play_token,
                });

                self.players.write(player.index, Player {
                    blacklisted: player.blacklisted,
                    player: player_sender,
                    score: score,
                    collected: collected,
                    index: player.index,
                    active: player.active,
                    play_token: player.play_token,
                });
            }
        }

        fn whitelist_player(ref self: ContractState, player: ContractAddress) {
            self.ownable.assert_only_owner();
            let player_info = self.player_info.read(player);
            if player_info.active {
                self.player_info.write(player, Player {
                    blacklisted: false,
                    player: player,
                    score: player_info.score,
                    collected: player_info.collected,
                    index: player_info.index,
                    active: player_info.active,
                    play_token: player_info.play_token,
                });
                self.players.write(player_info.index, Player {
                    blacklisted: false,
                    player: player,
                    score: player_info.score,
                    collected: player_info.collected,
                    index: player_info.index,
                    active: player_info.active,
                    play_token: player_info.play_token,
                });
            }
        }

        fn blacklist_player(ref self: ContractState, player: ContractAddress) {
            self.ownable.assert_only_owner();
            let player_info = self.player_info.read(player);
            if player_info.active {
                self.player_info.write(player, Player {
                    blacklisted: true,
                    player: player,
                    score: player_info.score,
                    collected: player_info.collected,
                    index: player_info.index,
                    active: player_info.active,
                    play_token: player_info.play_token,
                });
                self.players.write(player_info.index, Player {
                    blacklisted: true,
                    player: player,
                    score: player_info.score,
                    collected: player_info.collected,
                    index: player_info.index,
                    active: player_info.active,
                    play_token: player_info.play_token,
                });
            }
        }

        fn set_play_cost(ref self: ContractState, cost: u256) {
            self.ownable.assert_only_owner();
            self.play_cost.write(cost);
        }

        fn get_player(ref self: ContractState, player: ContractAddress) -> Player {
            self.player_info.read(player)
        }

        fn game_configured(ref self: ContractState) -> bool {
            !self.play_token.read().is_zero() && !self.nft_token.read().is_zero()
        }

        fn get_players(ref self: ContractState) -> Array<Player> {
            let mut players = ArrayTrait::<Player>::new();
            let mut index = 0;
            let total_players = self.total_players.read();
            loop {
                if index == total_players {
                    break;
                }
                let player = self.players.read(index);
                players.append(player);
                index += 1;
            };
            players
        }

        fn player_blacklisted(ref self: ContractState, player: ContractAddress) -> bool {
            self.player_info.read(player).blacklisted
        }
    }
}
