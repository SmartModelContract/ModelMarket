const marketplaceContractABI = [
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
        internalType: "address",
        name: "target",
        type: "address",
      },
    ],
    name: "AddressEmptyCode",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "AddressInsufficientBalance",
    type: "error",
  },
  {
    inputs: [],
    name: "FailedInnerCall",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "token",
        type: "address",
      },
    ],
    name: "SafeERC20FailedOperation",
    type: "error",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "string",
        name: "IPFSGuesses",
        type: "string",
      },
    ],
    name: "FetchDataForVerification",
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
    ],
    name: "FinalVerificationSuccess",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "uploader",
        type: "address",
      },
      {
        indexed: false,
        internalType: "string",
        name: "correspondingRequestID",
        type: "string",
      },
      {
        indexed: false,
        internalType: "string",
        name: "modelID",
        type: "string",
      },
      {
        indexed: false,
        internalType: "string",
        name: "SHAIPFSModel",
        type: "string",
      },
      {
        indexed: false,
        internalType: "string",
        name: "SHAIPFSGuesses",
        type: "string",
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
        name: "modelID",
        type: "string",
      },
    ],
    name: "NewTopScorer",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "requester",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "reward",
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
        name: "modelID",
        type: "string",
      },
      {
        indexed: false,
        internalType: "string",
        name: "message",
        type: "string",
      },
    ],
    name: "VerificationFailure",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "reward",
        type: "uint256",
      },
      {
        internalType: "string",
        name: "requestID",
        type: "string",
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
        name: "modelID",
        type: "string",
      },
    ],
    name: "finalVerification",
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
            name: "uploader",
            type: "address",
          },
          {
            internalType: "string",
            name: "correspondingRequestID",
            type: "string",
          },
          {
            internalType: "string",
            name: "SHAIPFSModel",
            type: "string",
          },
          {
            internalType: "string",
            name: "SHAIPFSGuesses",
            type: "string",
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
        name: "uploader",
        type: "address",
      },
      {
        internalType: "string",
        name: "correspondingRequestID",
        type: "string",
      },
      {
        internalType: "string",
        name: "SHAIPFSModel",
        type: "string",
      },
      {
        internalType: "string",
        name: "SHAIPFSGuesses",
        type: "string",
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
    name: "submitGuesses",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "string",
        name: "correspondingRequestID",
        type: "string",
      },
      {
        internalType: "string",
        name: "modelID",
        type: "string",
      },
      {
        internalType: "string",
        name: "SHAIPFSModel",
        type: "string",
      },
      {
        internalType: "string",
        name: "SHAIPFSGuesses",
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
    ],
    name: "submitRequestorLabels",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];
