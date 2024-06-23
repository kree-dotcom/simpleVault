# simpleVault
Starknet hackathon entry, autoinvesting contract

Basic implementation of an auto investing vault contract. 

Current functionality:

- Allows a user to deposit and withdraw the ERC20 token associated with the vault
- Interacts with third party contracts to make use of deposits to earn users interest

Planned functionality:

-  Alters deposit and withdrawals based on virtual price
- Borrows against user deposit to increase yield
- auto compounds interest


Please note none of these contracts have been audited or tested fully, do not use in production.

Currently known deficiencies:
- There is no function to claim STRK rewards for users nor a system to allocate these proportional to deposits.
This requires a merkle proof and an extensive accounting system that tracks user's time in the system as well as
users who have left but were owed rewards from a past claim period.
- The accounting system is basic and does not allocate interest received to users. It appears zTokens used by ZkLend
are rebasing and so would need a tailored share system to correctly allocate the increased quantity to depositors.
- 
