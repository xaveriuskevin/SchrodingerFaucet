// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.6;
pragma abicoder v2;

import {Test} from "forge-std/Test.sol";
import {SchrodingerFaucet} from "../src/SchrodingerFaucet.sol";
import {console2} from "forge-std/console2.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

//Custom Error
error EmptyTokenInput();
error InvalidAmount();
error UnableMint();
error UnsufficientBalance();

contract SchrodingerFaucetTest is Test,ERC721Holder {
    SchrodingerFaucet public schrodingerFaucet;

    //Set Address Public 
    address _owner = address(0x111);
    address _alice = address(0x112);
    address _butler = address(0x113);

    //Contract can receive Money
    receive() external payable {}

    function setUp() public {
        schrodingerFaucet = new SchrodingerFaucetTest();
    }

    function testSetPrices() public {
     
    }
}