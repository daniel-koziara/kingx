// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KingX is ERC20, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public titanX;
    address public buyAndBurnAddress;
    address public initialLpAddress;
    address public genesisAddress;

    uint256 public constant MINTING_PERIOD = 17 days;
    uint256 public constant INITIAL_RATE = 1e18; // 1:1 rate
    uint256 public constant FINAL_RATE = 1e17; // 1:0.1 rate
    uint256 public contractStartTime;

    event Mint(address indexed user, uint256 amount, uint256 rate);

    constructor(
        address _buyAndBurnAddress,
        address _initialLpAddress,
        address _titanxAddress,
        address _genesisAddress
    ) ERC20("KINGX", "KINGX") Ownable(msg.sender) {
        require(
            _buyAndBurnAddress != address(0),
            "BuyAndBurnAddress cannot be the zero address"
        );
        require(
            _initialLpAddress != address(0),
            "InitialLpAddress cannot be the zero address"
        );

        require(
            _genesisAddress != address(0),
            "GenesisAddress cannot be the zero address"
        );
        require(
            _titanxAddress != address(0),
            "TitanxAddress cannot be the zero address"
        );

        titanX = IERC20(_titanxAddress);
        buyAndBurnAddress = _buyAndBurnAddress;
        initialLpAddress = _initialLpAddress;
        contractStartTime = block.timestamp + 1 hours;
        genesisAddress = _genesisAddress;

        // Mint and send 20B tokens for INITIAL_LP_ACCOUNT
        _mint(initialLpAddress, 20e9 * 1e18);
    }

    function mint(uint256 titanXAmount) external {
        require(
            block.timestamp >= contractStartTime,
            "KingX_Minting: Minting not allowed yet"
        );

        require(
            block.timestamp <= contractStartTime + MINTING_PERIOD,
            "KingX_Minting: Minting period has ended"
        );

        uint256 genesisAmount = (titanXAmount * 3) / 100;
        titanX.safeTransferFrom(msg.sender, genesisAddress, genesisAmount);

        uint256 transferAmount = titanXAmount - genesisAmount;

        titanX.safeTransferFrom(msg.sender, buyAndBurnAddress, transferAmount);

        uint256 elapsedTimeInSeconds = block.timestamp - contractStartTime;
        uint256 elapsedTimeRoundedToFullHours = (elapsedTimeInSeconds /
            1 hours) * 1 hours;

        uint256 rate = INITIAL_RATE -
            ((INITIAL_RATE - FINAL_RATE) * elapsedTimeRoundedToFullHours) /
            MINTING_PERIOD;

        uint256 mintAmount = (titanXAmount * rate) / 1e18;

        if (mintAmount > titanXAmount) {
            revert("KingX_MintAmount: Mint amount is too high");
        }

        _mint(msg.sender, mintAmount);

        emit Mint(msg.sender, mintAmount, rate);
    }

    // The function is used to withdraw tokens that were sent incorrectly.
    function skim(address token, address to) external onlyOwner {
        IERC20(token).safeTransfer(to, IERC20(token).balanceOf(address(this)));
    }
}
