# 🚨 Emergency Access Wallet

A Stacks smart contract that provides emergency access to funds through a trusted contact after a specified time-lock period.

## 🔑 Key Features

- **🛡️ Emergency Contact System**: Designate a trusted contact who can access funds
- **⏰ Time-Lock Protection**: Configurable block-height delay before emergency access
- **🔄 Activity Reset**: Owner activity automatically resets the emergency timer  
- **💰 Multi-User Support**: Anyone can deposit, but only owner controls emergency settings
- **📊 Status Monitoring**: Real-time emergency status and countdown

## 🚀 Quick Start

### Deploy the Contract
```bash
clarinet deploy
```

### Initialize Emergency Settings
```clarity
(contract-call? .emergency-access-wallet initialize 'SP2TRUSTED-CONTACT-ADDRESS u144)
```

### Deposit Funds
```clarity
(contract-call? .emergency-access-wallet deposit u1000000)
```

## 📚 Contract Functions

### 👤 Owner Functions
- `initialize(contact, timelock-blocks)` - Set up emergency access (one-time)
- `set-emergency-contact(contact)` - Update emergency contact
- `set-emergency-timelock(blocks)` - Change time-lock duration
- `remove-emergency-contact()` - Remove emergency access
- `reset-emergency-timer()` - Manually reset activity timer
- `owner-withdraw-all()` - Withdraw all owner funds

### 💸 General Functions  
- `deposit(amount)` - Deposit STX to the wallet
- `withdraw(amount)` - Withdraw your deposited STX
- `emergency-claim()` - Emergency contact claims all funds (after time-lock)

### 📖 Read-Only Functions
- `get-emergency-status()` - Complete emergency status info
- `get-user-balance(user)` - Check user's balance
- `is-emergency-active()` - Check if emergency period is active
- `blocks-until-emergency()` - Blocks remaining until emergency access

## 🔧 Usage Examples

### Setting Up Emergency Access
```clarity
;; Initialize with 1 week timelock (1008 blocks ≈ 1 week)
(contract-call? .emergency-access-wallet initialize 'SP1EMERGENCY-CONTACT u1008)

;; Deposit funds
(contract-call? .emergency-access-wallet deposit u5000000) ;; 5 STX
```

### Emergency Contact Claiming Funds
```clarity
;; Check if emergency is active
(contract-call? .emergency-access-wallet is-emergency-active)

;; Claim all funds (only works if timelock expired)
(contract-call? .emergency-access-wallet emergency-claim)
```

### Resetting the Timer
```clarity
;; Owner can reset timer to prevent emergency access
(contract-call? .emergency-access-wallet reset-emergency-timer)
```

## 🛡️ Security Features

- ✅ Owner-only access to emergency settings
- ✅ Time-lock prevents immediate emergency access
- ✅ Activity tracking resets timer on owner transactions
- ✅ Emergency contact verification required for claims
- ✅ Balance protection with insufficient funds checks

## ⚠️ Important Notes

- Default timelock is **144 blocks** (~24 hours)
- Owner activity **automatically resets** the emergency timer
- Emergency contact can only claim **all remaining contract funds**
- Once initialized, emergency contact can be updated but not removed entirely
- Contract supports multiple users depositing, but emergency features are owner-specific

## 📊 Error Codes

- `u100` - Owner only function
- `u101` - Emergency contact not found  
- `u102` - Unauthorized access
- `u103` - Insufficient balance
- `u104` - Emergency period not active
- `u105` - Emergency still active
- `u106` - Invalid timelock value
- `u107` - Contract already initialized

## 🔗 Integration

Compatible with:
- 🌐 Stacks Web Wallets
- 📱 Mobile Applications  
- 🖥️ Desktop Clients
- 🔧 Smart Contract Integrations

Built with ❤️ for the Stacks ecosystem
