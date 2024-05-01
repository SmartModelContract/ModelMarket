// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ModelCoin.sol"; // Import the ModelCoin contract

// 0x39ae2482B07c0538968C17E58de124DD39C0151E

contract MLModelMarketplace {
    // Use SafeERC20 to prevent reentrancy attacks
    using SafeERC20 for ModelCoin;

    ModelCoin public modelCoin;
    // ----------------- Model Request -----------------
    struct ModelRequest {
        address requester;
        uint256 reward;
    }

    // ----------------- Model Submission -----------------
    struct ModelSubmission {
        address uploader;
        string correspondingRequestID;
        string SHAIPFSModel;
        string SHAIPFSGuesses;
    }
    // ----------------- Logs who is top scorer -----------------
    struct TopScorer {
        address uploader;
        string modelID;
    }

    // ----------------- Establish Variables -----------------
    mapping(string => ModelRequest) public requests; // Keep track of requests (w/ id, reward, collateral, hashes, etc.)
    mapping(string => ModelSubmission) public submissions; // keep track of submissions (hashes)
    mapping(string => string[]) private submissionsForRequest; // for slashing purposes.
    mapping(string => TopScorer) private topScorers; // to keep track who has best model



    event RequestCreated(address requester, uint256 reward); // request event
    event ModelSubmitted(address uploader, string correspondingRequestID, string modelID, string SHAIPFSModel, string SHAIPFSGuesses); // submission event
    event NewTopScorer(string modelID);
    event FetchDataForVerification(string IPFSGuesses);
    event VerificationFailure(string modelID, string message);
    event FinalVerificationSuccess(string modelID);

    constructor(ModelCoin modelCoinAddress) {
        modelCoin = modelCoinAddress;
    }

    function createRequest(uint256 reward, string calldata requestID) external {
    require(modelCoin.transferFrom(msg.sender, address(this), reward*2), "Transfer failed");
        requests[requestID] = ModelRequest({
            requester: msg.sender,
            reward: reward
        });
        emit RequestCreated(msg.sender, reward);
    }

    // now prompt 15 minute time lock for submissions to come in

    function submitModel(string calldata correspondingRequestID, string calldata modelID, string calldata SHAIPFSModel, string calldata SHAIPFSGuesses) external {
        require(requests[correspondingRequestID].requester != address(0), "Request does not exist");
        submissions[modelID] = ModelSubmission({
            uploader: msg.sender,
            correspondingRequestID: correspondingRequestID,
            SHAIPFSModel: SHAIPFSModel,
            SHAIPFSGuesses: SHAIPFSGuesses
        });
        submissionsForRequest[correspondingRequestID].push(modelID);
        emit ModelSubmitted(msg.sender, correspondingRequestID, modelID, SHAIPFSModel, SHAIPFSGuesses);
    }


    // now prompt 15 minute time lock for requestor to upload the labels

    function submitRequestorLabels(string calldata requestID) external {
        ModelRequest memory request = requests[requestID];
        modelCoin.transfer(msg.sender, request.reward);
    }

    function submitGuesses(string calldata modelID) external {
        ModelSubmission storage submission = submissions[modelID];
        require(modelCoin.transferFrom(msg.sender, address(this), requests[submission.correspondingRequestID].reward), "Failed to transfer collateral");

        emit NewTopScorer(modelID);
    }

    // implement timelock again

    // function submitVerify(string calldata modelID, string calldata IPFSModel, string calldata IPFSGuesses) external returns (bool) {
    //     ModelSubmission storage submission = submissions[modelID];
    //     require(msg.sender == topScorers[submission.correspondingRequestID].uploader, "Caller is not the top scorer");

    //     bool modelMatches = keccak256(abi.encodePacked(IPFSModel)) == keccak256(abi.encodePacked(submission.SHAIPFSModel)); // these too
    //     bool guessesMatches = keccak256(abi.encodePacked(IPFSGuesses)) == keccak256(abi.encodePacked(submission.SHAIPFSGuesses));

    //     if (modelMatches && guessesMatches) {
    //         emit FetchDataForVerification(IPFSGuesses);
    //         return true;
    //     } else {
    //         emit VerificationFailure(modelID, "Verification failed");
    //         return false;
    //     }
    // }

    function finalVerification(string calldata modelID) external {

        ModelSubmission storage submission = submissions[modelID];
        // Fetch the reward from the request
        ModelRequest storage request = requests[submission.correspondingRequestID];
        uint256 rewardAmount = request.reward * 2;  // Calculate double reward

        // Transfer the reward to the top scorer
        modelCoin.safeTransfer(submission.uploader, rewardAmount);

        emit FinalVerificationSuccess(modelID);
    }




    function getRequest(string calldata requestID) external view returns (ModelRequest memory) {
        return requests[requestID];
    }

    function getSubmission(string calldata modelID) external view returns (ModelSubmission memory) {
        return submissions[modelID];
    }
}
