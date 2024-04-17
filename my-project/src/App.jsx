import React, { useState, useEffect } from "react";
import { ethers } from "ethers";
import detectEthereumProvider from "@metamask/detect-provider";
import { contractABI } from "./abi";
import "./App.css";
import loadingGif from "./assets/loading.gif"; // Ensure this path is correct

const contractAddress = "0x1e33DaE11dcd6197259673C286C1F56e75A46A18";

const App = () => {
  const [contract, setContract] = useState(null);
  const [loading, setLoading] = useState(false);
  const [inputString, setInputString] = useState("");
  const [txHash, setTxHash] = useState("");
  const [latestString, setLatestString] = useState("");

  useEffect(() => {
    const initApp = async () => {
      const ethereumProvider = await detectEthereumProvider();
      if (ethereumProvider) {
        try {
          // Request account access if needed
          await ethereumProvider.request({ method: "eth_requestAccounts" });
          // We use the state setters here directly to avoid variable shadowing
          const tempProvider = new ethers.providers.Web3Provider(
            ethereumProvider,
          );
          const tempSigner = tempProvider.getSigner();
          const tempContract = new ethers.Contract(
            contractAddress,
            contractABI,
            tempSigner,
          );
          setContract(tempContract);

          // Event listener for the smart contract
          tempContract.on("StringSubmitted", (newString, index) => {
            setLatestString(
              `New string recorded on the blockchain: ${newString} at index ${index}`,
            );
          });
        } catch (error) {
          console.error("Error initializing app:", error);
        }
      } else {
        console.error("Please install MetaMask!");
      }
    };

    initApp();

    // Cleanup function
    return () => {
      if (contract) {
        // Remove listener when the component is unmounted
        contract.removeAllListeners("StringSubmitted");
      }
    };
  }, [contract]);

  const submitString = async () => {
    if (!contract) {
      console.error("The contract is not initialized.");
      return;
    }

    setLoading(true);
    try {
      const txResponse = await contract.submitString(inputString);
      await txResponse.wait();
      console.log("Transaction submitted!");
      console.log("Transaction hash:", txResponse.hash);
      setTxHash(`Transaction Hash: ${txResponse.hash}`);
    } catch (error) {
      console.error("Error submitting string:", error);
    } finally {
      setLoading(false);
    }
  };

  const displayLatestText = async () => {
    try {
      const latestString = await contract.getLastString();
      console.log("Latest string from the blockchain:", latestString);
      setLatestString(`Latest String: ${latestString}`);
    } catch (error) {
      console.error("Error fetching the latest string:", error);
    }
  };

  return (
    <div className="container">
      <div className="contract-info">
        <h2>Contract Location</h2>
        <p>
          This DApp is connected to a smart contract on the Ethereum testnet:{" "}
          <a href="https://sepolia.etherscan.io/address/0x1e33DaE11dcd6197259673C286C1F56e75A46A18">
            {" "}
            0x1e33DaE11dcd6197259673C286C1F56e75A46A18{" "}
          </a>{" "}
        </p>
        <h3>Contract Description</h3>
        <p>
          This page allows the storage and retrieval of a string. Users can
          submit a string to the contract, which is then stored on the
          blockchain. Anyone can read the latest string submitted.
        </p>
      </div>
      <input
        type="text"
        value={inputString}
        onChange={(e) => setInputString(e.target.value)}
        placeholder="Enter a string..."
      />
      {loading && (
        <div id="loadingIndicator">
          <img src={loadingGif} alt="Loading..." width="64" height="64" />
        </div>
      )}
      <button
        onClick={submitString}
        id="submitStringButton"
        disabled={!contract}
      >
        Submit String
      </button>

      {txHash && <div id="txHashDisplay">{txHash}</div>}
      <button onClick={displayLatestText} id="fetchLatestStringButton">
        Fetch Latest String
      </button>
      {latestString && <div id="latestStringDisplay">{latestString}</div>}
    </div>
  );
};

export default App;
