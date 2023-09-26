// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


//Custom Error
error EmptyTokenInput();
error InvalidAmount();
error UnableMint();
error InsufficientBalance();

contract EsperFaucet is Ownable {
  using SafeERC20 for IERC20;


  struct UserInfo {
    uint256 claimToken; // Amount Mint
    uint256 mintTime; // Time when Mint
  }

  struct TokenInfo {
    address token;
    uint256 amount;
    uint8 decimal;
  }

  TokenInfo[] private _tokens; // array for all existing token info
  mapping(address => uint256) public userCooldown; 

  uint256 private rangeMintTime = 1 days;

  // constructor()Ownable(msg.sender){}
  
  /**************************************************/
  /****************** PUBLIC VIEWS ******************/
  /**************************************************/

  /**
  * @dev Get remaining duration before the end of the sale
  */
  function getRangeTime() external view returns (uint256){
    return rangeMintTime;  
  }

  /**
   * @dev Returns the number of available tokens
   */
  function tokenLength() external view returns (uint256) {
    return _tokens.length;
  }

  /**
   * @dev Returns a token from its "index"
   */
  function getTokenAddressByIndex(uint256 index) external view returns (address) {
    if (index >= _tokens.length) return address(0);
    return _tokens[index].token;
  }

  /****************************************************************/
  /****************** EXTERNAL PUBLIC FUNCTIONS  ******************/
  /****************************************************************/

  /**
   * @dev Mint Faucet 
   */
  function claim() external {
    
    if(_tokens.length == 0) revert EmptyTokenInput();
    if(userCooldown[msg.sender] != 0){
      if(block.timestamp - userCooldown[msg.sender] < rangeMintTime) revert UnableMint();
    }

    for(uint256 i; i < _tokens.length; i++){
      //Check Balance of Token
      uint256 existingTokenBalance = IERC20(_tokens[i].token).balanceOf(address(this));
      //Compare existing token balance with required amount
      if(existingTokenBalance < _tokens[i].amount) revert InsufficientBalance();

      IERC20(_tokens[i].token).safeTransfer(msg.sender, _tokens[i].amount);
    }

    userCooldown[msg.sender] = block.timestamp;

  }
  
  /****************************************************************/
  /************************** Setters *****************************/
  /****************************************************************/

  /**
    * Owner-only function to set the Range time for each mint.
    * @param rangeTime New range time
  */
  function setRangeTime(uint256 rangeTime) external onlyOwner {
    rangeMintTime = rangeTime;
  }

 /**
   * @dev add Tokens
   *
   * Must only be called by the owner
  */
  function addTokens(address token , uint256 amount , uint8 decimal) external onlyOwner {
    if(amount == 0) revert InvalidAmount();
    TokenInfo memory newToken = TokenInfo(token,amount,decimal);
    _tokens.push(newToken);
  }

  /**
   * @dev remove Tokens
   *
   * Must only be called by the owner
  */
  function removeTokens(uint256 index) external onlyOwner {
    _tokens[index] = _tokens[_tokens.length - 1];
    _tokens.pop();
  }

   /**
   * @dev Update Tokens
   *
   * Must only be called by the owner
  */
  function UpdateTokens(uint256 index , address token , uint256 amount , uint8 decimal) external onlyOwner {
    if(amount == 0) revert InvalidAmount();
    _tokens[index] = _tokens[_tokens.length - 1];
    _tokens.pop();

    TokenInfo memory newToken = TokenInfo(token,amount,decimal);
    _tokens[_tokens.length] = newToken;

    IERC20(token).safeTransfer(address(this), amount);
  }

}
