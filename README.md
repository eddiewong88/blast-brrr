# blast-brrr

yield go brrr

## TO DEPLOY:

- Add private key to `.env` file. (copy `.env.example` and remove `.example`)
- Run the following command in terminal, config `<sRPC_URL>` to be real Blast's testnet rpc url.

```
forge script scripts/Deploy.s.sol --rpc-url https://sepolia.blast.io --broadcast --slow
```
