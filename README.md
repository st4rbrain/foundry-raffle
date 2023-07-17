# Raffle Smart Contract

### What is Raffle?
This repo contains a sample automated Raffle smart contract made using the Foundry framework.<br> This protocol allows users to enter the Raffle for a given interval and right after the completion of that interval, the winner is picked randomly. The Raffle then again starts and this goes on.
<br><br>

## Getting Started
### Requirements
  - **[git](https://git-scm.com/downloads)**
      - Download and install git from this link
      - Verify installation by running `git --version` in the terminal to see an output like `git version x.y.z`
  - **[foundry](https://book.getfoundry.sh/)**
      - Run the following command in the terminal:
          `curl -L https://foundry.paradigm.xyz | bash`
      - Open a new terminal and run `foundryup`
      - Verify installation by running `forge --version` in the terminal to see an output like `forge 0.2.0`
### Setup
  - Run these commands in the terminal: <br><br>
      ```bash
      git clone https://github.com/Cyfrin/raffle-smart-contract
      cd raffle-smart-contract
      forge build
      ```
      Setup completed!<br>
      **terminal refers to bash terminal in Linux or [WSL](https://learn.microsoft.com/en-us/windows/wsl/install)*
<br><br>
## Usage
### Testing
  1. Run all the test functions on the local [Anvil](https://book.getfoundry.sh/anvil/) chain
          
     ```bash
     forge test
     ```
  2. Run a particular test function<br>
     ```bash
     forge test --match-test testFunctionName
     ```
  3. Forked testing to test on a simulated testnet or mainnet<br>
     ```bash
     forge test --fork-url $SEPOLIA_RPC_URL
     ```
<br>

**To check the approximation of the percentage of the contract covered in tests**
```bash
forge coverage
```
<br> 

### Deployment
  1. **Deploy to Anvil Local Chain**
      - Temporary Anvil deployment (can't do any interactions with the contract deployed)
  
          ```bash
          forge script scripts/DeployRaffle.s.sol
          ```
      - Deploy to local Anvil chain
          - Open a second terminal and fire Anvil by running the command: &nbsp;&nbsp; `anvil`
          - Copy any of the ten private keys shown in the terminal
          - Run this command in the first terminal:
  
            ```bash
            forge script script/DeployRaffle.s.sol --rpc-url http://127.0.0.1:8545 --private-key <COPIED_PRIVATE_KEY> --broadcast
            ```
            <br>
  2. **Deploy to Testnets or Mainnets**
     
      - Setup Environment Variables
         
          - Create a `.env` file in the working directory similar to `.env.example` in this repo
          - Set your own `SEPOLIA_RPC_URL` and `PRIVATE_KEY`<br><br>
      - &#x1F4A1; **`PRIVATE_KEY`** : &nbsp;&nbsp;Private Key of any account of your Web3 wallet (like Metamask)
      > NOTE: For development purposes, please use an account that doesn't have any real funds associated with it
      
      - &#x1F4A1; **`SEPOLIA_RPC_URL`**: &nbsp;&nbsp; API of the Sepolia testnet node you're working with. Get this for free from [Alchemy](https://alchemy.com/?a=673c802981)<br><br>
      - You can also add your `ETHERSCAN_API_KEY` if you want to verify your contract on [Etherscan](https://etherscan.io/)
      - Get some testnet ETH from [Chainlink faucet](https://faucets.chain.link/)
      - Deploy by running the command:
    
        ```bash
        forge script script/DeployRaffle.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
        ```
        - This will set up a ChainlinkVRF Subscription for you. If you already have one, update it in the scripts/HelperConfig.s.sol file. It will also automatically add your contract as a consumer.
      - Register a Chainlink Automation Upkeep <br> 
        Go to <a href='https://automation.chain.link'>automation.chain.link</a> and register new upkeep. Choose Custom logic as your trigger mechanism for automation.
  <br>

# Thank You!
If you find this useful, feel free to contribute to this project by adding more functionality or finding any bugs 🤝

## You can also donate! 💸
**Metamsk Account Address**: 0x2726c81f38f445aEBA4D54cc74CBca4f51597D17