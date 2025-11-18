# 📚 Collaborative Storytelling DAO

> 🎭 A decentralized autonomous organization for crowdsourced interactive fiction where community members vote on story branches and winning paths become NFTs.

## 🌟 Overview

The Collaborative Storytelling DAO revolutionizes creative writing by enabling community-driven narrative development. Writers propose story branches, members vote using governance tokens, and successful storylines are immortalized as NFTs on the Stacks blockchain.

## ✨ Key Features

- 📖 **Story Creation**: Authors can create new stories or add branches to existing narratives
- 🗳️ **Democratic Voting**: Token-weighted voting system for selecting story directions
- 🎨 **NFT Minting**: Winning story branches become collectible NFTs
- 🪙 **Governance Tokens**: Earn tokens by contributing stories and participating in governance
- 🤝 **Contributor Rewards**: Fair distribution of rewards to story contributors
- ⏰ **Time-bound Proposals**: Structured voting periods for decision making

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- [Node.js](https://nodejs.org/) for running tests
- Stacks wallet for mainnet deployment

### Installation

```bash
git clone https://github.com/your-username/Collaborative-Storytelling-DAO
cd Collaborative-Storytelling-DAO
npm install
```

### Local Development

```bash
# Check contract syntax
clarinet check

# Run tests
npm test

# Start local devnet
clarinet integrate
```

## 🎯 Contract Functions

### 🏁 Initialization

```clarity
(contract-call? .StoryDAO initialize)
```

Initializes the contract and mints initial governance tokens to the deployer.

### ✍️ Story Management

#### Create a New Story

```clarity
(contract-call? .StoryDAO create-story 
  "The Quantum Adventure" 
  "In a world where reality shifts with every choice..." 
  none)
```

#### Create a Story Branch

```clarity
(contract-call? .StoryDAO create-story 
  "Chapter 2: The Portal" 
  "Sarah stepped through the shimmering portal..." 
  (some u1))
```

### 🏛️ Governance & Voting

#### Create a Proposal

```clarity
(contract-call? .StoryDAO create-branch-proposal 
  u1 
  (list u2 u3 u4) 
  "Vote for the next chapter direction")
```

#### Vote on Proposal

```clarity
(contract-call? .StoryDAO vote-on-proposal u1 true u1000)
```

#### Execute Winning Proposal

```clarity
(contract-call? .StoryDAO execute-proposal u1)
```

### 🎨 NFT Operations

#### Mint Story NFT

```clarity
(contract-call? .StoryDAO mint-story-nft u1 'SP1PRINCIPAL...)
```

#### Distribute Rewards

```clarity
(contract-call? .StoryDAO distribute-rewards u1)
```

### 📊 Read-Only Functions

```clarity
;; Get story details
(contract-call? .StoryDAO get-story u1)

;; Check user balance
(contract-call? .StoryDAO get-user-balance 'SP1PRINCIPAL...)

;; View proposal status
(contract-call? .StoryDAO get-proposal u1)

;; Get contract statistics
(contract-call? .StoryDAO get-contract-info)
```

## 🎮 Usage Workflow

### For Story Authors 📝

1. **Create Initial Story**: Call `create-story` with your opening narrative
2. **Earn Tokens**: Receive 100 governance tokens for each story contribution
3. **Build Branches**: Add continuation stories that reference parent stories
4. **Participate**: Vote on other authors' proposals using your tokens

### For Community Members 👥

1. **Acquire Tokens**: Contribute stories or receive tokens from authors
2. **Review Proposals**: Examine story branch options and descriptions
3. **Cast Votes**: Use tokens to vote on preferred narrative directions
4. **Collect NFTs**: Own pieces of the collaborative stories as NFTs

### For DAO Members 🏛️

1. **Submit Proposals**: Create voting proposals for story branch selection
2. **Set Parameters**: Adjust voting periods and proposal thresholds (owner only)
3. **Execute Results**: Finalize winning proposals and mint corresponding NFTs
4. **Distribute Rewards**: Share governance tokens with active contributors

## 🔧 Configuration

### Default Settings

- **Voting Period**: 1440 blocks (~1 day)
- **Proposal Threshold**: 1,000,000 micro-tokens
- **Contribution Reward**: 100 tokens per story
- **Distributor Reward**: 500 tokens per contributor

### Admin Functions

```clarity
;; Update voting period (owner only)
(contract-call? .StoryDAO set-voting-period u2880)

;; Adjust proposal threshold (owner only)
(contract-call? .StoryDAO set-proposal-threshold u2000000)
```

## 🏗️ Contract Architecture

### Data Structures

- **Stories**: Title, author, content, parent relationships, canonical status
- **Proposals**: Voting options, tallies, execution status, time bounds
- **Governance**: Token balances, voting records, contributor tracking
- **NFTs**: Unique story tokens linked to canonical narratives

### Error Codes

- `u100`: Owner-only function
- `u101`: Resource not found
- `u102`: Unauthorized access
- `u103`: Invalid proposal
- `u104`: Proposal voting period ended
- `u105`: User already voted
- `u106`: Insufficient token balance
- `u107`: Story already exists
- `u108`: Invalid branch reference

## 🧪 Testing

```bash
# Run all tests
npm test

# Run specific test file
npm test -- StoryDAO.test.ts

# Coverage report
npm run coverage
```

## 📈 Tokenomics

### Governance Token Distribution

- **Story Creation**: +100 tokens per story
- **Proposal Creation**: Requires 1M+ tokens
- **Voting Participation**: Tokens locked during vote
- **Reward Distribution**: +500 tokens per contributor

### NFT Economics

- **Canonical Stories**: Become mintable NFTs after successful proposals
- **Author Rights**: Original authors can mint NFTs of their stories
- **Community Ownership**: Voted stories become community-owned assets

## 🛡️ Security Considerations

- ✅ Input validation for all user-provided data
- ✅ Access control for administrative functions
- ✅ Reentrancy protection through proper state management
- ✅ Time-bound voting to prevent stale proposals
- ✅ Token balance checks before operations

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Clarity](https://clarity-lang.org/) smart contract language
- Powered by [Stacks](https://www.stacks.co/) blockchain
- Testing framework by [Clarinet](https://github.com/hirosystems/clarinet)

---

*Built with ❤️ for the decentralized storytelling community*

# Collaborative Storytelling DAO

