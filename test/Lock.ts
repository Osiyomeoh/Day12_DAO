import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("DAO", function () {
  async function deployDAOFixture() {
    const [owner, otherAccount] = await hre.ethers.getSigners();

    const GovernanceToken = await hre.ethers.getContractFactory("GovernanceToken");
    const governanceToken = await GovernanceToken.deploy();

    const DAO = await hre.ethers.getContractFactory("DAO");
    const dao = await DAO.deploy(governanceToken.target);

    return { dao, governanceToken, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should set the right governance token", async function () {
      const { dao, governanceToken } = await loadFixture(deployDAOFixture);
      expect(await dao.governanceToken()).to.equal(governanceToken.target);
    });
  });

  describe("Proposal Creation", function () {
    it("Should create a proposal", async function () {
      const { dao, governanceToken, owner } = await loadFixture(deployDAOFixture);
      const description = "Test Proposal";
      const targetContract = await dao.getAddress();
      const callData = dao.interface.encodeFunctionData("setQuorum", [100]);

      await expect(dao.createProposal(description, targetContract, callData))
        .to.emit(dao, "ProposalCreated")
        .withArgs(1, owner.address, description);

      const proposal = await dao.getProposal(1);
      expect(proposal.description).to.equal(description);
    });

    it("Should revert if non-token holder tries to create a proposal", async function () {
      const { dao, otherAccount } = await loadFixture(deployDAOFixture);
      const description = "Test Proposal";
      const targetContract = await dao.getAddress();
      const callData = dao.interface.encodeFunctionData("setQuorum", [100]);

      await expect(dao.connect(otherAccount).createProposal(description, targetContract, callData))
        .to.be.revertedWith("Must hold governance tokens");
    });
  });

  describe("Voting", function () {
    it("Should allow token holders to vote", async function () {
      const { dao, governanceToken, owner } = await loadFixture(deployDAOFixture);
      const description = "Test Proposal";
      const targetContract = await dao.getAddress();
      const callData = dao.interface.encodeFunctionData("setQuorum", [100]);

      await dao.createProposal(description, targetContract, callData);

      await expect(dao.vote(1, true))
        .to.emit(dao, "Voted")
        .withArgs(1, owner.address, true, await governanceToken.balanceOf(owner.address));
    });

    it("Should revert if voting period has ended", async function () {
      const { dao, owner } = await loadFixture(deployDAOFixture);
      const description = "Test Proposal";
      const targetContract = await dao.getAddress();
      const callData = dao.interface.encodeFunctionData("setQuorum", [100]);

      await dao.createProposal(description, targetContract, callData);

      await time.increase(4 * 24 * 60 * 60); // Increase time by 4 days

      await expect(dao.vote(1, true)).to.be.revertedWith("Voting period has ended");
    });
  });

  describe("Proposal Execution", function () {
    it("Should execute a passed proposal", async function () {
      const { dao, governanceToken, owner } = await loadFixture(deployDAOFixture);
      const description = "Set Quorum";
      const targetContract = await dao.getAddress();
      const newQuorum = 100;
      const callData = dao.interface.encodeFunctionData("setQuorum", [newQuorum]);

      await dao.createProposal(description, targetContract, callData);
      await dao.vote(1, true);

      await time.increase(4 * 24 * 60 * 60); // Increase time by 4 days

      await expect(dao.executeProposal(1))
        .to.emit(dao, "ProposalExecuted")
        .withArgs(1);

      expect(await dao.quorum()).to.equal(newQuorum);
    });

    it("Should revert if proposal didn't pass", async function () {
      const { dao, governanceToken, owner } = await loadFixture(deployDAOFixture);
      const description = "Set Quorum";
      const targetContract = await dao.getAddress();
      const callData = dao.interface.encodeFunctionData("setQuorum", [100]);

      await dao.createProposal(description, targetContract, callData);
      await dao.vote(1, false);

      await time.increase(4 * 24 * 60 * 60); // Increase time by 4 days

      await expect(dao.executeProposal(1)).to.be.revertedWith("Proposal did not pass");
    });
  });
});