# Solana Batch Transfer Contract

Welcome to the wildest SPL token batch transfer contract on Solana! This bad boy, built with Anchor, lets you yeet tokens to multiple wallets in one slick transaction. Open-source, community-driven, and ready to make your DeFi life epic. 🌌

## Why This Rocks 🎉
- 💥 Batch Blast: Send SPL tokens to a ton of addresses in a single tx. No more spamming the blockchain!
- 🔒 Safe & Sound: Checks targets, amounts, and ATAs so you don’t screw up. We got your back.
- 🦀 Anchor-Powered: Rust + Anchor = clean, geeky, and bulletproof code.
- 🚨 Error Swagger: Mess up? We’ll throw you sassy error messages like InvalidATA or InvalidInput.

## Prerequisites 🛠️
- Solana CLI
- Rust
- Anchor CLI
- Node.js (for testing/deployment)

## Installation
1. Clone repository:
   ```bash
   git clone <repository-url>
   cd batch-transfer
   ```
   
2.Install dependencies:
   ```bash
   anchor build
   ```

3.Configure Solana CLI:
  ```base
  solana config set --url <rpc-url>
  ```

## Usage
### Deploy Contract
1.Build and deploy:
  ```base
  anchor deploy
  ```

2.Note program ID from deployment.

### Interact with Contract
Call ```batch_transfer``` using client SDK or custom script. Example:

```javascript
  const program = new Program(idl, programId, provider);
  await program.rpc.batchTransfer(targets, amounts, {
    accounts: {
      user: wallet.publicKey,
      userTokenAccount: userATA,
      form: formAccount,
      tokenProgram: TOKEN_PROGRAM_ID,
      mint: tokenMint,
    },
    remainingAccounts: targetATAs,
  }); 
```
     
### Parameters
- ```targets```: Array of recipient public keys.
- ```amounts```: Array of token amounts (must match ```targets``` length).
- ```remaining_accounts```: ATAs for each recipient.

## Error Codes
- ```InvalidInput```: Mismatch between targets and amounts, or empty inputs.
- ```InvalidATA```: Provided ATA does not match expected ATA.
- ```InvalidOwner```: User token account owner does not match signer.

## Security Notes
- Secure ```form``` account authorization.
- Validate inputs client-side to reduce on-chain errors.
- Use correct ATAs to prevent token loss.

## Contributing
Submit issues or pull requests to improve functionality or fix bugs.

## License
MIT License. See LICENSE for details.
