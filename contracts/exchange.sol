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
        token_reserves = token.balanceOf(address(this)) * multiplier;
        eth_reserves = msg.value;
        k = token_reserves * eth_reserves;

        // Pool shares set to a large value to minimize round-off errors
        total_shares = 10**18;
        // Pool creator has some low amount of shares to allow autograder to run
        lps[msg.sender] = 0;
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

    function getLps() public payable returns (uint) {
        return lps[msg.sender];
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
       uint tokenSupply = token.balanceOf(msg.sender);
       uint amountTokens = token_reserves * msg.value / eth_reserves;
       require(amountTokens <= tokenSupply * multiplier, "Not have enough tokens to add liquidity.");

       //Update lps
       for(uint i = 0; i < lp_providers.length; ++i) {
            uint shared = eth_reserves * lps[lp_providers[i]] / total_shares;
            if(lp_providers[i] == msg.sender) {
                shared += msg.value;
            }
            lps[lp_providers[i]] = total_shares * shared / (eth_reserves + msg.value);
        }
        if(lps[msg.sender] == 0) {
            lps[msg.sender] = total_shares * msg.value / (eth_reserves + msg.value);
            lp_providers.push(msg.sender);
        }

       uint token_transfer = (token_reserves + amountTokens) / multiplier - token_reserves / multiplier;
       token.transferFrom(msg.sender, address(this), token_transfer);
       token_reserves += amountTokens;
       eth_reserves += msg.value;
       k = token_reserves * eth_reserves;
    }


    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
    function removeLiquidity(uint amountETH, uint maxSlippagePct)
        public 
        payable
    {
        /******* TODO: Implement this function *******/
        uint amountTokens = token_reserves * amountETH / eth_reserves;
        require(eth_reserves >= amountETH + multiplier && token_reserves >= multiplier + amountTokens, "Not have enough tokens/eth to remove liquidity");
        require(lps[msg.sender] * eth_reserves >= total_shares * amountETH && lps[msg.sender] * token_reserves >= total_shares * amountTokens, "Not provide enough liquidity to remove");
        uint token_expected = amountTokens / multiplier;

        // Update lps
        for(uint i = 0; i < lp_providers.length; ++i) {
            uint shared = eth_reserves * lps[lp_providers[i]] / total_shares;
            if(lp_providers[i] == msg.sender) {
                shared -= amountETH;
            }
            lps[lp_providers[i]] = total_shares * shared / (eth_reserves - amountETH);
        }

        // Check slippage percentage
        uint token_transfer = token_reserves / multiplier - (token_reserves - amountTokens) / multiplier;
        require(token_expected < token_transfer || (token_expected - token_transfer) * 100 * multiplier <= token_expected * maxSlippagePct, "Slippage too high");

        bool success = token.approve(address(this), token_transfer);
        require(success, "Token doesn't approve");
        token.transferFrom(address(this), msg.sender, token_transfer);
        token_reserves -= amountTokens;
        payable(msg.sender).transfer(amountETH);
        eth_reserves -= amountETH;
        k = token_reserves * eth_reserves;
    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity(uint maxSlippagePct)
        external
        payable
    {
        /******* TODO: Implement this function *******/
        uint amountETH = lps[msg.sender] * eth_reserves / total_shares;
        uint amountTokens = lps[msg.sender] * token_reserves / total_shares;
        require(lps[msg.sender] > 0, "Not provide any liquidity");
        require(eth_reserves >= amountETH + multiplier && token_reserves >= multiplier + amountTokens, "Not have enough tokens/eth to remove liquidity");
        uint token_expected = amountTokens / multiplier;
        
        //Update lps
        for(uint i = 0; i < lp_providers.length; ++i) {
            uint shared = eth_reserves * lps[lp_providers[i]] / total_shares;
            if(lp_providers[i] == msg.sender) {
                shared = 0;
            }
            lps[lp_providers[i]] = total_shares * shared / (eth_reserves - amountETH);
        }

        // Check slippage percentage
        uint token_transfer = token_reserves / multiplier - (token_reserves - amountTokens) / multiplier;
        require(token_expected < token_transfer || (token_expected - token_transfer) * 100 * multiplier <= token_expected * maxSlippagePct, "Slippage too high");

        bool success = token.approve(address(this), token_transfer);
        require(success, "Token doesn't approve");
        token.transferFrom(address(this), msg.sender, token_transfer);
        token_reserves -= amountTokens;
        payable(msg.sender).transfer(amountETH);
        eth_reserves -= amountETH;
        k = token_reserves * eth_reserves;
    }
    /***  Define additional functions for liquidity fees here as needed ***/


    /* ========================= Swap Functions =========================  */ 

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    function swapTokensForETH(uint amountTokens, uint maxSlippagePct)
        external 
        payable
    {
        /******* TODO: Implement this function *******/
        amountTokens *= multiplier;
        require(amountTokens <= token.balanceOf(msg.sender) * multiplier, "Sender doesn't have enough token to swap");
        uint amountETH = eth_reserves - k / (token_reserves + amountTokens);
        require(eth_reserves > amountETH && address(this).balance > amountETH, "Not have enough ETH to swap");
        uint eth_expected = amountTokens * eth_reserves / token_reserves;

        // Check slippage percentage
        // price eth/token decreases
        require((eth_expected - amountETH) * 100 * multiplier <= eth_expected * maxSlippagePct, "Swap too many tokens");

        token_reserves += amountTokens;
        token.transferFrom(msg.sender, address(this), amountTokens / multiplier);
        payable(msg.sender).transfer(amountETH);
        eth_reserves -= amountETH;
    }

    // Function swapETHForTokens: Swaps ETH for your tokens
    // ETH is sent to contract as msg.value
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens(uint maxSlippagePct)
        external
        payable 
    {
        /******* TODO: Implement this function *******/
        uint amountTokens = token_reserves - k / (eth_reserves + msg.value);
        require(token_reserves > amountTokens, "Cannot remove all tokens from the pool");
        uint token_transfer = token_reserves / multiplier - (token_reserves - amountTokens) / multiplier;
        uint token_expected = (msg.value * token_reserves) / (eth_reserves * multiplier);

        // Check slippage percentage
        // Price token/eth decrease
        // expect x eth -> token_reserve / eth_reserve * x token
        // reality x eth -> token_reserve - k / (eth_reserve + x) token
        require((token_expected - token_transfer) * 100 * multiplier <= token_expected * maxSlippagePct, "Swap too much ETH");

        eth_reserves += msg.value;
        bool success = token.approve(address(this), token_transfer);
        require(success, "Token doesn't approve");
        token.transferFrom(address(this), msg.sender, token_transfer);
        token_reserves -= amountTokens;
    }
}