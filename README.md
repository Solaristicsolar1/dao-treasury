# DAO Treasury with Streaming Payments

A Clarity smart contract implementing a time-locked DAO treasury with streaming payment functionality.

## Features

- **DAO Governance**: Member-based voting system with weighted votes
- **Time-locked Proposals**: Proposals require voting period + timelock before execution
- **Streaming Payments**: Vesting-based payment streams with flexible claiming
- **Treasury Management**: Secure fund management with proper access controls

## Setup Instructions

### Prerequisites

1. Install Clarinet:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
cargo install clarinet-cli
```

2. Install Deno (for tests):
```bash
curl -fsSL https://deno.land/x/install/install.sh | sh
```

3. Install VS Code extensions:
   - Clarity LSP (hirosystems.clarity-lsp)
   - Deno (denoland.vscode-deno)

### Project Setup

1. Navigate to the project directory:
```bash
cd dao-treasury
```

2. Check Clarinet installation:
```bash
clarinet --version
```

3. Verify project structure:
```bash
clarinet check
```

## Running Tests

### Run all tests:
```bash
clarinet test
```

### Run specific test:
```bash
clarinet test --filter "Can add DAO members"
```

### Run tests with coverage:
```bash
clarinet test --coverage
```

## Contract Functions

### Public Functions

- `add-member(member, weight)` - Add DAO member with voting weight
- `create-proposal(title, description, amount, recipient)` - Create funding proposal
- `vote-on-proposal(proposal-id, vote-for)` - Vote on proposal
- `execute-proposal(proposal-id)` - Execute approved proposal (starts timelock)
- `finalize-proposal(proposal-id)` - Finalize proposal after timelock
- `create-stream(recipient, total-amount, duration-blocks)` - Create payment stream
- `claim-stream-advanced(stream-id, claim-percentage)` - Claim from stream with vesting

### Read-only Functions

- `get-proposal(proposal-id)` - Get proposal details
- `get-stream(stream-id)` - Get stream details
- `get-treasury-balance()` - Get current treasury balance
- `get-member(member)` - Get member details

## Development Workflow

1. Make changes to `contracts/dao-treasury.clar`
2. Run `clarinet check` to validate syntax
3. Run `clarinet test` to run test suite
4. Use `clarinet console` for interactive testing

## Testing Scenarios Covered

- Member management and authorization
- Proposal creation and voting
- Time-lock mechanism
- Streaming payment creation and claiming
- Vesting schedule calculations
- Treasury balance tracking
- Error handling and edge cases

## VS Code Integration

The project includes VS Code configuration for:
- Clarity syntax highlighting
- LSP support for code completion
- Deno integration for TypeScript tests
- Automatic formatting on save
