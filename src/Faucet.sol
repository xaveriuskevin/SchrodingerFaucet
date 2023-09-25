// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import {ERC721A} from "ERC721A/ERC721A.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {OperatorFilterer} from "closedsea/OperatorFilterer.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

//Custom Error
error InsufficientBalance();
error SupplyExceeded();
error InvalidSaleStatus();
error InvalidProof();
error WithdrawFailed();
error WhitelistExceeded();
error WalletLimitExceeded();
error InvalidNewSupply();
error InvalidSignature();

contract BaseContract is ERC721A , EIP712 , Ownable , ERC2981 , OperatorFilterer{

  // Base Uri
  string baseURI;

  //Extension for Base Uri
  string public baseExtension = "";
  
  //Total Supply Of the Collection
  uint256 public maxSupply = 10000;

  //Price For the Public Mint
  uint256 public publicPrice = 0.005 ether;

  //Price for the Whitelist Mint
  uint256 public whitelistPrice = 0.0005 ether;

  //Number of Public NFT to Mint
  uint8 public publicMintsPerWallet = 3;

  //Number of Public NFT to Mint
  uint8 public whitelistMintsPerWallet = 3;

  //Root for Merkle Proof
  bytes32 public merkleRoot;

  // Address that signs messages used for minting
  address public mintSigner;

  // Whether operator filtering is enabled
  bool public operatorFilteringEnabled;

  //Status For Sales
  enum SaleStatus {
    CLOSED,
    WHITELIST,
    PUBLIC
  }

  //Default Status --> CLOSED
  SaleStatus public saleStatus;

  constructor(
    string memory _name,
    string memory _symbol,
    string memory _initBaseURI,
    bytes32 _merkleRoot,
    address _signer,
    address _royaltyReceiver
  ) ERC721A(_name, _symbol) EIP712("GreyAreaSnapshot","1.0.0")
   {

    //Setup Base URI
    setBaseURI(_initBaseURI);

    //Merkle Root for whitelist
    merkleRoot = _merkleRoot;

    //Set Mint Signer
    mintSigner = _signer;

    //Setup Marketplace Operator Filtering
    _registerForOperatorFiltering();
    operatorFilteringEnabled = true;

    //5% Enforce Royalites
    _setDefaultRoyalty(_royaltyReceiver, 500);
  }

  // =========================================================================
  //                                 Minting 
  // =========================================================================

  /**
     * Whitelist mint function (Merkle Proof)
     * @param qty Number of NFTs to mint
     * @param proof Proof generated from the backend
  */
  function whitelistMintMerkleProof(uint8 qty, bytes32[] memory proof) external payable {
    if (saleStatus != SaleStatus.WHITELIST) revert InvalidSaleStatus();
    if (_totalMinted() + qty > maxSupply) revert SupplyExceeded();
    if (msg.value < whitelistPrice * qty) revert InsufficientBalance();

    // Validate Merkle Proof
    if(!MerkleProof.verify(proof,merkleRoot,keccak256(abi.encodePacked(msg.sender))))
      revert InvalidProof();

    // Validate that user still has whitelist spots
    uint64 wlMintCount = _getAux(msg.sender) + qty;
    if (wlMintCount > whitelistMintsPerWallet) revert WhitelistExceeded();

    // Update whitelist used count
    _setAux(msg.sender, wlMintCount);

    // Mint tokens
    _mint(msg.sender, qty);
  }

  /**
    * Public mint function.
    * @param qty Number of NFTs to mint
  */
  function publicMint(uint256 qty) external payable {
    if (saleStatus != SaleStatus.PUBLIC) revert InvalidSaleStatus();
    if (_totalMinted() + qty > maxSupply) revert SupplyExceeded();
    if (msg.value < publicPrice * qty) revert InsufficientBalance();

    // Determine number of public mints by substracting whitelist mints from total mints
    if (_numberMinted(msg.sender) - _getAux(msg.sender) + qty > publicMintsPerWallet) {
      revert WalletLimitExceeded();
    }

    // Mint tokens
    _mint(msg.sender, qty);
  }

  /**
    * Owner-only mint function. Used to mint the team treasury.
    * @param qty Number of NFTs to mint
  */
  function ownerMint(uint256 qty) external onlyOwner {
    if (_totalMinted() + qty > maxSupply) revert SupplyExceeded();
    _mint(msg.sender, qty);
  }

  /**
    * View function to get number of whitelist mints an Owner has done.
    * @param _owner Address to check
  */
  function whitelistMintCount(address _owner) external view returns (uint64) {
    return _getAux(_owner);
  }

  /**
    * View function to get number of total mints an Owner has done.
    * @param _owner Address to check
  */
  function totalMintCount(address _owner) external view returns (uint256) {
    return _numberMinted(_owner);
  }
  // =========================================================================
  //                                 Minting Signature
  // =========================================================================

  /**
     * Whitelist mint function (Signature)
     * @param amount Number of NFTs to mint
     * @param signature Signature generated from the backend
  */
  function whitelistMintSignature(uint8 amount, bytes calldata signature) external payable {
    if (saleStatus != SaleStatus.WHITELIST) revert InvalidSaleStatus();
    if (_totalMinted() + amount > maxSupply) revert SupplyExceeded();
    if (msg.value < whitelistPrice * amount) revert InsufficientBalance();

    //Validate signature
    if (recoverAddress(msg.sender, amount ,signature) != mintSigner) revert InvalidSignature();
    
    //Validate that user still has whitelist spots
    uint64 wlMintCount = _getAux(msg.sender) + amount;
    if (wlMintCount > whitelistMintsPerWallet) revert WhitelistExceeded();
    
    // Update whitelist used count
    _setAux(msg.sender, wlMintCount);

    // Mint tokens
    _mint(msg.sender, amount);
  }

  /**
     * Owner-only function to set the mint signer.
     * @param _signer New mint signer
  */
  function setMintSigner(address _signer) external onlyOwner {
      mintSigner = _signer;
  }

  function _hash(address account, uint256 amount) internal view returns (bytes32){
    return _hashTypedDataV4(
        keccak256(
          abi.encode(
            keccak256("GreyAreaSnapshot(address account,uint256 amount)"),
            account,
            amount
          )
        )
      );
  }

  function recoverAddress(address account, uint256 amount, bytes calldata signature) public view returns(address){
      return ECDSA.recover(_hash(account, amount), signature);
  }


  // =========================================================================
  //                             Mint Settings
  // =========================================================================
  
  /**
    * Owner-only function to set the current sale state.
    * @param _saleStatus New sale state
  */
  function setSaleStatus(SaleStatus _saleStatus) external onlyOwner {
    saleStatus = _saleStatus;
  }

  /**
    * Owner-only function to set the mint prices.
    * @param _whitelistPrice New paid allowlist mint price
    * @param _publicPrice New public mint price
  */
  function setPrices(uint256 _whitelistPrice, uint256 _publicPrice) external onlyOwner {
    whitelistPrice = _whitelistPrice;
    publicPrice = _publicPrice;
  }

  /**
    * Owner-only function to set the collection supply. This value can only be decreased.
    * @param _maxSupply The new supply count
  */
  function setMaxSupply(uint256 _maxSupply) external onlyOwner {
    if (_maxSupply >= maxSupply) revert InvalidNewSupply();
    maxSupply = _maxSupply;
  }

  /**
    * Owner-only function to set Maximum Mint Per Wallet & Whitelist.
    * @param _whitelistMint The new Maximum Whitelist Mint
    * @param _publicMint The new Maximum Public Mint
  */
  function setMaxMint(uint8 _whitelistMint , uint8 _publicMint) external onlyOwner {
    whitelistMintsPerWallet = _whitelistMint;
    publicMintsPerWallet = _publicMint;
  }

  /**
    * Owner-only function to withdraw funds in the contract to a destination address.
    * @param receiver Destination address to receive funds
  */
  function withdrawFunds(address receiver) external onlyOwner {
    (bool sent,) = receiver.call{value: address(this).balance}("");
    if (!sent) {
        revert WithdrawFailed();
    }
  }

  // =========================================================================
  //                                 Metadata
  // =========================================================================

  //Set New Base Uri
  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }

  function _baseURI() internal view override returns (string memory) {
    return baseURI;
  }

  //Set New Base Extension
  function setBaseExtension(string memory _newBaseExtension) external onlyOwner {
    baseExtension = _newBaseExtension;
  }

  //Override Function so Token Id Start From 1
  function _startTokenId() internal pure override returns(uint256) {
    return 1;
  }

  // =========================================================================
  //                                 ERC2891
  // =========================================================================

  /**
    * Owner-only function to set the royalty receiver and royalty rate
    * @param receiver Address that will receive royalties
    * @param feeNumerator Royalty amount in basis points. Denominated by 10000
  */
  function setDefaultRoyalty(address receiver, uint96 feeNumerator) public onlyOwner {
    _setDefaultRoyalty(receiver, feeNumerator);
  }

  // =========================================================================
  //                           Operator filtering
  // =========================================================================

  /**
    * Overridden setApprovalForAll with operator filtering.
  */
  function setApprovalForAll(address operator, bool approved)
    public
    override(ERC721A)
    onlyAllowedOperatorApproval(operator)
  {
    super.setApprovalForAll(operator, approved);
  }

  /**
    * Overridden approve with operator filtering.
  */
  function approve(address operator, uint256 tokenId)
    public
    payable
    override(ERC721A)
    onlyAllowedOperatorApproval(operator)
  {
    super.approve(operator, tokenId);
  }

  /**
    * Overridden transferFrom with operator filtering. For ERC721A, this will also add
    * operator filtering for both safeTransferFrom functions.
  */
  function transferFrom(address from, address to, uint256 tokenId)
    public
    payable
    override(ERC721A)
    onlyAllowedOperator(from)
  {
    super.transferFrom(from, to, tokenId);
  }

  /**
    * Owner-only function to toggle operator filtering.
    * @param value Whether operator filtering is on/off.
  */
  function setOperatorFilteringEnabled(bool value) public onlyOwner {
    operatorFilteringEnabled = value;
  }

  function _operatorFilteringEnabled() internal view override returns (bool) {
    return operatorFilteringEnabled;
  }

  // =========================================================================
  //                                  ERC165
  // =========================================================================

  /**
    * Overridden supportsInterface with IERC721 support and ERC2981 support
    * @param interfaceId Interface Id to check
    */
  function supportsInterface(bytes4 interfaceId) public view override(ERC721A, ERC2981) returns (bool) {
    // Supports the following `interfaceId`s:
    // - IERC165: 0x01ffc9a7
    // - IERC721: 0x80ac58cd
    // - IERC721Metadata: 0x5b5e139f
    // - IERC2981: 0x2a55205a
    return ERC721A.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId);
  }
}