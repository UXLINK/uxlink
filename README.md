![image](https://uxuy.hk.ufileos.com/uxlink-social-layer.png)

## Overview 

An open source repository of all UXLINK contracts maintained by UXLINK Labs. This repo contains the UXLink core contracts. 
UXLINK Social Growth Layer is an infrastructure Layer which contains chain abstraction, accounts abstraction, universal gas, social protocols, etc.

## Launch DApp

- Web: [dapp.uxlink.io](https://dapp.uxlink.io)
- Line DApp: [lineapp.uxlink.io](https://lineapp.uxlink.io)
- INVITE Mini App: [https://t.me/UXINVITE_bot/app](https://t.me/UXINVITE_bot/app?startapp=inviteCode=9408)

## Socials / Contact

- Twitter: [@UXLINKofficial](https://x.com/UXLINKofficial)
- Telegram: [@uxlink_bot](https://t.me/uxlink_bot)
- Email: admin@uxlink.io

## Whitepapers
- https://docs.uxlink.io/layer/whitepaper/white-paper
  
## Community
UXLink has an active and ever growing community. 

[Telegram UXLINK® ](https://t.me/uxlinkofficial)

[Telegram UXLINK® 2](https://t.me/uxlinkofficial2)

They are the primary communication used for day to day communication,
answering questions, and aggregating UXLink related content. Take
a look at the [community blogs](https://blog.uxlink.io/) for more information
regarding UXLink social accounts, news, and networking.

## 🗂 Directory Structure

| Folder      | Contents                                                                       |
| ----------- | ------------------------------------------------------------------------------ |
| `contracts/`| Shared UXLink core contracts.                                                  |
| `documents/`| Shared Development documents and UXLINK contract descriptions.                 |
| `scripts/`  | UXLINK core contract running script.                                           |

## Getting Started

### Install

1. Install the required packages
   ```
   npm install
   ```

2. Open hardhat.config.js file and add the following scripts (we use the https://www.alchemy.com/ service):
  
   ```
   const PRIVATE_KEY = "your-wallet-private-key";
   const alchemyNetworkUrl = "https://arb-goerli.alchemyapi.io/v2/your-api-key";
   ```

### Compile
  ```
  npx hardhat compile
  ```
### Test
  ```
  npx hardhat test
  ```

### test all contacrts
  ```
  npx hardhat test --network arb_goerli
  ```

### Test one contacrt
  ```
  npx hardhat test --network arb_goerli ./test/your_test_script.js
  ```
### Deploy Contracts
  ```
  npx hardhat run --network arb_goerli ./scripts/your_test_script.js
  ```
