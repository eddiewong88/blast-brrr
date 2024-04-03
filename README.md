# blast-brrr

Front-end demo: https://uat-blast-brrr.web.app

install `yarn`

## Test

To test `yarn test`

## Deploy

- verify _max_supply_ & _mint_fee_ in `Deploy.s.sol`
- Add private key to `.env` file. (copy `.env.example` and remove `.example`)
- Run

  - replace `xxx` with private key

  for testnet:

        forge script scripts/Deploy.s.sol --rpc-url blast_sepolia --broadcast

  for mainnet:

      forge script scripts/Deploy.s.sol --rpc-url blast_mainnet --broadcast

## Upgrade

- Check `Upgrade.s.sol` params and values

  for mainnet:

        forge script scripts/Upgrade.s.sol --rpc-url blast_mainnet --broadcast

## Manual configure automatic yield (required for Blast chain)

Use this if can't config within constructor. it fails simulation but works on-chain

- replace `xxx` with private key
- replace `proxy_addr` with proxy address that just deployed

  for testnet:

        cast send --private-key xxx --rpc-url blast_sepolia 0x4300000000000000000000000000000000000002 "configureAutomaticYieldOnBehalf(address)" "proxy_addr"

  for mainnet:

        cast send --private-key xxx --rpc-url blast_mainnet 0x4300000000000000000000000000000000000002 "configureAutomaticYieldOnBehalf(address)" "proxy_addr"

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

- On testnet, can just put anything for `etherscan-api-key` just to bypass command line arg
- Then go to proxy address on chain explorer and we should be able to verify proxy just with clicking because implementation already verified
