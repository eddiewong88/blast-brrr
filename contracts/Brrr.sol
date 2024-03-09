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
    //          VARIABLES
    // ╚════════════════════════╝
    IBlast public blast;

    uint256 public maxSupply;
    uint256 public principal;
    uint256 public mintFee;
    uint256 public tokenIdCounter;

    event Mint(address indexed minter, uint256 tokenId);
    event Burn(address indexed burner, uint256 tokenId);
    event ClaimYield(address indexed claimer, uint256 amount);
    event PrintItBaby(address indexed printer, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _blast,
        uint256 _mintFee,
        uint256 _maxSupply
    ) public initializer {
        __ERC721_init("Yield go brrr", "BRRR");
        __ERC721Enumerable_init();
        __ERC2981_init();
        __Ownable_init(msg.sender);

        maxSupply = _maxSupply;
        mintFee = _mintFee;
        blast = IBlast(_blast);

        // configure gas mechanism
        IBlast(_blast).configureClaimableGas();
        // configure yield mechanism
        IBlast(_blast).configureAutomaticYield();

        // Set contract creator as governor
        IBlast(_blast).configureGovernor(msg.sender);

        // Set ERC2981 royalty info; fee = 10%
        // NOTE: Config `royaltyFee` before deploying, in BPS.
        _setDefaultRoyalty(msg.sender, 1000);
    }

    // ╔════════════════════════╗
    //      FUNCTIONALITIES
    // ╚════════════════════════╝

    function mint() external payable {
        require(msg.value == mintFee, "bruh ETH plz");
        require(totalSupply() + 1 <= maxSupply, "exceed supply");
        // mint
        tokenIdCounter++;
        _mint(msg.sender, tokenIdCounter);
        // accrue principal
        principal += msg.value;
        emit Mint(msg.sender, tokenIdCounter);
    }

    function burn(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Caller is not the owner");
        require(principal >= mintFee, "not enough ETH to refund");

        // update states before transfer to prevent reentrancy
        principal -= mintFee;
        // set true for approval check, i.e. isOwner
        _burn(tokenId);
        emit Burn(msg.sender, tokenId);

        // refund ETH to msg.sender
        (bool sent, ) = payable(msg.sender).call{value: mintFee}("");
        require(sent, "Failed to send ETH");
    }

    function claim() external {
        require(balanceOf(msg.sender) > 0, "no rights to claim");
        uint256 yieldAmount = address(this).balance - principal;
        require(yieldAmount > 0, "no yield");
        // will leave the principal in the contract
        (bool sent, ) = payable(msg.sender).call{value: yieldAmount}("");
        require(sent, "Failed to send ETH");
        emit ClaimYield(msg.sender, yieldAmount);
    }

    function previewClaimableYield() external view returns (uint256) {
        return
            address(this).balance > principal
                ? address(this).balance - principal
                : 0;
    }

    function printItBaby() external payable {
        require(msg.value > 0, "bruh");
        principal += msg.value;
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
