const ethers = require("ethers");
const fs = require("fs");

async function main() {
  // Provider URL
  const provider = new ethers.providers.JsonRpcProvider(
    "http://127.0.0.1:7545",
  );

  // Private key must have '0x' prefix
  const wallet = new ethers.Wallet(
    "0x3a744f6bfc8d92ae80f4509b989ed8891d4a85f4f9b1209d29b585935a7ad75b",
    provider,
  );

  // Read ABI and binary files
  const abi = fs.readFileSync("./HelloWorld_sol_HelloWorld.abi", "utf8");
  const binary = fs.readFileSync("./HelloWorld_sol_HelloWorld.bin", "utf8");

  // Parse ABI if necessary and create contract factory
  const contractFactory = new ethers.ContractFactory(
    JSON.parse(abi),
    binary,
    wallet,
  );

  console.log("Deploying the contract... Please wait.");

  // Set gas limit for deployment
  const options = {
    gasLimit: 1000000, // You might need to adjust this value based on your contract's requirements
  };

  // Deploy the contract with specified gas limit
  const contract = await contractFactory.deploy(options);

  // Wait for the contract to be mined
  await contract.deployTransaction.wait();

  console.log("Contract deployed to address:", contract.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
