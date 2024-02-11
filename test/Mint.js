const { expect } = require("chai");
const { ethers } = require("hardhat");

const TITANX_ADDRESS = "0xF19308F923582A6f7c465e5CE7a9Dc1BEC6665B1";
const SWAP_ROUTER_ADDRESS = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";


const HELLWHALE_OWNER = "0x8add03eafe6E89Cc28726f8Bb91096C2dE139fFb";
const DANIEL_KOZIARA_OWNER = "0x7e603e457d8C0D61351111614ad977315Dfc77aa";
const KRONOS_OWNER = "0x9FEAcbaf3C4277bC9438759058E9E334f866992a";

const GenesisTokens = {
    KINGX: 0,
    TITANX: 1,
}

describe("Mint", function () {
    let swapHelper;
    let owner;
    let addr1;
    let titanXToken;


    beforeEach(async function () {
        [owner, addr1, ...addrs] = await ethers.getSigners();

        const SwapHelperFactory = await ethers.getContractFactory("SwapHelper");
        swapHelper = await SwapHelperFactory.deploy(SWAP_ROUTER_ADDRESS, WETH_ADDRESS);

        KingX = await ethers.getContractFactory("KingX");
        kingXToken = await KingX.deploy(owner.address, addr1);

        titanXToken = await ethers.getContractAt("ITitanX", TITANX_ADDRESS);

    });

    it("should have more than 0 TITANX after swap", async function () {

        const swapAmount = ethers.parseEther("1");
        const swapTx = await swapHelper.swapETHForTITANX({ value: swapAmount });
        await swapTx.wait();

        const balance = await titanXToken.balanceOf(owner.address);
        expect(balance).to.be.gt(0);
    });

    it("should not allow minting before contract start time", async function () {

        const swapAmount = ethers.parseEther("1");
        await titanXToken.transfer(owner.address, swapAmount);

        await titanXToken.connect(owner).approve(await kingXToken.getAddress(), swapAmount);

        await expect(
            kingXToken.connect(owner).mint(swapAmount)
        ).to.be.revertedWith("KingX_Minting: Minting not allowed yet");
    });

    it("should allow minting after contract start time and transfer correct amount of KINGX tokens", async function () {
        await ethers.provider.send("evm_increaseTime", [3600]);
        await ethers.provider.send("evm_mine");

        const swapAmount = ethers.parseEther("1");

        await titanXToken.connect(owner).approve(await kingXToken.getAddress(), swapAmount);

        await expect(kingXToken.connect(owner).mint(swapAmount))
            .to.emit(kingXToken, "Mint");

        const balanceAfter = await kingXToken.balanceOf(owner.address);
        expect(balanceAfter).to.be.gt(0);
    });


    it("should add TITANX tokens to genesis pool after minting", async function () {
        await ethers.provider.send("evm_increaseTime", [3600]);
        await ethers.provider.send("evm_mine");

        const swapAmount = ethers.parseEther("1");
        await titanXToken.connect(owner).approve(await kingXToken.getAddress(), swapAmount);

        const initialGenesisBalance = await kingXToken.genesis(1);

        await kingXToken.connect(owner).mint(swapAmount);

        const finalGenesisBalance = await kingXToken.genesis(1);

        const expectedGenesisAmount = swapAmount * 3n / 100n;

        expect(finalGenesisBalance - initialGenesisBalance).to.equal(expectedGenesisAmount);
    });

    it("should distribute genesis rewards correctly", async function () {
        await ethers.provider.send("evm_increaseTime", [3600]);
        await ethers.provider.send("evm_mine");

        const swapAmount = ethers.parseEther("1");
        await titanXToken.connect(owner).approve(await kingXToken.getAddress(), swapAmount);
        await kingXToken.connect(owner).mint(swapAmount);

        const balanceKingX = await titanXToken.balanceOf(await kingXToken.getAddress());
        expect(balanceKingX).to.be.gt(0);

        const totalGenesisRewards = await kingXToken.genesis(GenesisTokens.TITANX);

        const initialBalanceDaniel = await titanXToken.balanceOf(DANIEL_KOZIARA_OWNER);
        const initialBalanceHellwhale = await titanXToken.balanceOf(HELLWHALE_OWNER);
        const initialBalanceKronos = await titanXToken.balanceOf(KRONOS_OWNER);


        await kingXToken.connect(owner).distributeGenesisRewards(GenesisTokens.TITANX);


        const finalBalanceDaniel = await titanXToken.balanceOf(DANIEL_KOZIARA_OWNER);
        const finalBalanceHellwhale = await titanXToken.balanceOf(HELLWHALE_OWNER);
        const finalBalanceKronos = await titanXToken.balanceOf(KRONOS_OWNER);

        const expectedAmountDaniel = totalGenesisRewards / 2n;
        const expectedAmountOthers = totalGenesisRewards / 4n;

        expect(finalBalanceDaniel - initialBalanceDaniel).to.equal(expectedAmountDaniel);
        expect(finalBalanceHellwhale - initialBalanceHellwhale).to.equal(expectedAmountOthers);
        expect(finalBalanceKronos - initialBalanceKronos).to.equal(expectedAmountOthers);
    });


});
