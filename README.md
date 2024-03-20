# blast-brrr

yield go brrr

Front-end demo: https://uat-blast-brrr.web.app

## Deploy

- verify _max_supply_ & _mint_fee_ in `Deploy.s.sol`
- Add private key to `.env` file. (copy `.env.example` and remove `.example`)
- Run

  - replace `xxx` with private key

  for testnet:

        forge script scripts/Deploy.s.sol --rpc-url blast_sepolia --broadcast --private-key xxx

  for mainnet:

      forge script scripts/Deploy.s.sol --rpc-url blast_mainnet --broadcast --private-key xxx

## Manual configure automatic yield (required)

Use this if can't config within constructor. it fails simulation but works on-chain

- replace `xxx` with private key
- replace `proxy_addr` with proxy address that just deployed

  for testnet:

        cast send --private-key xxx --rpc-url blast_sepolia 0x4300000000000000000000000000000000000002 "configureAutomaticYieldOnBehalf(address)" proxy_addr

  for mainnet:

        cast send --private-key xxx --rpc-url blast_mainnet 0x4300000000000000000000000000000000000002 "configureAutomaticYieldOnBehalf(address)" proxy_addr

## Verify:

- Run

  - replace `<impl_address>` with implementation address)
  - replace `<api_address> ` with api address \
    testnet: https://api-sepolia.blastscan.io/api \
    mainnet: https://api.blastscan.io/api \
    (see https://api-sepolia.blastscan.io/api for updated detail)

  ```
  forge verify-contract <impl_address> Brrr --verifier-url <api_address> --etherscan-api-key abc --watch
  ```

- Note: can just put anything for `etherscan-api-key` just to bypass command line arg
- Then go to proxy address on chain explorer and we should be able to verify proxy just with clicking because implementation already verified
