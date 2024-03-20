// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import './token.sol';
import "hardhat/console.sol";


contract TokenExchange is Ownable {
    string public exchange_name = "TokenDealer";

    // TODO: paste token contract address here
    // e.g. tokenAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3
    address tokenAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3;// TODO: paste token contract address here
    Token public token = Token(tokenAddr);                                

    // Liquidity pool for the exchange
    uint private token_reserves = 0;
    uint private eth_reserves = 0;

    // Fee Pools
    uint private token_fee_reserves = 0;
    uint private eth_fee_reserves = 0;

    // Liquidity pool shares
    mapping(address => uint) private lps;
    mapping(address => uint) private token_reward;
    mapping(address => uint) private eth_reward;

    // For Extra Credit only: to loop through the keys of the lps mapping
    address[] private lp_providers;      

    // Total Pool Shares
    uint private total_shares = 0;

    // liquidity rewards
    uint private swap_fee_numerator = 3;                
    uint private swap_fee_denominator = 100;

    // Constant: x * y = k
    uint private k;

    uint private multiplier = 10**18;

    constructor() Ownable(msg.sender) {}
    

    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens)
        external
        payable
        onlyOwner
    {
        // This function is already implemented for you; no changes needed.

        // require pool does not yet exist:
        require (token_reserves == 0, "Token reserves was not 0");
        require (eth_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require (msg.value > 0, "Need eth to create pool.");
        uint tokenSupply = token.balanceOf(msg.sender);
        require(amountTokens <= tokenSupply, "Not have enough tokens to create the pool");
        require (amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        token_reserves = token.balanceOf(address(this));
        eth_reserves = msg.value;
        k = token_reserves * eth_reserves;

        // Pool shares set to a large value to minimize round-off errors
        total_shares = 10**6;
        // Pool creator has some low amount of shares to allow autograder to run
        lps[msg.sender] = 100;
    }

    // For use for ExtraCredit ONLY
    // Function removeLP: removes a liquidity provider from the list.
    // This function also removes the gap left over from simply running "delete".
    function removeLP(uint index) private {
        require(index < lp_providers.length, "specified index is larger than the number of lps");
        lp_providers[index] = lp_providers[lp_providers.length - 1];
        lp_providers.pop();
    }

    // Function getSwapFee: Returns the current swap fee ratio to the client.
    function getSwapFee() public view returns (uint, uint) {
        return (swap_fee_numerator, swap_fee_denominator);
    }

    // Function getReserves
    function getReserves() public view returns (uint, uint) {
        return (eth_reserves, token_reserves);
    }

    function getLps() public view returns (uint, uint) {
        return (lps[msg.sender], total_shares);
    }

    function updateLps(address _address, uint token_transfer, uint8 option) public {

        if(option == 0) {
            lps[_address] = 0;
            total_shares -= total_shares * token_transfer / token_reserves;
        }

        if(option == 1) {
            if(lps[_address] == 0) {
                lp_providers.push(_address);
            }
            lps[_address] += total_shares * token_transfer / token_reserves;
            total_shares += total_shares * token_transfer / token_reserves;
        }

        if(option == 2) {
            lps[_address] -= total_shares * token_transfer / token_reserves;
            total_shares -= total_shares * token_transfer / token_reserves;
        }
    }

    function updateReward(uint amountTokens, uint amountETH) public {
        
        // Each lp has 0.03 reward of the amount after swapping
        for(uint i = 0; i < lp_providers.length; ++i) {
            token_reward[lp_providers[i]] += amountTokens;
            eth_reward[lp_providers[i]] += amountETH;
            token_fee_reserves += amountTokens * lps[lp_providers[i]] * swap_fee_numerator / (swap_fee_denominator * total_shares);
            eth_fee_reserves += amountETH * lps[lp_providers[i]] * swap_fee_numerator / (swap_fee_denominator * total_shares);
        }
    }

    function getReward(address _address) public returns(uint, uint) {
        uint token_fee = token_reward[_address] * lps[_address] * swap_fee_numerator / (swap_fee_denominator * total_shares);
        uint eth_fee = eth_reward[_address] * lps[_address] * swap_fee_numerator / (swap_fee_denominator * total_shares);
        token_reward[_address] = 0;
        eth_reward[_address] = 0;
        token_fee_reserves -= token_fee;
        eth_fee_reserves -= eth_fee;
        return (token_fee, eth_fee);
    }

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================
    
    /* ========================= Liquidity Provider Functions =========================  */ 

    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value).
    // You can change the inputs, or the scope of your function, as needed.
    function addLiquidity() 
        external 
        payable
    {
       /******* TODO: Implement this function *******/
       require (msg.value > 0, "Need eth to add liquidity.");
       uint amountTokens = token_reserves * msg.value / eth_reserves;
       require(amountTokens <= token.balanceOf(msg.sender), "Not have enough tokens to add liquidity.");

       token.transferFrom(msg.sender, address(this), amountTokens);
       token_reserves += amountTokens;
       eth_reserves += msg.value;
       k = token_reserves * eth_reserves;

       //Update lps
       updateLps(msg.sender, amountTokens, 1);
    }


    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
    function removeLiquidity(uint amountETH, uint minTokenReceive)
        public 
        payable
    {
        /******* TODO: Implement this function *******/
        uint amountTokens = token_reserves * amountETH / eth_reserves;
        require(eth_reserves > amountETH && token_reserves > amountTokens, "Not have enough tokens/eth to remove liquidity");

        // Check slippage percentage
        require(lps[msg.sender] * token_reserves >= total_shares * amountTokens, "Not provide enough liquidity to remove");
        require(amountTokens >= minTokenReceive, "Slippage");

        (uint token_fee, uint eth_fee) = getReward(msg.sender);
        bool success = token.approve(address(this), amountTokens + token_fee);
        require(success, "Token doesn't approve");
        token.transferFrom(address(this), msg.sender, amountTokens + token_fee);
        token_reserves -= amountTokens;
        payable(msg.sender).transfer(amountETH + eth_fee);
        eth_reserves -= amountETH;
        k = token_reserves * eth_reserves;

        updateLps(msg.sender, amountTokens, 2);
    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity(uint minTokenReceive)
        external
        payable
    {
        /******* TODO: Implement this function *******/
        uint amountETH = lps[msg.sender] * eth_reserves / total_shares;
        uint amountTokens = lps[msg.sender] * token_reserves / total_shares;
        require(eth_reserves > amountETH && token_reserves > amountTokens, "Not have enough tokens/eth to remove liquidity");
        
        // Check slippage percentage
        require(lps[msg.sender] * token_reserves >= total_shares * amountTokens, "Not provide enough liquidity to remove");
        require(amountTokens >= minTokenReceive, "Slippage");

        (uint token_fee, uint eth_fee) = getReward(msg.sender);
        bool success = token.approve(address(this), amountTokens + token_fee);
        require(success, "Token doesn't approve");
        token.transferFrom(address(this), msg.sender, amountTokens + token_fee);
        token_reserves -= amountTokens;
        payable(msg.sender).transfer(amountETH + eth_fee);
        eth_reserves -= amountETH;
        k = token_reserves * eth_reserves;

        updateLps(msg.sender, amountTokens, 0);
    }
    /***  Define additional functions for liquidity fees here as needed ***/


    /* ========================= Swap Functions =========================  */ 

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    function swapTokensForETH(uint amountTokens, uint minETHReceive)
        external 
        payable
    {
        /******* TODO: Implement this function *******/
        require(amountTokens <= token.balanceOf(msg.sender), "Sender doesn't have enough token to swap");
        uint amountETH = eth_reserves - k / (token_reserves + amountTokens);
        require(eth_reserves > amountETH && address(this).balance > amountETH, "Not have enough ETH to swap");

        // Check slippage percentage
        // price eth/token decreases
        require(amountETH >= minETHReceive, "Slippage");

        updateReward(amountTokens, amountETH);
        token_reserves += amountTokens;
        token.transferFrom(msg.sender, address(this), amountTokens);
        payable(msg.sender).transfer(amountETH - amountETH * swap_fee_numerator / swap_fee_denominator);
        eth_reserves -= amountETH;
        k = token_reserves * eth_reserves;
    }

    // Function swapETHForTokens: Swaps ETH for your tokens
    // ETH is sent to contract as msg.value
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens(uint minTokenReceive)
        external
        payable 
    {
        /******* TODO: Implement this function *******/
        uint amountTokens = token_reserves - k / (eth_reserves + msg.value);
        require(token_reserves > amountTokens, "Not have enough tokens to swap");

        // Check slippage percentage
        // Price token/eth decrease
        // expect x eth -> token_reserve / eth_reserve * x token
        // reality x eth -> token_reserve - k / (eth_reserve + x) token
        require(amountTokens >= minTokenReceive, "Slippage");

        updateReward(amountTokens, msg.value);
        eth_reserves += msg.value;
        bool success = token.approve(address(this), amountTokens - amountTokens * swap_fee_numerator / swap_fee_denominator);
        require(success, "Token doesn't approve");
        token.transferFrom(address(this), msg.sender, amountTokens - amountTokens * swap_fee_numerator / swap_fee_denominator);
        token_reserves -= amountTokens;
        k = token_reserves * eth_reserves;
    }
}