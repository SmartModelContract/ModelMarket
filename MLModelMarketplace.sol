// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ModelCoin.sol"; // Import the ModelCoin contract

contract MLModelMarketplace {

    // ------- ModelCoin -------
    using SafeERC20 for ModelCoin; // to prevent reentrancy attacks
    ModelCoin public modelCoin;
    constructor(ModelCoin modelCoinAddress) {
        modelCoin = modelCoinAddress;
    }


    // ----------------- Model Request -----------------
    struct ModelRequest {               //TODO: populate update!
        address constant requester;
        uint256 constant reward;
        uint256 constant collateral;
        uint256 constant deadline;      // timestamp of submission closure
        string constant datasetHash;    // testing data must be unlabeled!
        uint256 constant testDataCount; // number of testing data
        string constant context;        // relevant instructions / info

        // Tracking Status Codes:
        // ---------------------
        // 0 - Open (Accepting Submissions / Awaiting Ground Truth)
        // 1 - Accepting Accuracy Claims / Awaiting Candidate Selection
        // 2 - Awaiting Model Upload
        // 3 - Validation Success (Transaction Complete)
        // 4 - Refunded (No Valid Submissions)
        // 5 - Cancelled by Requester
        // 6 - Requester Punished for Taking Too Long
        // ---------------------

        uint256 status;             // current status code
        uint256 timeout;            // timestamp when contract will revert
        uint256 submissionCount;    // total number of submissions
        uint256 validSubmissions;   // submissions remaining

        // Ground Truth
        bool hasGroundTruth;
        uint256[] groundTruth;

        // Candidate Selection
        bool candidateSelected;
        address candidate;          // responsible for preventing timeout
        uint256 primeSubmission;
    }


    // ----------------- Model Submission -----------------
    struct ModelSubmission {                // TODO: populate update!
        address constant trainer;

        // Tracking Status
        bool isCanceled;

        // Submission Payload
        string constant modelHash;
        string constant predictionHash;
        uint256 claimedAccuracy;    // # of testing data correctly categorized
        string[] prediction;        // predicted testing data labels
    }


    // ----------------- Establish Variables -----------------
    mapping(uint256 => ModelRequest) public requests; // Keep track of requests (w/ id, reward, collateral, hashes, etc.)
    mapping(uint256 => ModelSubmission[]) public submissions; // keep track of submissions (hashes)

    uint256 public requestCount;
    uint256 public responseWindow = 1200;  // twenty minutes (in seconds)

    // TODO UPDATE!
    event RequestCreated(uint256 requestId, address requester, uint256 reward, uint256 collateral, string trainingDataHash, string testingDataHash); // request event
    event ModelSubmitted(uint256 requestId, string modelHash, address contributor); // submission event


    // -------------- External View Functions ---------------
    function getRequest(uint256 requestId) external view returns (ModelRequest memory) {
        return requests[requestId];
    }

    function listSubmissions(uint256 requestId) external view returns (ModelSubmission[] memory) {
        return submissions[requestId];
    }

    function getSubmission(uint256 requestId, uint256 submissionIndex) external view returns (ModelSubmission memory) {
        return submissions[requestId][submissionIndex];
    }


    // ------------- Internal Utility Functions ---------------
    function eqs(string s1, string s2) internal returns (bool) {
        // checks string equality
        if (bytes(s1).length != bytes(s2).length) {
            return false;
        } else {
            return keccak256(abi.encodePacked(s1)) == keccak256(abi.encodePacked(s2));
        }
    }




    // Protocol Operation Functions TODO: update!!!
    function createRequest(uint256 reward, uint256 collateral, string calldata context, string calldata trainingDataHash, string calldata testingDataHash) external {
        require(modelCoin.transferFrom(msg.sender, address(this), reward + collateral), "Transfer failed"); // transfer reward and collateral from requester to contract
        uint256 requestId = ++requestCount;
        requests[requestId] = ModelRequest({
            requester: msg.sender,
            reward: reward,
            collateral: collateral,
            context: context,
            trainingDataHash: trainingDataHash,
            testingDataHash: testingDataHash,
            status: 0
        });
        hasRequested[msg.sender] = true;
        emit RequestCreated(requestId, msg.sender, reward, collateral, trainingDataHash, testingDataHash);
    }

    function submitModel(uint256 requestId, string[] calldata modelHashes) external {
        ModelRequest request = requests[requestId];

        require(block.timestamp < request.deadline, "Submissions are closed.");
        require(!request.status == "Open", "This request has been canceled.");

        submissions[requestId][request.submissionCount] = ModelSubmission({
            modelHashes: modelHashes,
            contributor: msg.sender,
            isSubmitted: true
        });

        requests[requestId].submissionCount++;
        //emit ModelSubmitted(requestId, modelHashes, msg.sender);
    }

    // COMPLETE!
    function uploadGroundTruth(uint256 requestId, string[] calldata groundTruth) external {
        ModelRequest request = requests[requestId];

        require(msg.sender == request.requester, "Only the requester can upload ground truth testing labels!");
        require(!request.hasGroundTruth, "The ground truth has already been uploaded.");
        require(request.status == "Open", "You let the contract time out! Sorry.");
        require(block.timestamp >= request.deadline, "It is too early to upload the ground truth! Wait until the submission deadline.");

        requests[requestId].groundTruth = groundTruth;
        requests[requestId].hasGroundTruth = true;
    }


    function fulfillRequest(uint256 requestId) external {
        require(msg.sender == requests[requestId].requester, "Only requester can fulfill");
        require(submissions[requestId].isSubmitted, "No model submitted yet");
        requests[requestId].isFulfilled = true;
        modelCoin.transfer(submissions[requestId].contributor, requests[requestId].reward);
        modelCoin.transfer(requests[requestId].requester, requests[requestId].collateral);
        emit RequestFulfilled(requestId, submissions[requestId].modelHashes, submissions[requestId].contributor);
    }

    function resetTimeout(uint256 requestId) internal {
        requests[requestId].timeout = block.timestamp + responseWindow;
    }

    // VERY IMPORTANT: KEEP INTERNAL/PRIVATE!
    function pickCandidate(uint256 requestId, address target) internal {
        requests[requestId].candidate = target;
        resetTimeout;
    }



    //function cancelSubmission(uint256 requestId)

    function cancelRequest(uint256 requestId) external returns (string memory) {
        address requester = requests[requestId].requester;
        uint256 timeout = requests[requestId].timeout;

      //  if(msg.sender == requester) {

      //  }

        require((msg.sender == requester) || (block.timestamp > timeout), "You cannot cancel this request unless it times out.");

        address candidate = requests[requestId].candidate;

        if (requester == candidate) {

            // keep requester's collateral

            // TODO: distribute reward equally among trainers

            requests[requestId].status = "Canceled";
            return "Request marked as Canceled.";
        } else {


            requests[requestId].status = "Timed Out";
            return "Request marked as Timed Out.";
        }

    }

}
