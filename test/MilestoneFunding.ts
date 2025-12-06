import { expect } from "chai";
import hre from "hardhat";

// Hardhat 3 pattern: get ethers from a connected network instance
const { ethers } = await hre.network.connect();

describe("MilestoneFunding", function () {
  let contract: any;
  let deployer: any;
  let owner: any;
  let approver: any;
  let funder1: any;
  let funder2: any;

  const projectId = 1;

  beforeEach(async () => {
    // Get test accounts
    [deployer, owner, approver, funder1, funder2] = await ethers.getSigners();

    // Deploy the contract (first signer = deployer)
    contract = await ethers.deployContract("MilestoneFunding");
    await contract.waitForDeployment();

    // Create a sample project with 2 milestones (called by owner)
    const totalFundingRequired = ethers.parseEther("3"); // 3 ETH total
    const descriptions = ["Design", "Development"];
    const amounts = [ethers.parseEther("1"), ethers.parseEther("2")]; // 1 + 2 = 3

    await contract
      .connect(owner)
      .createProject(approver.address, totalFundingRequired, descriptions, amounts);
  });

  // ---------- Positive tests ----------

  it("creates project with correct data", async () => {
    const [
      projOwner,
      projApprover,
      totalFundingRequired,
      totalFunded,
      status,
      milestonesCount,
    ] = await contract.getProject(projectId);

    expect(projOwner).to.equal(owner.address);
    expect(projApprover).to.equal(approver.address);
    expect(totalFundingRequired).to.equal(ethers.parseEther("3"));
    expect(totalFunded).to.equal(0n);
    // ProjectStatus.Funding = 0
    expect(status).to.equal(0);
    expect(milestonesCount).to.equal(2n);
  });

  it("allows funding up to the goal and moves project to Active", async () => {
    // funder1 sends 1 ETH
    await contract
      .connect(funder1)
      .fundProject(projectId, { value: ethers.parseEther("1") });

    // funder2 sends 2 ETH
    await contract
      .connect(funder2)
      .fundProject(projectId, { value: ethers.parseEther("2") });

    const [, , , totalFunded, status] = await contract.getProject(projectId);

    expect(totalFunded).to.equal(ethers.parseEther("3"));
    // ProjectStatus.Active = 1
    expect(status).to.equal(1);
  });

  it("lets owner complete, approver approve, and owner withdraw milestone funds", async () => {
    // Fully fund the project first
    await contract
      .connect(funder1)
      .fundProject(projectId, { value: ethers.parseEther("3") });

    // Owner marks milestone 0 completed
    await contract.connect(owner).markMilestoneCompleted(projectId, 0);

    // Approver approves milestone 0
    await contract.connect(approver).approveMilestone(projectId, 0);

    // Check milestone state before payment
    let [desc, amount, isCompleted, isApproved, isPaid] =
      await contract.getMilestone(projectId, 0);
    expect(isCompleted).to.equal(true);
    expect(isApproved).to.equal(true);
    expect(isPaid).to.equal(false);

    // Contract balance before withdrawal
    const contractAddress = await contract.getAddress();
    const before = await ethers.provider.getBalance(contractAddress);

    // Owner releases funds for milestone 0
    await contract.connect(owner).releaseMilestoneFunds(projectId, 0);

    // Contract balance after withdrawal
    const after = await ethers.provider.getBalance(contractAddress);

    // Contract should have sent `amount` out
    expect(before - after).to.equal(amount);

    // Milestone should now be paid
    [desc, amount, isCompleted, isApproved, isPaid] =
      await contract.getMilestone(projectId, 0);
    expect(isPaid).to.equal(true);
  });

  it("allows cancel during funding and refund to funder", async () => {
    // Fund partially (1 ETH)
    await contract
      .connect(funder1)
      .fundProject(projectId, { value: ethers.parseEther("1") });

    // Owner cancels project (still in Funding state)
    await contract.connect(owner).cancelProject(projectId);

    // Funder claims refund
    const before = await ethers.provider.getBalance(funder1.address);

    const tx = await contract.connect(funder1).claimRefund(projectId);
    const receipt = await tx.wait();
    const gasUsed = receipt!.gasUsed * (receipt!.gasPrice ?? 0n);

    const after = await ethers.provider.getBalance(funder1.address);

    // after + gasUsed - before ≈ refunded amount
    expect(after + BigInt(gasUsed) - before).to.equal(ethers.parseEther("1"));

    // Contribution should now be zero
    const contribution = await contract.getContribution(
      projectId,
      funder1.address
    );
    expect(contribution).to.equal(0n);
  });

  // ---------- Negative tests ----------

  it("does not allow non-owner to mark milestone completed", async () => {
    // Fully fund to move to Active
    await contract
      .connect(funder1)
      .fundProject(projectId, { value: ethers.parseEther("3") });

    // Non-owner tries to mark completed
    await expect(
      contract.connect(funder1).markMilestoneCompleted(projectId, 0)
    ).to.be.revertedWith("Only project owner");
  });

  it("does not allow approver to approve before completion", async () => {
    // Fully fund to move to Active
    await contract
      .connect(funder1)
      .fundProject(projectId, { value: ethers.parseEther("3") });

    // Approver tries to approve directly
    await expect(
      contract.connect(approver).approveMilestone(projectId, 0)
    ).to.be.revertedWith("Milestone not completed");
  });

  it("prevents funding beyond goal", async () => {
    // Fully fund with first tx (3 ETH)
    await contract
      .connect(funder1)
      .fundProject(projectId, { value: ethers.parseEther("3") });

    // Try to fund again (project is Active now, not Funding)
    await expect(
      contract
        .connect(funder2)
        .fundProject(projectId, { value: ethers.parseEther("1") })
    ).to.be.revertedWith("Project not fundable");
  });

  it("prevents refund when project is not cancelled", async () => {
    // Fund some ETH
    await contract
      .connect(funder1)
      .fundProject(projectId, { value: ethers.parseEther("1") });

    // Try refund without cancellation
    await expect(
      contract.connect(funder1).claimRefund(projectId)
    ).to.be.revertedWith("Project not cancelled");
  });

  it("prevents double refund", async () => {
    await contract
      .connect(funder1)
      .fundProject(projectId, { value: ethers.parseEther("1") });

    await contract.connect(owner).cancelProject(projectId);

    // First refund OK
    await contract.connect(funder1).claimRefund(projectId);

    // Second refund should fail
    await expect(
      contract.connect(funder1).claimRefund(projectId)
    ).to.be.revertedWith("Nothing to refund");
  });
});
