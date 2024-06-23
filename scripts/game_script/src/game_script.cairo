use sncast_std::{
    declare, deploy, invoke, call, DeclareResult, DeployResult, InvokeResult, CallResult, get_nonce, DisplayContractAddress, DisplayClassHash
};

fn main() {
    let owner=0x7e00d496e324876bbc8531f2d9a82bf154d1a04a50218ee74cdd372f75a551a;
    let nft_address =deploy_nft_contract("GameERC721",owner);
}



fn deploy_nft_contract(nft_contract_name: ByteArray,owner_address: ContractAddress) -> ContractAddress {
    let nft_class_hash = declare(nft_contract_name).unwrap();
    let max_fee = 99999999999999999;
    let salt = 0x3;
    let nonce = get_nonce('latest');
    let NAME:ByteArray = "Token Name";
    let SYMBOL:ByteArray= "NNGT";
    let BASE_URI:ByteArray= "https://google.com";
    let mut calldata = ArrayTrait::new();
    NAME.serialize(ref calldata);
    SYMBOL.serialize(ref calldata);
    BASE_URI.serialize(ref calldata);
    let (contract_address, transaction_hash) = deploy(nft_class_hash,@calldata,Option::Some(salt), true, Option::Some(max_fee), Option::Some(nonce)).unwrap();
     println!("NFT Contract deployed to: {} transaction_hash: {}", contract_address,transaction_hash);
    contract_address
}