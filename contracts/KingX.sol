// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract KingX is ERC20 {
    using SafeERC20 for IERC20;

    IUniswapV3Factory public v3Factory;

    IERC20 public titanX;
    address public buyAndBurnAddress;
    address public initialLpAddress;
    address public uniswapFactoryAddress;
    // owners
    address constant HELLWHALE_OWNER =
        0x8add03eafe6E89Cc28726f8Bb91096C2dE139fFb;
    address constant DANIEL_KOZIARA_OWNER =
        0x7e603e457d8C0D61351111614ad977315Dfc77aa;
    address constant KRONOS_OWNER = 0x9FEAcbaf3C4277bC9438759058E9E334f866992a;

    uint256 public constant taxFeePercent = 1;
    uint256 public constant MINTING_PERIOD = 17 days;
    uint256 public constant INITIAL_RATE = 1e18; // 1:1 rate
    uint256 public constant FINAL_RATE = 1e17; // 1:0.1 rate
    uint256 public constant taxFeePercentBps = 100;
    uint256 public contractStartTime;

    address constant TITANX_ADDRESS =
        0xF19308F923582A6f7c465e5CE7a9Dc1BEC6665B1;
    address public taxFeeAddress;
    address public routerAddress = 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD;

    mapping(GenesisTokens => uint256) public genesis;

    // enums
    enum GenesisTokens {
        KINGX,
        TITANX
    }

    event Mint(address indexed user, uint256 amount, uint256 rate);
    event UniFactoryUpdated(
        address oldUniswapFactory,
        address newUniswapFactory
    );
    event RouterUpdated(address oldRouterAddress, address newRouterAddress);
    event TitanXUpdated(address oldTitanxAddress, address newTitanxAddress);
    event DistributionOfRewards(
        uint256 distributedRewardsInKingX,
        uint256 distributedRewardsInTitanX
    );

    modifier onlyOwner() {
        require(
            msg.sender == HELLWHALE_OWNER ||
                msg.sender == DANIEL_KOZIARA_OWNER ||
                msg.sender == KRONOS_OWNER,
            "Not an owner"
        );
        _;
    }

    constructor(
        address _buyAndBurnAddress,
        address _initialLpAddress,
        address _uniswapFactoryAddress
    ) ERC20("KINGX", "KINGX") {
        require(
            _buyAndBurnAddress != address(0),
            "BuyAndBurnAddress cannot be the zero address"
        );
        require(
            _initialLpAddress != address(0),
            "InitialLpAddress cannot be the zero address"
        );
        require(
            _uniswapFactoryAddress != address(0),
            "UniswapFactoryAddress cannot be the zero address"
        );

        titanX = IERC20(TITANX_ADDRESS);
        buyAndBurnAddress = _buyAndBurnAddress;
        initialLpAddress = _initialLpAddress;
        contractStartTime = block.timestamp + 1 hours;
        taxFeeAddress = address(this);
        uniswapFactoryAddress = _uniswapFactoryAddress;

        v3Factory = IUniswapV3Factory(_uniswapFactoryAddress);

        // Mint and send 20B tokens for INITIAL_LP_ACCOUNT
        _mint(initialLpAddress, 20e9 * 1e18);
    }

    function setUniswapRouter(address _router) external onlyOwner {
        require(_router != address(0));
        address oldRouter = routerAddress;
        routerAddress = _router;
        emit RouterUpdated(oldRouter, _router);
    }

    function setTitanX(address _titanX) external onlyOwner {
        require(_titanX != address(0));
        address oldTitanx = address(titanX);
        titanX = IERC20(_titanX);
        emit TitanXUpdated(oldTitanx, _titanX);
    }

    function transfer(
        address to,
        uint256 value
    ) public override returns (bool) {
        uint256 valueAfterTax = value;

        if (
            to == routerAddress ||
            msg.sender == routerAddress ||
            isUniswapV3PoolToken0(msg.sender) ||
            isUniswapV3PoolToken1(msg.sender) ||
            isUniswapV3PoolToken0(to) ||
            isUniswapV3PoolToken1(to)
        ) {
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

        if (
            from == routerAddress ||
            to == routerAddress ||
            msg.sender == routerAddress ||
            isUniswapV3PoolToken0(msg.sender) ||
            isUniswapV3PoolToken1(msg.sender) ||
            isUniswapV3PoolToken0(from) ||
            isUniswapV3PoolToken1(from) ||
            isUniswapV3PoolToken0(to) ||
            isUniswapV3PoolToken1(to)
        ) {
            uint256 taxFee = calculateTaxFee(value);
            valueAfterTax = value - taxFee;

            genesis[GenesisTokens.KINGX] += taxFee;
            super.transferFrom(from, taxFeeAddress, taxFee);
        }
        super.transferFrom(from, to, valueAfterTax);

        return true;
    }

    function calculateTaxFee(uint256 amount) private pure returns (uint256) {
        return (amount * taxFeePercentBps) / 10000;
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

        titanX.safeTransferFrom(msg.sender, address(this), genesisAmount);
        genesis[GenesisTokens.TITANX] += genesisAmount;

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

    function distributeGenesisRewards() external {
        uint256 totalAmountKingX = genesis[GenesisTokens.KINGX];
        uint256 totalAmountTitanX = genesis[GenesisTokens.TITANX];

        uint256 distributedRewardsInKingX = 0;
        uint256 distributedRewardsInTitanX = 0;

        if (totalAmountKingX > 0) {
            uint256 amountKingxForDaniel = totalAmountKingX / 2; // 50% for Daniel
            uint256 amountKingxForOthers = totalAmountKingX / 4; // 25% for others

            distributedRewardsInKingX +=
                amountKingxForDaniel +
                (amountKingxForOthers * 2);

            transfer(DANIEL_KOZIARA_OWNER, amountKingxForDaniel);
            transfer(HELLWHALE_OWNER, amountKingxForOthers);
            transfer(KRONOS_OWNER, amountKingxForOthers);

            genesis[GenesisTokens.KINGX] = 0;
        }

        if (totalAmountTitanX > 0) {
            uint256 amountTitanxForDaniel = totalAmountTitanX / 2; // 50% for Daniel
            uint256 amountTitanxForOthers = totalAmountTitanX / 4; // 25% for others

            distributedRewardsInTitanX +=
                amountTitanxForDaniel +
                (amountTitanxForOthers * 2);

            titanX.safeTransfer(DANIEL_KOZIARA_OWNER, amountTitanxForDaniel);
            titanX.safeTransfer(HELLWHALE_OWNER, amountTitanxForOthers);
            titanX.safeTransfer(KRONOS_OWNER, amountTitanxForOthers);

            genesis[GenesisTokens.TITANX] = 0;
        }

        emit DistributionOfRewards(
            distributedRewardsInKingX,
            distributedRewardsInTitanX
        );
    }

    function setUniswapFactory(address _uniFactory) external onlyOwner {
        require(_uniFactory != address(0));
        address oldUniswapFactory = uniswapFactoryAddress;
        uniswapFactoryAddress = _uniFactory;
        emit UniFactoryUpdated(oldUniswapFactory, _uniFactory);
    }

    function isUniswapV3PoolToken0(address target) private view returns (bool) {
        if (target.code.length == 0) {
            return false;
        }

        IUniswapV3Pool poolContract = IUniswapV3Pool(target);
        address token0;
        address token1;
        uint24 fee;

        try poolContract.token0() returns (address _token0) {
            if (_token0 != address(this)) {
                return false;
            }

            token0 = _token0;
        } catch (bytes memory) {
            return false;
        }

        try poolContract.token1() returns (address _token1) {
            token1 = _token1;
        } catch (bytes memory) {
            return false;
        }

        try poolContract.fee() returns (uint24 _fee) {
            fee = _fee;
        } catch (bytes memory) {
            return false;
        }

        return target == v3Factory.getPool(token0, token1, fee);
    }

    function isUniswapV3PoolToken1(address target) private view returns (bool) {
        if (target.code.length == 0) {
            return false;
        }

        IUniswapV3Pool poolContract = IUniswapV3Pool(target);

        address token0;
        address token1;
        uint24 fee;

        try poolContract.token0() returns (address _token0) {
            if (token0 != address(this)) {
                return false;
            }

            token0 = _token0;
        } catch (bytes memory) {
            return false;
        }

        try poolContract.token1() returns (address _token1) {
            if (_token1 != address(this)) {
                return false;
            }

            token1 = _token1;
        } catch (bytes memory) {
            return false;
        }

        try poolContract.fee() returns (uint24 _fee) {
            fee = _fee;
        } catch (bytes memory) {
            return false;
        }

        return target == v3Factory.getPool(token0, token1, fee);
    }
}
