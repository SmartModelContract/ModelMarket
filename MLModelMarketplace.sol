// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ModelCoin.sol"; // Import the ModelCoin contract

contract MLModelMarketplace {
    // Use SafeERC20 to prevent reentrancy attacks
    using SafeERC20 for ModelCoin;

    ModelCoin public modelCoin;
    // ----------------- Model Request -----------------
    struct ModelRequest {
        address requester;
        uint256 reward;
        string context;
        string IPFSTraining;
        string IPFSTestingNoLabels;
        string SHALabels;
    }
    // ----------------- Model Submission -----------------
    struct ModelSubmission {
        address uploader;
        string correspondingRequestID;
        string SHAIPFSModel;
        string SHAIPFSGuesses;
    }
    // ----------------- Establish Variables -----------------
    mapping(string => ModelRequest) public requests; // Keep track of requests (w/ id, reward, collateral, hashes, etc.)
    mapping(string => ModelSubmission) public submissions; // keep track of submissions (hashes)
    mapping(string => string[]) private submissionsForRequest; // for slashing purposes.


    event RequestCreated(address requester, uint256 reward, string requestID, string context, string IPFSTraining, string IPFSTestingNoLabels, string SHALabels); // request event
    event ModelSubmitted(address uploader, string correspondingRequestID, string modelID, string SHAIPFSModel, string SHAIPFSGuesses); // submission event

    constructor(ModelCoin modelCoinAddress) {
        modelCoin = modelCoinAddress;
    }

    function createRequest(uint256 reward, string calldata requestID, string calldata context, string calldata IPFSTraining, string calldata IPFSTestingNoLabels, string calldata SHALabels) external {
        require(modelCoin.transferFrom(msg.sender, address(this), reward*2), "Transfer failed"); // transfer reward and collateral from requestor to contract
        requests[requestID] = ModelRequest({
            requester: msg.sender,
            reward: reward,
            context: context,
            IPFSTraining: IPFSTraining,
            IPFSTestingNoLabels: IPFSTestingNoLabels,
            SHALabels: SHALabels
        });
        emit RequestCreated(msg.sender, reward, requestID, context, IPFSTraining, IPFSTestingNoLabels, SHALabels);
    }
    // now prompt 15 minute time lock for submissions to come in

    function submitModel( string calldata correspondingRequestID, string calldata modelID, string calldata SHAIPFSModel, string calldata SHAIPFSGuesses) external {
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

    function submitRequestorLabels(string calldata requestID, string calldata IPFSLabels) external {
        ModelRequest memory request = requests[requestID];

        // Check if the caller is the requester of the original request
        require(msg.sender == request.requester, "Only the requester can call this function.");

        // Check if the SHA-256 hash of IPFSLabels matches the stored SHALabels for the request
        if (keccak256(abi.encodePacked(IPFSLabels)) != keccak256(abi.encodePacked(request.SHALabels))) {
            // Logic to distribute the reward among all submissions if the hashes do not match
            // Assuming the existence of a function 'distributeRewards' to handle reward distribution
            slash(request.reward, requestID);
            modelCoin.transfer(msg.sender, request.reward);
        }
        // Additional logic for what happens if the hashes match (not specified in your requirements)
    }

    function slash(uint256 reward, string memory requestID) private {
        // Retrieve the array of model IDs submitted for the given requestID
        string[] memory modelIDs = submissionsForRequest[requestID];

        // Calculate the reward share for each submitter
        uint256 numberOfSubmitters = modelIDs.length;
        if (numberOfSubmitters == 0) return; // If no submissions, exit function

        uint256 rewardPerSubmitter = reward / numberOfSubmitters;

        // Distribute the reward to each submitter
        for (uint256 i = 0; i < numberOfSubmitters; i++) {
            address submitter = submissions[modelIDs[i]].uploader;
            require(modelCoin.transfer(submitter, rewardPerSubmitter), "Failed to transfer reward");
        }
    }


    function getRequest(string calldata requestID) external view returns (ModelRequest memory) {
        return requests[requestID];
    }

    function getSubmission(string calldata modelID) external view returns (ModelSubmission memory) {
        return submissions[modelID];
    }
}
