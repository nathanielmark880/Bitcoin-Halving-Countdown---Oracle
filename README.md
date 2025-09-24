# 🟠 Bitcoin Halving Countdown & Oracle

A decentralized smart contract that tracks Bitcoin block height via oracle and provides real-time countdown to the next halving event.

## 📋 Features

- 🔍 **Real-time Bitcoin Block Tracking**: Oracle-based Bitcoin blockchain monitoring
- ⏰ **Halving Countdown**: Precise countdown to next halving event  
- 📊 **Historical Data**: Complete halving history and statistics
- 🛡️ **Authorized Oracles**: Secure oracle management system
- 💰 **Reward Calculations**: Current and next block reward calculations
- 📈 **Progress Tracking**: Percentage progress within current halving epoch
- 🎯 **Prediction Market**: Stake STX to predict exact halving blocks and earn rewards
- 🏆 **Competitive Gaming**: Track accuracy and compete with other predictors

## 🚀 Quick Start

### Deploy Contract
```bash
clarinet deploy
```

### Basic Usage

#### Get Halving Countdown
```clarity
(contract-call? .Halving get-halving-countdown)
```

#### Check Current Bitcoin Height
```clarity
(contract-call? .Halving get-contract-info)
```

#### View Halving Progress
```clarity
(contract-call? .Halving get-halving-progress)
```

## 🎯 Halving Prediction Market

### Stake and Predict
```clarity
;; Predict exact halving block (stake 0.1 STX)
(contract-call? .Halving predict-halving-block u5 u1050000)
```

### Check Your Prediction
```clarity
(contract-call? .Halving get-user-prediction u5 tx-sender)
```

### View Market Stats
```clarity
(contract-call? .Halving get-prediction-stats u5)
```

### Early Withdrawal (20% penalty)
```clarity
(contract-call? .Halving withdraw-prediction u5)
```

### Resolve Market (Oracle/Owner Only)
```clarity
(contract-call? .Halving resolve-epoch-predictions u5 u1049995)
```

## 🔧 Oracle Management

### Authorize Oracle (Owner Only)
```clarity
(contract-call? .Halving authorize-oracle 'SP1ABC...)
```

### Update Bitcoin Height (Authorized Oracles Only)
```clarity
(contract-call? .Halving update-bitcoin-height u850000)
```

### Batch Update with Fee Payment
```clarity
(contract-call? .Halving batch-update-oracle-data u850000 u1000000)
```

## 📖 Key Functions

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-halving-countdown` | Complete countdown information |
| `get-blocks-until-halving` | Blocks remaining until next halving |
| `get-current-block-reward` | Current Bitcoin block reward |
| `get-next-block-reward` | Next halving block reward |
| `get-halving-progress` | Progress within current epoch |
| `estimate-time-to-halving` | Time estimates for next halving |
|| `get-network-statistics` | Overall Bitcoin network stats |
|| `get-prediction-stats` | Epoch prediction market statistics |
|| `get-user-prediction` | User's prediction for specific epoch |
|| `calculate-prediction-accuracy` | Accuracy metrics for resolved predictions |

### Public Functions

| Function | Description | Access |
|----------|-------------|---------|
| `authorize-oracle` | Add authorized oracle | Owner Only |
| `revoke-oracle` | Remove oracle authorization | Owner Only |
| `update-bitcoin-height` | Update Bitcoin block height | Oracles Only |
| `set-oracle-fee` | Update oracle fee | Owner Only |
| `emergency-update-height` | Emergency height update | Owner Only |

## 📊 Data Structures

### Halving Countdown Response
```clarity
{
  current-bitcoin-height: uint,
  next-halving-block: uint, 
  blocks-remaining: uint,
  current-reward: uint,
  next-reward: uint,
  progress-percentage: uint,
  estimated-days: uint,
  is-halving-complete: bool
}
```

### Network Statistics
```clarity
{
  total-bitcoins-mined: uint,
  current-halving-epoch: uint,
  total-halvings-occurred: uint,
  blocks-per-halving: uint,
  current-block-reward: uint,
  max-supply: uint
}
```

## ⚡ Constants

- `BLOCKS-PER-HALVING`: 210,000 blocks
- `INITIAL-BLOCK-REWARD`: 50 BTC (5,000,000,000 satoshis)
- Bitcoin block times: ~10 minutes average

## 🔒 Security Features

- Owner-only administrative functions
- Oracle authorization system
- Input validation for block heights
- Fee requirements for oracle updates
- Emergency override capabilities

## 🛠️ Development

### Requirements
- Clarinet CLI
- Stacks blockchain access
- Bitcoin blockchain data source

### Testing
```bash
clarinet test
```

### Type Checking
```bash
clarinet check
```

## 📚 Examples

### Monitor Next Halving
```clarity
;; Get countdown info
(contract-call? .Halving get-halving-countdown)

;; Expected response:
;; {
;;   current-bitcoin-height: u845000,
;;   next-halving-block: u1050000, 
;;   blocks-remaining: u205000,
;;   current-reward: u312500000,
;;   next-reward: u156250000,
;;   estimated-days: u1423
;; }
```

### Oracle Update Flow
```clarity
;; 1. Authorize oracle (owner)
(contract-call? .Halving authorize-oracle 'SP1ORACLE...)

;; 2. Update height (oracle)
(contract-call? .Halving update-bitcoin-height u850000)

;; 3. Check update status
(contract-call? .Halving get-contract-info)
```

## 🎯 Use Cases

- 📱 **DeFi Applications**: Halving-based trading strategies
- 📊 **Analytics Dashboards**: Bitcoin network monitoring
- 🎮 **Prediction Markets**: Halving timing bets
- 🏛️ **Educational Tools**: Bitcoin halving education
- 🔔 **Alert Systems**: Halving notification services

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Add tests for new functionality  
4. Run `clarinet check` and `clarinet test`
5. Submit pull request

## 📄 License

MIT License - see LICENSE file for details

---

**⚠️ Disclaimer**: This contract provides estimates based on oracle data. Actual halving times may vary due to Bitcoin's difficulty adjustment algorithm.
