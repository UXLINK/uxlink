use anchor_lang::prelude::*;
// use anchor_lang::system_program;
use anchor_spl::{
    associated_token::get_associated_token_address,
    token::{self, Mint, Token, TokenAccount, Transfer},
};

declare_id!("4zws8jvSDAgGVJw1Cs7Kj9m4XbHtan9D8YKPKaJVbrz5");

#[program]
pub mod batch_transfer {
    use super::*;

    pub fn batch_transfer<'info>(
        ctx: Context<'_, '_, '_, 'info, BatchTransfer<'info>>,
        targets: Vec<Pubkey>,
        amounts: Vec<u64>,
    ) -> Result<()> {
        require!(!targets.is_empty(), ErrorCode::InvalidInput);
        require!(targets.len() == amounts.len(), ErrorCode::InvalidInput);

        // 获取剩余账户迭代器
        let remaining_accounts = &mut ctx.remaining_accounts.iter();

        for (i, target) in targets.iter().enumerate() {
            let target_ata_info = next_account_info(remaining_accounts)?;

            let expected_ata = get_associated_token_address(target, &ctx.accounts.mint.key());
            require!(target_ata_info.key() == expected_ata, ErrorCode::InvalidATA);

            // 使用 delegate_authority 作为 authority
            let cpi_accounts = Transfer {
                from: ctx.accounts.user_token_account.to_account_info(),
                to: target_ata_info.clone(),
                authority: ctx.accounts.form.to_account_info(),
            };

            token::transfer(
                CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts),
                amounts[i],
            )?;
        }
        Ok(())
    }

    
}

#[error_code]
pub enum ErrorCode {
    #[msg("The number of target addresses does not match the number of amounts.")]
    InvalidInput,
    #[msg("The provided associated token account (ATA) does not match the expected ATA for the target address.")]
    InvalidATA,
    #[msg("Invalid account owner.")]
    InvalidOwner,
}
// 指令参数

#[derive(Accounts)]
pub struct BatchTransfer<'info> {
    // Source token account
    #[account(mut, signer)]
    pub user: Signer<'info>,
    #[account(
        mut,
        constraint = user_token_account.owner == user.key() @ ErrorCode::InvalidOwner
    )]
    pub user_token_account: Account<'info, TokenAccount>,
    /// CHECK: This account is only used for signature verification, no data storage required
    pub form: UncheckedAccount<'info>,
    pub token_program: Program<'info, Token>,
    pub mint: Account<'info, Mint>,
}
