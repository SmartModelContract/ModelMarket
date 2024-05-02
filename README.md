# ModelMarket

ModelMarket is a decentralized application (dApp) designed to reward trainers for providing bespoke machine learning models on demand.

In this README, the term "superhash" will refer to the SHA256 digest of the hash receipt returned by Interplanetary Filesystem ([IPFS](https://www.ipfs.tech/)) upon uploading some data. Additionally, all users will be required to provide some stake of ModelCoin, a bespoke cryptocurrency designed to incentivize the ecosystem to behave properly. If deadlines or other key protocols are broken, these stakes will be slashed (claimed by the contract).

In broad strokes, SmartModel functions like this:

1) The requester uploads their request (including the whole dataset, deadline, reward, and context) to the Ethereum blockchain. Locally, the dApp randomly splits the dataset into testing and training data before uploading, **strips the testing data of labels**, then uploads the testing and **unlabeled** training data to IPFS. The resultant hashes are openly revealed on-chain, rendering the data available for public download, while only the superhash of the _labeled_ testing data (the ground truth) is uploaded (to lock it in, without yet allowing anyone to view it).A time lock function is activated, beginning a period of time within which any user can become a model "trainer" by fitting the released training data with an ML model. The requester may cancel the contract at any time. Before there are submissions, they may cancel with no penalty. After submissions have been uploaded, they forfeit the reward upon cancellation, and it is distributed between the trainers.

2) After training models, trainers upload the superhash of their trained ML model and the hash of their prediction (an array of fixed length, containing the results of the model when applied to the unlabeled testing data). Before the submission deadline, trainers can cancel their model submission without forfeiting collateral. After the deadline, they forfeit their collateral.

3) After submissions have closed, the requester must upload the **ground truth** (testing data labels) on-chain within the response window (set to 15 minutes). Once it is uploaded the timeout is reset, and trainers can easily compute the accuracy of their model by comparing their prediction to the ground truth. If the requester does not upload the ground truth in time, anyone may cancel the contract, causing the reward to be slashed.
		
4) After the ground truth is uploaded, trainers have **one submission window** to report the accuracy of their model on-chain. If trainers do not upload their accuracy in time, their submissions are canceled and they lose their collateral.

5) The core functionality of the protocol then ensues. The contract automatically selects the submission with the highest claimed accuracy. Within the response window, that model's trainer must upload their prediction (which is hashed and compared to the hash they uploaded previously, and cross-referenced with their reported accuracy), AND the IPFS hash of their model, which must correspond to the superhash from their initial submission. If their prediction and model hash do not check out, their submission is canceled, they lose their stake, the timeout is reset, a new candidate model is selected. If there are no uncanceled trainers remaining, the request is canceled, and the requester is refunded in full. If the blameworthy trainer times out, anyone may cancel their submission and trigger a new candidate selection.

6) If everything checks out from the previous step, the trainer is sent the reward! The request is now complete, and the model is publicly available.

While there are no technical checks to ensure that the superhash originally uploaded to the chain refers to the correct model, there is an economic incentive for trainers to upload the model which actually generated their prediction, since uploading the wrong data would detract from the reputation of the system, thereby causing the price of ModelCoin to drop. By providing a stake of ModelCoin, trainers are guaranteed to have some interest in maintaining the value of ModelCoin. Furthermore, since it is infeasible to generate an accurate prediction on the testing data without producing an appropriate ML model, uploading anything else would not provide any particular advantage to the model trainer—they would only do this to actively detract from the usefulness of the system, at their own personal expense (training ML models costs electricity).

![State Diagram: ModelMarket](https://github.com/SmartModelContract/ModelMarket/blob/main/Flowchart.png?raw=true)

## ModelMarket

ModelMarket is a decentralized application (dApp) designed to reward trainers for providing bespoke machine learning models on demand.

In this README, the term "superhash" will refer to the SHA256 digest of the hash receipt returned by Interplanetary Filesystem ([IPFS](https://www.ipfs.tech/)) upon uploading some data. Additionally, all users will be required to provide some stake of ModelCoin, a bespoke cryptocurrency designed to incentivize the ecosystem to behave properly. If deadlines or other key protocols are broken, these stakes will be slashed (claimed by the contract).

In broad strokes, SmartModel functions like this:

1) The requester uploads their request (including the whole dataset, deadline, reward, and context) to the Ethereum blockchain. Locally, the dApp randomly splits the dataset into testing and training data before uploading, **strips the testing data of labels**, then uploads the testing and **unlabeled** training data to IPFS. The resultant hashes are openly revealed on-chain, rendering the data available for public download, while only the superhash of the _labeled_ testing data (the ground truth) is uploaded (to lock it in, without yet allowing anyone to view it).A time lock function is activated, beginning a period of time within which any user can become a model "trainer" by fitting the released training data with an ML model. The requester may cancel the contract at any time. Before there are submissions, they may cancel with no penalty. After submissions have been uploaded, they forfeit the reward upon cancellation, and it is distributed between the trainers.

2) After training models, trainers upload the superhash of their trained ML model and the hash of their prediction (an array of fixed length, containing the results of the model when applied to the unlabeled testing data). Before the submission deadline, trainers can cancel their model submission without forfeiting collateral. After the deadline, they forfeit their collateral.

3) After submissions have closed, the requester must upload the **ground truth** (testing data labels) on-chain within the response window (set to 15 minutes). Once it is uploaded the timeout is reset, and trainers can easily compute the accuracy of their model by comparing their prediction to the ground truth. If the requester does not upload the ground truth in time, anyone may cancel the contract, causing the reward to be slashed.
		
