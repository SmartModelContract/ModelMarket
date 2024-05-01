const marketplaceContractABI = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "modelID",
        type: "string",
      },
      {
        indexed: false,
        internalType: "string",
        name: "targetRequestID",
        type: "string",
      },
      {
        indexed: false,
        internalType: "string",
        name: "modelIPFS",
        type: "string",
      },
    ],
    name: "ModelAccepted",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "modelID",
        type: "string",
      },
      {
        indexed: false,
        internalType: "string",
        name: "targetRequestID",
        type: "string",
      },
      {
        indexed: false,
        internalType: "address",
        name: "trainer",
        type: "address",
      },
    ],
    name: "ModelSubmitted",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "requestID",
        type: "string",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "status",
        type: "uint256",
      },
    ],
    name: "RequestClosed",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "requestID",
        type: "string",
      },
      {
        indexed: false,
        internalType: "address",
        name: "requester",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "timeout",
        type: "uint256",
      },
    ],
    name: "RequestCreated",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "requestID",
        type: "string",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "timeout",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "status",
        type: "uint256",
      },
    ],
    name: "RequestUpdated",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "modelID",
        type: "string",
      },
      {
        indexed: false,
        internalType: "string",
        name: "targetRequestID",
        type: "string",
      },
    ],
    name: "SubmissionCanceled",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "requestID",
        type: "string",
      },
    ],
    name: "cancelRequest",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "modelID",
        type: "string",
      },
    ],
    name: "cancelSubmission",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "modelID",
        type: "string",
      },
      {
        internalType: "string",
        name: "modelIPFS",
        type: "string",
      },
      {
        internalType: "uint256[]",
        name: "prediction",
        type: "uint256[]",
      },
    ],
    name: "candidateUpload",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "requestID",
        type: "string",
      },
      {
        internalType: "uint256",
        name: "reward",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "trainerStake",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "submissionWindow",
        type: "uint256",
      },
      {
        internalType: "string",
        name: "context",
        type: "string",
      },
      {
        internalType: "string",
        name: "trainingIPFS",
        type: "string",
      },
      {
        internalType: "string",
        name: "unlabeledTestingIPFS",
        type: "string",
      },
      {
        internalType: "string",
        name: "groundTruthSHA",
        type: "string",
      },
      {
        internalType: "uint256",
        name: "testDataSize",
        type: "uint256",
      },
    ],
    name: "createRequest",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "requestID",
        type: "string",
      },
    ],
    name: "enforceTimeout",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "requestID",
        type: "string",
      },
    ],
    name: "pickCandidate",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "modelID",
        type: "string",
      },
      {
        internalType: "uint256",
        name: "accuracy",
        type: "uint256",
      },
    ],
    name: "submitAccuracy",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "targetRequestID",
        type: "string",
      },
      {
        internalType: "string",
        name: "modelID",
        type: "string",
      },
      {
        internalType: "string",
        name: "modelSuperhash",
        type: "string",
      },
      {
        internalType: "string",
        name: "predictionSHA",
        type: "string",
      },
    ],
    name: "submitModel",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "requestID",
        type: "string",
      },
      {
        internalType: "uint256[]",
        name: "groundTruth",
        type: "uint256[]",
      },
    ],
    name: "uploadGroundTruth",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "contract ModelCoin",
        name: "modelCoinAddress",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "requestID",
        type: "string",
      },
    ],
    name: "getRequest",
    outputs: [
      {
        components: [
          {
            internalType: "address",
            name: "requester",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "reward",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "trainerStake",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "deadline",
            type: "uint256",
          },
          {
            internalType: "string",
            name: "context",
            type: "string",
          },
          {
            internalType: "string",
            name: "trainingIPFS",
            type: "string",
          },
          {
            internalType: "string",
            name: "unlabeledTestingIPFS",
            type: "string",
          },
          {
            internalType: "string",
            name: "groundTruthSHA",
            type: "string",
          },
          {
            internalType: "uint256",
            name: "testDataSize",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "status",
            type: "uint256",
          },
          {
            internalType: "address",
            name: "blameworthy",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "timeout",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "canceledCount",
            type: "uint256",
          },
          {
            internalType: "uint256[]",
            name: "groundTruth",
            type: "uint256[]",
          },
          {
            internalType: "string",
            name: "candidateModel",
            type: "string",
          },
        ],
        internalType: "struct MLModelMarketplace.ModelRequest",
        name: "",
        type: "tuple",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "requestID",
        type: "string",
      },
    ],
    name: "getStatus",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "modelID",
        type: "string",
      },
    ],
    name: "getSubmission",
    outputs: [
      {
        components: [
          {
            internalType: "address",
            name: "trainer",
            type: "address",
          },
          {
            internalType: "string",
            name: "targetRequestID",
            type: "string",
          },
          {
            internalType: "string",
            name: "modelSuperhash",
            type: "string",
          },
          {
            internalType: "string",
            name: "predictionSHA",
            type: "string",
          },
          {
            internalType: "uint256",
            name: "claimedAccuracy",
            type: "uint256",
          },
          {
            internalType: "string",
            name: "modelIPFS",
            type: "string",
          },
          {
            internalType: "uint256[]",
            name: "prediction",
            type: "uint256[]",
          },
        ],
        internalType: "struct MLModelMarketplace.ModelSubmission",
        name: "",
        type: "tuple",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "modelCoin",
    outputs: [
      {
        internalType: "contract ModelCoin",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    name: "requests",
    outputs: [
      {
        internalType: "address",
        name: "requester",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "reward",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "trainerStake",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "deadline",
        type: "uint256",
      },
      {
        internalType: "string",
        name: "context",
        type: "string",
      },
      {
        internalType: "string",
        name: "trainingIPFS",
        type: "string",
      },
      {
        internalType: "string",
        name: "unlabeledTestingIPFS",
        type: "string",
      },
      {
        internalType: "string",
        name: "groundTruthSHA",
        type: "string",
      },
      {
        internalType: "uint256",
        name: "testDataSize",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "status",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "blameworthy",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "timeout",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "canceledCount",
        type: "uint256",
      },
      {
        internalType: "string",
        name: "candidateModel",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "responseWindow",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    name: "submissions",
    outputs: [
      {
        internalType: "address",
        name: "trainer",
        type: "address",
      },
      {
        internalType: "string",
        name: "targetRequestID",
        type: "string",
      },
      {
        internalType: "string",
        name: "modelSuperhash",
        type: "string",
      },
      {
        internalType: "string",
        name: "predictionSHA",
        type: "string",
      },
      {
        internalType: "uint256",
        name: "claimedAccuracy",
        type: "uint256",
      },
      {
        internalType: "string",
        name: "modelIPFS",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
];
