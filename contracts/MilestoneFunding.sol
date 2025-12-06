// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MilestoneFunding {
    uint256 public projectCount;

    enum ProjectStatus { Funding, Active, Cancelled, Completed }

    struct Milestone {
        string description;
        uint256 amount;
        bool isCompleted; 
        bool isApproved;  
        bool isPaid;     
    }

    struct Project {
        address owner;
        address approver;
        uint256 totalFundingRequired;
        uint256 totalFunded;
        ProjectStatus status;
        Milestone[] milestones;
        mapping(address => uint256) contributions; // how much each address funded
    }

    mapping(uint256 => Project) private projects;

    //  Events 

    event ProjectCreated(
        uint256 indexed projectId,
        address indexed owner,
        address indexed approver,
        uint256 totalFundingRequired
    );

    event ProjectFunded(
        uint256 indexed projectId,
        address indexed funder,
        uint256 amount,
        uint256 newTotalFunded
    );

    event MilestoneCompleted(
        uint256 indexed projectId,
        uint256 indexed milestoneIndex
    );

    event MilestoneApproved(
        uint256 indexed projectId,
        uint256 indexed milestoneIndex
    );

    event MilestonePaid(
        uint256 indexed projectId,
        uint256 indexed milestoneIndex,
        uint256 amount
    );

    event ProjectCancelled(uint256 indexed projectId);

    event RefundClaimed(
        uint256 indexed projectId,
        address indexed funder,
        uint256 amount
    );

    //  Modifiers 

    modifier onlyProjectOwner(uint256 projectId) {
        require(
            msg.sender == projects[projectId].owner,
            "Only project owner"
        );
        _;
    }

    modifier onlyApprover(uint256 projectId) {
        require(
            msg.sender == projects[projectId].approver,
            "Only approver"
        );
        _;
    }

    modifier validProject(uint256 projectId) {
        require(projectId > 0 && projectId <= projectCount, "Invalid project");
        _;
    }

    constructor() {}

    //  Core read functions 

    function getProject(
        uint256 projectId
    )
        external
        view
        validProject(projectId)
        returns (
            address owner,
            address approver,
            uint256 totalFundingRequired,
            uint256 totalFunded,
            ProjectStatus status,
            uint256 milestonesCount
        )
    {
        Project storage p = projects[projectId];
        owner = p.owner;
        approver = p.approver;
        totalFundingRequired = p.totalFundingRequired;
        totalFunded = p.totalFunded;
        status = p.status;
        milestonesCount = p.milestones.length;
    }

    function getMilestone(
        uint256 projectId,
        uint256 milestoneIndex
    )
        external
        view
        validProject(projectId)
        returns (
            string memory description,
            uint256 amount,
            bool isCompleted,
            bool isApproved,
            bool isPaid
        )
    {
        Project storage p = projects[projectId];
        require(milestoneIndex < p.milestones.length, "Invalid milestone index");
        Milestone storage m = p.milestones[milestoneIndex];

        description = m.description;
        amount = m.amount;
        isCompleted = m.isCompleted;
        isApproved = m.isApproved;
        isPaid = m.isPaid;
    }

    function getContribution(
        uint256 projectId,
        address funder
    ) external view validProject(projectId) returns (uint256) {
        return projects[projectId].contributions[funder];
    }

    //  Project creation 

    function createProject(
        address _approver,
        uint256 _totalFundingRequired,
        string[] calldata _descriptions,
        uint256[] calldata _amounts
    ) external {
        require(_approver != address(0), "Invalid approver");
        require(_totalFundingRequired > 0, "Funding must be > 0");
        require(_descriptions.length == _amounts.length, "Length mismatch");
        require(_descriptions.length > 0, "Need at least 1 milestone");

        projectCount += 1;
        uint256 projectId = projectCount;

        Project storage p = projects[projectId];
        p.owner = msg.sender;
        p.approver = _approver;
        p.totalFundingRequired = _totalFundingRequired;
        p.status = ProjectStatus.Funding;

        uint256 sum;
        for (uint256 i = 0; i < _amounts.length; i++) {
            p.milestones.push(
                Milestone({
                    description: _descriptions[i],
                    amount: _amounts[i],
                    isCompleted: false,
                    isApproved: false,
                    isPaid: false
                })
            );
            sum += _amounts[i];
        }

        require(sum == _totalFundingRequired, "Milestones sum != total");

        emit ProjectCreated(projectId, p.owner, p.approver, p.totalFundingRequired);
    }

    //  Funding 

    /**
     * @dev Fund a project while it's in the Funding state.
     *      When totalFunded reaches totalFundingRequired, project moves to Active.
     */
    function fundProject(
        uint256 projectId
    ) external payable validProject(projectId) {
        require(msg.value > 0, "Must send some ETH");

        Project storage p = projects[projectId];

        require(p.status == ProjectStatus.Funding, "Project not fundable");

        uint256 newTotal = p.totalFunded + msg.value;
        require(newTotal <= p.totalFundingRequired, "Exceeds funding goal");

        p.totalFunded = newTotal;
        p.contributions[msg.sender] += msg.value;

        if (p.totalFunded == p.totalFundingRequired) {
            p.status = ProjectStatus.Active;
        }

        emit ProjectFunded(projectId, msg.sender, msg.value, p.totalFunded);
    }

    //  Milestone lifecycle 

    /**
     * @dev Owner marks a milestone as completed (work done).
     */
    function markMilestoneCompleted(
        uint256 projectId,
        uint256 milestoneIndex
    ) external validProject(projectId) onlyProjectOwner(projectId) {
        Project storage p = projects[projectId];
        require(p.status == ProjectStatus.Active, "Project not active");
        require(milestoneIndex < p.milestones.length, "Invalid milestone index");

        Milestone storage m = p.milestones[milestoneIndex];
        require(!m.isCompleted, "Already completed");

        m.isCompleted = true;

        emit MilestoneCompleted(projectId, milestoneIndex);
    }

    /**
     * @dev Approver verifies and approves a completed milestone.
     */
    function approveMilestone(
        uint256 projectId,
        uint256 milestoneIndex
    ) external validProject(projectId) onlyApprover(projectId) {
        Project storage p = projects[projectId];
        require(p.status == ProjectStatus.Active, "Project not active");
        require(milestoneIndex < p.milestones.length, "Invalid milestone index");

        Milestone storage m = p.milestones[milestoneIndex];
        require(m.isCompleted, "Milestone not completed");
        require(!m.isApproved, "Already approved");

        m.isApproved = true;

        emit MilestoneApproved(projectId, milestoneIndex);
    }

    /**
     * @dev Owner withdraws funds for an approved milestone.
     */
    function releaseMilestoneFunds(
        uint256 projectId,
        uint256 milestoneIndex
    ) external validProject(projectId) onlyProjectOwner(projectId) {
        Project storage p = projects[projectId];
        require(p.status == ProjectStatus.Active, "Project not active");
        require(milestoneIndex < p.milestones.length, "Invalid milestone index");

        Milestone storage m = p.milestones[milestoneIndex];
        require(m.isApproved, "Milestone not approved");
        require(!m.isPaid, "Already paid");
        require(address(this).balance >= m.amount, "Insufficient contract balance");

        m.isPaid = true;

        (bool sent, ) = payable(p.owner).call{value: m.amount}("");
        require(sent, "Payment failed");

        emit MilestonePaid(projectId, milestoneIndex, m.amount);

        if (_allMilestonesPaid(p)) {
            p.status = ProjectStatus.Completed;
        }
    }

    function _allMilestonesPaid(Project storage p) internal view returns (bool) {
        for (uint256 i = 0; i < p.milestones.length; i++) {
            if (!p.milestones[i].isPaid) {
                return false;
            }
        }
        return true;
    }

    //  Cancel + Refund 

    /**
     * @dev Owner can cancel the project while still in Funding state.
     *      No milestones should be paid yet (by design they can't be).
     *      Contributors can then claim refunds.
     */
    function cancelProject(
        uint256 projectId
    ) external validProject(projectId) onlyProjectOwner(projectId) {
        Project storage p = projects[projectId];
        require(p.status == ProjectStatus.Funding, "Can only cancel during funding");

        p.status = ProjectStatus.Cancelled;

        emit ProjectCancelled(projectId);
    }

    /**
     * @dev Funder claims back their contribution after cancellation.
     */
    function claimRefund(
        uint256 projectId
    ) external validProject(projectId) {
        Project storage p = projects[projectId];
        require(p.status == ProjectStatus.Cancelled, "Project not cancelled");

        uint256 contribution = p.contributions[msg.sender];
        require(contribution > 0, "Nothing to refund");

        p.contributions[msg.sender] = 0;

        require(address(this).balance >= contribution, "Insufficient contract balance");

        (bool sent, ) = payable(msg.sender).call{value: contribution}("");
        require(sent, "Refund failed");

        emit RefundClaimed(projectId, msg.sender, contribution);
    }
}