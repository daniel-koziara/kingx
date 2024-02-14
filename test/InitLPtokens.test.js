const { expect } = require("chai");
const { ethers } = require("hardhat");
describe("KingX Token Deployment", function () {
    const routerAddress = '0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD';
    let KingX;
    let kingXToken;
    let owner;
    let addr1;
    let lpAddr;
    let addrs;

    beforeEach(async function () {
        [owner, addr1, lpAddr, ...addrs] = await ethers.getSigners();
        KingX = await ethers.getContractFactory("KingX");
        kingXToken = await KingX.deploy(owner.address, lpAddr, routerAddress);
    });

    it("should mint 20B KINGX tokens to the INITIAL_LP_ACCOUNT", async function () {
        const expectedBalance = ethers.parseUnits("20000000000", 18);
        expect(await kingXToken.balanceOf(lpAddr)).to.equal(expectedBalance);
    });
});
