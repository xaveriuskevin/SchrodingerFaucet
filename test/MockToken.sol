// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract MockToken is Ownable, ERC20Burnable {
  /**
   * @dev Constructor.
   * @param wallet owner's wallet of the token
   * @param totalSupply total supply of tokens in lowest units (depending on decimals)
   */
  constructor(
    string memory name,
    string memory symbol,
    address wallet,
    uint256 totalSupply
  ) Ownable() ERC20(name, symbol) {
    _mint(wallet, totalSupply);
    transferOwnership(wallet);
  }
}
