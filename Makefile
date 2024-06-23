test:
	@snforge test --detailed-resources

clean:
	@snforge clean-cache


format:
	@cargo fmt --check

lint:
	@cargo clippy --all-targets --all-features -- --no-deps -W clippy::pedantic -A clippy::missing_errors_doc -A clippy::missing_panics_doc -A clippy::default_trait_access

fix_typos:
	@typos -w

deploy:
	@sncast --url http://127.0.0.1:5050 script run game_script

run_local_node:
	@docker pull shardlabs/starknet-devnet:latest;
	@docker run -p 5050:5050 shardlabs/starknet-devnet:latest --seed 0