4) After the ground truth is uploaded, trainers have **one submission window** to report the accuracy of their model on-chain. If trainers do not upload their accuracy in time, their submissions are canceled and they lose their collateral.

5) The core functionality of the protocol then ensues. The contract automatically selects the submission with the highest claimed accuracy. Within the response window, that model's trainer must upload their prediction (which is hashed and compared to the hash they uploaded previously, and cross-referenced with their reported accuracy), AND the IPFS hash of their model, which must correspond to the superhash from their initial submission. If their prediction and model hash do not check out, their submission is canceled, they lose their stake, the timeout is reset, a new candidate model is selected. If there are no uncanceled trainers remaining, the request is canceled, and the requester is refunded in full. If the blameworthy trainer times out, anyone may cancel their submission and trigger a new candidate selection.

6) If everything checks out from the previous step, the trainer is sent the reward! The request is now complete, and the model is publicly available.

While there are no technical checks to ensure that the superhash originally uploaded to the chain refers to the correct model, there is an economic incentive for trainers to upload the model which actually generated their prediction, since uploading the wrong data would detract from the reputation of the system, thereby causing the price of ModelCoin to drop. By providing a stake of ModelCoin, trainers are guaranteed to have some interest in maintaining the value of ModelCoin. Furthermore, since it is infeasible to generate an accurate prediction on the testing data without producing an appropriate ML model, uploading anything else would not provide any particular advantage to the model trainer—they would only do this to actively detract from the usefulness of the system, at their own personal expense (training ML models costs electricity).

If you have any questions about the intended operation of this protocol, please contact the developers.

![State Diagram: ModelMarket](https://github.com/SmartModelContract/ModelMarket/blob/main/Flowchart.png?raw=true)

## File Descriptions for running the dApp in MNIST folder
mnist.csv: dataset to upload as first form parameter for "Model Requesting"

mnist_labels.csv: dataset to upload as first form parameter for "Model Requesting"

mnist_labels_test.csv: dataset to upload as first form paramter for "Model Uploading"

mnist_model_example.h5: an example model for classifying the MNIST dataset, upload as second form paramter for "Model Uploading" (although the exact contents of the file uploaded at this parameter are uploaded)

## How to Run

### 1. Install dependencies and node
```bash
npm install
npm update
```
### 2. Create a [thirdweb](https://thirdweb.com/) api key and replace your key in server.js
Or use our key
```javascript
const storage = new ThirdwebStorage({
    secretKey: 'replace with your key'
});
```

### 3. Launch the dApp
```bash
node server.js
python3 -m http.server
```

### 4. Pair with Wallet
Make sure you are signed into your metamask wallet, click the (Connect to Metamask) button to connect to the wallet.

## Interacting with the dApp.
### 1. Airdrop 1000 MDC from the airdrop button.

### 2. "Model Requesting Form Parameters"

1) string: an ID to associate with the model
2) file: a full csv of data for model training purposes, can use ./MNIST/mnist.csv for testing
3) file: a full csv of data labels for model training purposes, can use ./MNIST/mnist_labels.csv for testing (must be same length as first param)
4) number: a reward for the model creation
5) context: any sort of information that may be necessary for model creation e.g. "classification, regression, etc." (not necessary for dApp functionality)
6) number: an expiration time for when models must be uploaded by in minutes (minimum of 1)


### "Model Uploading/Creation Form Paramters"

1) string: the model request ID specified by the model requester in the first form (a list of models requested will be populated on screen, this form value must be the ID specified by one of these requests)
2) string: the unique ID you want to associate to this model (as opposed to the request identifier this is the ID to associate to your exact model)
3) file: a full csv of data labels predicted by your model for the testing dataset, can use ./MNIST/mnist_labels_test.csv for testing (must be same length as the testing dataset, and although these labels are equivalent to the length of the testing data and can be submitted, the testing data is randomly split to not allow for malicious activities, so these labels are not going to be representative of the actual predictions any good ML model would make on the testing data, but is sufficient for the proof of concept)
4) file: the model contents you created for the request (can be an arbitrary file since this is not verified as previously expressed but can use ./MNIST/mnist_model_example.h5 if you desire)


### Notes

- Make sure to keep track of all the data prompted to you by the dApp (the dApp will be specific as to which contents you must keep track of, just copy and paste the values from the prompt and keep track of them somewhere)
- For calculating the number of correct 'predictions' you made with your model, instead of having to do the work of parsing the CSV of ground truth labels and your own testing labels just open up the console as we log the two seperate arrays here during the dApp's chain of events, copy and paste these two values into ./MNIST/array_comparison.py as the values for the variable arr1 and arr2, the result of 'correct predictions' is the value printed 



