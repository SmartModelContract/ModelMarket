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
        uint256 created;
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
        uint256 correctGuesses;
    }

    // ----------------- Establish Variables -----------------
    mapping(string => ModelRequest) public requests; // Keep track of requests (w/ id, reward, collateral, hashes, etc.)
    mapping(string => ModelSubmission) public submissions; // keep track of submissions (hashes)
    mapping(string => string[]) private submissionsForRequest; // for slashing purposes.
    mapping(string => TopScorer) private topScorers; // to keep track who has best model
    address private constant dAppAddress = 0x02190Df4Bb86893e8f543673ccBacCCC752f020d;



    event RequestCreated(address requester, uint256 reward, string requestID, string context, string IPFSTraining, string IPFSTestingNoLabels, string SHALabels); // request event
    event ModelSubmitted(address uploader, string correspondingRequestID, string modelID, string SHAIPFSModel, string SHAIPFSGuesses); // submission event
    event NewTopScorer(string modelID, string requestID, uint256 correctGuesses);
    event FetchDataForVerification(string IPFSGuesses);
    event VerificationFailure(string modelID, string message);
    event FinalVerificationSuccess(string modelID, uint256 matchesCount);

    constructor(ModelCoin modelCoinAddress) {
        modelCoin = modelCoinAddress;
    }

    function createRequest(uint256 reward, string calldata requestID, string calldata context, string calldata IPFSTraining, string calldata IPFSTestingNoLabels, string calldata SHALabels) external {
    require(modelCoin.transferFrom(msg.sender, address(this), reward*2), "Transfer failed");
        requests[requestID] = ModelRequest({
            requester: msg.sender,
            reward: reward,
            context: context,
            IPFSTraining: IPFSTraining,
            IPFSTestingNoLabels: IPFSTestingNoLabels,
            SHALabels: SHALabels,
            created: block.timestamp // Set the creation time
        });
        emit RequestCreated(msg.sender, reward, requestID, context, IPFSTraining, IPFSTestingNoLabels, SHALabels);
    }

    // now prompt 15 minute time lock for submissions to come in

    function submitModel(string calldata correspondingRequestID, string calldata modelID, string calldata SHAIPFSModel, string calldata SHAIPFSGuesses) external {
    require(requests[correspondingRequestID].requester != address(0), "Request does not exist");
        require(block.timestamp <= requests[correspondingRequestID].created + 15 minutes, "Submission period has ended"); // Enforce the 15-minute time lock

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
        if (keccak256(abi.encodePacked(IPFSLabels)) != keccak256(abi.encodePacked(request.SHALabels))) { // check if this keccak256 is necessary
            // If malicious labels, then requestor lose all money
            slash(request.reward * 2, requestID);
        } else {
            // if good, give collateral back
            modelCoin.transfer(msg.sender, request.reward);
        }
    }

    function slash(uint256 slashReward, string memory requestID) private {
        // Retrieve the array of model IDs submitted for the given requestID
        string[] memory modelIDs = submissionsForRequest[requestID];

        // Calculate the reward share for each submitter
        uint256 numberOfSubmitters = modelIDs.length;
        if (numberOfSubmitters == 0) return; // If no submissions, exit function

        uint256 rewardPerSubmitter = slashReward / numberOfSubmitters;

        // Distribute the reward to each submitter
        for (uint256 i = 0; i < numberOfSubmitters; i++) {
            address submitter = submissions[modelIDs[i]].uploader;
            require(modelCoin.transfer(submitter, rewardPerSubmitter), "Failed to transfer reward");
        }
    }

    function submitGuesses(string calldata modelID, uint256 correctGuesses) external { // send money back forgot
        ModelSubmission storage submission = submissions[modelID];
        require(msg.sender == submission.uploader, "Caller is not the uploader of this model");

        TopScorer storage currentTopScorer = topScorers[submission.correspondingRequestID];

        if (correctGuesses > currentTopScorer.correctGuesses) {
            currentTopScorer.uploader = msg.sender;
            currentTopScorer.modelID = modelID;
            currentTopScorer.correctGuesses = correctGuesses;

            // the collateral will be the reward for the request to be top scorer
            require(modelCoin.transferFrom(msg.sender, address(this), requests[submission.correspondingRequestID].reward), "Failed to transfer collateral");

            emit NewTopScorer(modelID, submission.correspondingRequestID, correctGuesses);
        }
    }

    // implement timelock again

    function submitVerify(string calldata modelID, string calldata IPFSModel, string calldata IPFSGuesses) external returns (bool) {
        ModelSubmission storage submission = submissions[modelID];
        require(msg.sender == topScorers[submission.correspondingRequestID].uploader, "Caller is not the top scorer");

        bool modelMatches = keccak256(abi.encodePacked(IPFSModel)) == keccak256(abi.encodePacked(submission.SHAIPFSModel)); // these too
        bool guessesMatches = keccak256(abi.encodePacked(IPFSGuesses)) == keccak256(abi.encodePacked(submission.SHAIPFSGuesses));

        if (modelMatches && guessesMatches) {
            emit FetchDataForVerification(IPFSGuesses);
            return true;
        } else {
            emit VerificationFailure(modelID, "Verification failed");
            return false;
        }
    }

    function finalVerification(string calldata modelID, string[] calldata guesses, string[] calldata labels) external {
        require(msg.sender == dAppAddress, "Unauthorized: caller is not the dApp");
        ModelSubmission storage submission = submissions[modelID];
        require(guesses.length == labels.length, "Input arrays must be of equal length");

        uint256 matchesCount = 0;
        for (uint256 i = 0; i < guesses.length; i++) {
            if (keccak256(abi.encodePacked(guesses[i])) == keccak256(abi.encodePacked(labels[i]))) { // check
                matchesCount++;
            }
        }

        require(matchesCount == topScorers[submission.correspondingRequestID].correctGuesses, "Match count does not align with the top scorer's claim");

        // Fetch the reward from the request
        ModelRequest storage request = requests[submission.correspondingRequestID];
        uint256 rewardAmount = request.reward * 2;  // Calculate double reward

        // Transfer the reward to the top scorer
        modelCoin.safeTransfer(submission.uploader, rewardAmount);

        emit FinalVerificationSuccess(modelID, matchesCount);
    }




    function getRequest(string calldata requestID) external view returns (ModelRequest memory) {
        return requests[requestID];
    }

    function getSubmission(string calldata modelID) external view returns (ModelSubmission memory) {
        return submissions[modelID];
    }
}
