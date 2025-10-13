# 🏪 Micro-equity Tokenization for Local Businesses

A Clarity smart contract that enables fractional ownership of local mom-and-pop businesses through tokenized equity shares, empowering community investors to support neighborhood enterprises.

## 🎯 Purpose

Democratize startup capital by allowing community members to invest in local businesses through fractional shares. The smart contract governs dividend distributions, transfer restrictions, and equity management transparently on the Stacks blockchain.

## ✨ Features

- 🏢 **Business Registration**: Local businesses can tokenize their equity
- 💰 **Community Investment**: Investors can purchase fractional shares
- 📊 **Dividend Distribution**: Automated profit sharing based on equity ownership
- 🔒 **Transfer Restrictions**: Configurable holding periods and transfer rules
- 📈 **Investment Tracking**: Complete history of investments and ownership changes

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic understanding of Stacks blockchain and Clarity

### Installation
```bash
git clone <repository-url>
cd Micro-equity-Tokenization-for-Local-Businesses
clarinet check
```

## 📝 Contract Functions

### Public Functions

#### `register-business`
Register a new business for tokenization
```clarity
(register-business "Pizza Corner" u1000 u50000)
```
- `name`: Business name (max 50 characters)
- `total-shares`: Total equity shares to create
- `valuation`: Business valuation in microSTX

#### `invest`
Purchase equity shares in a registered business
```clarity
(invest u1 u100)
```
- `business-id`: Target business ID
- `shares`: Number of shares to purchase

#### `transfer-shares`
Transfer shares to another investor (subject to restrictions)
```clarity
(transfer-shares u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u50)
```

#### `add-to-dividend-pool`
Business owner adds profits for dividend distribution
```clarity
(add-to-dividend-pool u1 u5000)
```

#### `distribute-dividends`
Distribute accumulated dividends to shareholders
```clarity
(distribute-dividends u1)
```

#### `set-transfer-restrictions`
Configure transfer restrictions for business shares
```clarity
(set-transfer-restrictions u1 true u144)
```

### Read-Only Functions

#### `get-business`
Retrieve business information
```clarity
(get-business u1)
```

#### `get-shares`
Check share balance for a holder
```clarity
(get-shares u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

#### `calculate-dividend-share`
Calculate dividend amount for a shareholder
```clarity
(calculate-dividend-share u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

## 🏗️ Usage Example

1. **Register Business**
   ```clarity
   (contract-call? .micro-equity register-business "Local Cafe" u1000 u100000)
   ```

2. **Community Investment**
   ```clarity
   (contract-call? .micro-equity invest u1 u100)
   ```

3. **Add Dividend Pool**
   ```clarity
   (contract-call? .micro-equity add-to-dividend-pool u1 u10000)
   ```

4. **Distribute Dividends**
   ```clarity
   (contract-call? .micro-equity distribute-dividends u1)
   ```

## 🔧 Testing

Run the test suite:
```bash
clarinet test
```

## 🛡️ Security Features

- **Authorization Checks**: Only business owners can modify their business settings
- **Transfer Restrictions**: Configurable holding periods prevent quick flipping
- **Balance Validation**: Prevents over-spending and invalid transfers
- **Active Business Checks**: Ensures operations only on active businesses

## 📊 Data Structures

- **Businesses**: Core business information and metrics
- **Equity Tokens**: Share ownership mapping
- **Investment History**: Complete investment tracking
- **Transfer Restrictions**: Business-specific transfer rules

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests with `clarinet test`
5. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

## 🌟 Impact

Empowering local businesses with accessible capital while giving community members the opportunity to invest in their neighborhood's economic growth.
