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