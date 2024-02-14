const { expect } = require("chai");
const { ethers } = require("hardhat");

const TITANX_ADDRESS = "0xF19308F923582A6f7c465e5CE7a9Dc1BEC6665B1";
const SWAP_ROUTER_ADDRESS = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const routerAddress = '0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD';

describe("MintInPeriod", function () {
    let kingXToken;
    let owner;
    let titanXToken;

    beforeEach(async function () {
        [owner, addr1, ...addrs] = await ethers.getSigners();

        const SwapHelperFactory = await ethers.getContractFactory("SwapHelper");
        swapHelper = await SwapHelperFactory.deploy(SWAP_ROUTER_ADDRESS, WETH_ADDRESS);

        KingX = await ethers.getContractFactory("KingX");
        kingXToken = await KingX.deploy(owner.address, addr1, routerAddress);

        titanXToken = await ethers.getContractAt("ITitanX", TITANX_ADDRESS);

        await swapHelper.connect(owner).swapETHForTITANX({ value: ethers.parseEther("1000") });
        const titanXBalance = await titanXToken.balanceOf(owner.address);
        await titanXToken.connect(owner).approve(await kingXToken.getAddress(), titanXBalance);
    });

    it("should mint decreasing amounts of KINGX over time until the end of minting period", async function () {
        this.timeout(300_000); // 5 min for test
        const initialTitanXBalance = ethers.parseEther("1000");
        await titanXToken.transfer(owner.address, initialTitanXBalance);
        await titanXToken.connect(owner).approve(await kingXToken.getAddress(), initialTitanXBalance);

        let lastMintAmount;
        for (let hour = 1; hour <= 17 * 24; hour++) {
            await ethers.provider.send("evm_increaseTime", [3600]);
            await ethers.provider.send("evm_mine");

            const tx = await kingXToken.connect(owner).mint(ethers.parseEther("1"));
            await tx.wait();
            const filter = kingXToken.filters.Mint(owner.address);
            const events = await kingXToken.queryFilter(filter, "latest");

            const mintAmount = events[0].args.amount;
            // console.log(`Hour: ${hour}, minted kingx: ${mintAmount}`);
            if (lastMintAmount) {
                expect(mintAmount).to.be.at.most(lastMintAmount);
            }
            lastMintAmount = mintAmount;

            if (hour > 17 * 24) {
                await expect(kingXToken.connect(owner).mint(ethers.parseEther("1")))
                    .to.be.revertedWith("KingX_Minting: Minting period has ended");
                break;
            }
        }
    });
});
