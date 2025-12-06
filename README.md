Milestone-Based Project Funding Smart Contract

This project implements a secure milestone-based project funding system using an Ethereum smart contract.
Unlike traditional crowdfunding where project creators receive all funds upfront, this contract locks funding on-chain and releases it milestone by milestone only after approval — eliminating trust issues and ensuring accountability.

Features
Feature	Description
Project Creation	Owner defines approver, milestones, and required total funding
Funding	Multiple contributors can fund until target is reached
State Transition	Project automatically becomes Active once fully funded
Milestone Completion	Owner marks a milestone as completed
Milestone Approval	Approver independently verifies completion
Payment Release	Owner receives milestone payout only after approval
Cancellation	Owner can cancel during Funding phase
Refunds	Contributors can claim refunds if project is cancelled
Technologies Used
Technology	Purpose
Solidity (^0.8.28)	Smart contract
Hardhat v3	Development framework
ethers.js v6	Blockchain interaction
TypeScript	Testing + scripts
Mocha + Chai	Unit testing

## 📂 Project Structure

```text
milestone-funding/
│
├── contracts/
│   └── MilestoneFunding.sol
│
├── test/
│   └── MilestoneFunding.ts
│
├── scripts/
│   └── deploy.ts
│
├── hardhat.config.ts
└── README.md
```

Smart Contract Overview

Each project contains:

Owner

Approver

TotalFundingRequired

TotalFunded

Status: Funding → Active → Completed (or Cancelled)

Milestones[]: description, amount, completion/approval/payment flags

Contributions mapping: enables accurate refunds

Funds remain locked in the contract until the milestone is approved, making this a trustless escrow-style crowdfunding model.

🖥️ Running the Project
1️⃣ Install dependencies
npm install

2️⃣ Compile Smart Contract
npx hardhat compile

3️⃣ Run all tests
npx hardhat test


Expected output:

9 passing

🌐 Deployment Instructions
Start local blockchain
npx hardhat node

Deploy to local network

In a new terminal:

npx hardhat run scripts/deploy.ts --network localhost


Example output:

MilestoneFunding deployed to: 0xABC123... 

💡 Demo Interaction (Hardhat Console)
npx hardhat console --network localhost
