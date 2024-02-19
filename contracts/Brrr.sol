// SPDX-License-Identifier: BUSL
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";

import "./interfaces/IBlast.sol"; // Import the interface

contract Brrr is
    Initializable,
    ERC721EnumerableUpgradeable,
    OwnableUpgradeable,
    ERC2981Upgradeable
{
    // ╔════════════════════════╗
    //          CONSTANTS
    // ╚════════════════════════╝
    address public constant BLAST_YIELD_ADDRESS =
        0x4300000000000000000000000000000000000002;

    // ╔════════════════════════╗
    //          VARIABLES
    // ╚════════════════════════╝
    address public _deployer;
    address public _governor;

    uint256 public _maxSupply;
    uint256 public _principal;
    uint256 public _mintFee;
    uint256 public _tokenIdCounter;

    event Mint(address indexed minter, uint256 tokenId);
    event Burn(address indexed burner, uint256 tokenId);
    event ClaimGas(address indexed claimer, uint256 amount);
    event ClaimYield(address indexed claimer, uint256 amount);
    event PrintItBaby(address indexed printer, uint256 amount);
    event UpdateGovernor(
        address indexed oldGovernor,
        address indexed newGovernor
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 mintFee, uint256 maxSupply) public initializer {
        __ERC721_init("Yield go brrr", "BRRR");
        __ERC721Enumerable_init();
        __ERC2981_init();
        __Ownable_init(msg.sender);

        _maxSupply = maxSupply;
        _mintFee = mintFee;

        // configure gas mechanism
        IBlast(BLAST_YIELD_ADDRESS).configureClaimableGas();
        // @dev: does not work on testnet
        // IBlast(BLAST_YIELD_ADDRESS).configureAutomaticYield();

        // as owner = msg.sender due to the modifier
        IBlast(BLAST_YIELD_ADDRESS).configureGovernor(msg.sender);

        // Set ERC2981 royalty info; fee = 10%
        // NOTE: Config `royaltyFee` before deploying, in BPS.
        _setDefaultRoyalty(msg.sender, 1000);
    }

    function updateGoverner(address newGovernor) external onlyOwner {
        IBlast(BLAST_YIELD_ADDRESS).configureGovernor(newGovernor);
        emit UpdateGovernor(_governor, newGovernor);
        _governor = newGovernor;
    }

    // ╔════════════════════════╗
    //      FUNCTIONALITIES
    // ╚════════════════════════╝

    function mint() external payable {
        require(msg.value == _mintFee, "bruh ETH plz");
        require(totalSupply() + 1 <= _maxSupply, "exceed supply");
        // mint
        _tokenIdCounter++;
        _mint(msg.sender, _tokenIdCounter);
        // accrue principal
        _principal += msg.value;
        emit Mint(msg.sender, _tokenIdCounter);
    }

    function burn(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Caller is not the owner");

        uint256 mintFee = _mintFee;
        require(_principal >= mintFee, "not enough ETH to refund");

        // refund ETH to msg.sender
        (bool sent, ) = payable(msg.sender).call{value: mintFee}("");
        require(sent, "Failed to send ETH");

        _principal -= mintFee;
        // set true for approval check, i.e. isOwner
        _burn(tokenId);
        emit Burn(msg.sender, tokenId);
    }

    function claim() external {
        require(balanceOf(msg.sender) > 0, "no rights to claim");
        require(address(this).balance > _principal, "no yield");
        // will leave the principal in the contract
        uint256 yieldAmount = address(this).balance - _principal;
        IBlast(BLAST_YIELD_ADDRESS).claimYield(
            address(this),
            msg.sender,
            yieldAmount
        );
        emit ClaimYield(msg.sender, yieldAmount);
    }

    function claimGas() external onlyOwner {
        // use msg.sender as it's ensured to be the owner
        uint256 receiveAmount = IBlast(BLAST_YIELD_ADDRESS).claimMaxGas(
            address(this),
            msg.sender
        );
        emit ClaimGas(msg.sender, receiveAmount);
    }

    function previewClaimableYield() external view returns (uint256) {
        return
            address(this).balance > _principal
                ? address(this).balance - _principal
                : 0;
    }

    function printItBaby() external payable {
        require(msg.value > 0, "bruh");
        _principal += msg.value;
        emit PrintItBaby(msg.sender, msg.value);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC721EnumerableUpgradeable, ERC2981Upgradeable)
        returns (bool)
    {
        return
            ERC721Upgradeable.supportsInterface(interfaceId) ||
            ERC2981Upgradeable.supportsInterface(interfaceId);
    }
}
