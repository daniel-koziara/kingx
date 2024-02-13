// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract KingX is Context, ERC20 {
    using SafeERC20 for IERC20;

    IERC20 public titanX;
    address public buyAndBurnAddress;
    address public initialLpAddress;
    uint256 public contractStartTime;
    uint256 public constant taxFeePercent = 10;
    address public taxFeeAddress;
    mapping(GenesisTokens => uint256) public genesis;
    address public constant routerAddress =
        0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD; // universal router uniswap
    uint256 public constant MINTING_PERIOD = 17 days;
    uint256 public constant INITIAL_RATE = 1e18; // 1:1 rate
    uint256 public constant FINAL_RATE = 1e17; // 1:0.1 rate
    address constant TITANX_ADDRESS =
        0xF19308F923582A6f7c465e5CE7a9Dc1BEC6665B1;

    // owners
    address constant HELLWHALE_OWNER =
        0x8add03eafe6E89Cc28726f8Bb91096C2dE139fFb;
    address constant DANIEL_KOZIARA_OWNER =
        0x7e603e457d8C0D61351111614ad977315Dfc77aa;
    address constant KRONOS_OWNER = 0x9FEAcbaf3C4277bC9438759058E9E334f866992a;

    // enums
    enum GenesisTokens {
        KINGX,
        TITANX
    }

    event Mint(address indexed user, uint256 amount, uint256 rate);

    constructor(
        address _buyAndBurnAddress,
        address _initialLpAddress
    ) ERC20("KINGX", "KINGX") {
        titanX = IERC20(TITANX_ADDRESS);
        buyAndBurnAddress = _buyAndBurnAddress;
        initialLpAddress = _initialLpAddress;
        contractStartTime = block.timestamp + 1 hours;
        taxFeeAddress = address(this);
        // Mint and send 20B tokens for INITIAL_LP_ACCOUNT
        _mint(initialLpAddress, 20e9 * 1e18);
    }

    function transfer(
        address to,
        uint256 value
    ) public override returns (bool) {
        uint256 valueAfterTax = value;

        if (to == routerAddress) {
            uint256 taxFee = calculateTaxFee(value);
            valueAfterTax = value - taxFee;
            genesis[GenesisTokens.KINGX] += taxFee;
            super.transfer(taxFeeAddress, taxFee);
        }

        super.transfer(to, valueAfterTax);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override returns (bool) {
        uint256 valueAfterTax = value;

        if (from == routerAddress || to == routerAddress) {
            uint256 taxFee = calculateTaxFee(value);
            valueAfterTax = value - taxFee;

            genesis[GenesisTokens.KINGX] += taxFee;
            super.transferFrom(from, taxFeeAddress, taxFee);
        }
        super.transferFrom(from, to, valueAfterTax);

        return true;
    }

    function calculateTaxFee(uint256 amount) private pure returns (uint256) {
        return (amount * taxFeePercent) / 100;
    }

    function mint(uint256 titanXAmount) external {
        require(
            block.timestamp > contractStartTime,
            "KingX_Minting: Minting not allowed yet"
        );

        require(
            block.timestamp <= contractStartTime + MINTING_PERIOD,
            "KingX_Minting: Minting period has ended"
        );

        uint256 genesisAmount = (titanXAmount * 3) / 100;

        titanX.safeTransferFrom(msg.sender, address(this), genesisAmount);
        genesis[GenesisTokens.TITANX] += genesisAmount;

        uint256 transferAmount = titanXAmount - genesisAmount;

        titanX.transferFrom(msg.sender, buyAndBurnAddress, transferAmount);

        uint256 elapsedTimeInSeconds = block.timestamp - contractStartTime;
        uint256 fullHours = elapsedTimeInSeconds / 1 hours;
        uint256 elapsedTimeRoundedToFullHours = fullHours * 1 hours;

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

    function distributeGenesisRewards() external {
        uint256 totalAmountKingX = genesis[GenesisTokens.KINGX];
        uint256 totalAmountTitanX = genesis[GenesisTokens.TITANX];

        if(totalAmountKingX > 0) {
            uint256 amountKingxForDaniel = totalAmountKingX / 2; // 50% for Daniel
            uint256 amountKingxForOthers = totalAmountKingX / 4; // 25% for others
            
            transfer(DANIEL_KOZIARA_OWNER, amountKingxForDaniel);
            transfer(HELLWHALE_OWNER, amountKingxForOthers);
            transfer(KRONOS_OWNER, amountKingxForOthers);

            genesis[GenesisTokens.KINGX] = 0;
        }

        if(totalAmountTitanX > 0) {
            uint256 amountTitanxForDaniel = totalAmountTitanX / 2; // 50% for Daniel
            uint256 amountTitanxForOthers = totalAmountTitanX / 4; // 25% for others

            transfer(DANIEL_KOZIARA_OWNER, amountTitanxForDaniel);
            transfer(HELLWHALE_OWNER, amountTitanxForOthers);
            transfer(KRONOS_OWNER, amountTitanxForOthers);

            genesis[GenesisTokens.TITANX] = 0;
        }

    }
}
