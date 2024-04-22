require('dotenv').config();
const express = require('express');
const multer = require('multer');
const { ThirdwebStorage } = require("@thirdweb-dev/storage");
const fs = require("fs");
const path = require('path');

const app = express();
const upload = multer({ dest: 'uploads/' }); 

const storage = new ThirdwebStorage({
    secretKey: 'M_vQncADV0Cri8YUxGvgrIS_2hhS2dbTML7ciOyfztllbgKnNd4EBr8uyEB7WQXffgqMlFP533zu4Xis36jntg'
});

app.post('/upload_full', upload.single('file'), async (req, res) => {
    try {
        const tempPath = req.file.path;
        
        const fileData = fs.readFileSync(tempPath);

        const uploadResult = await storage.upload(fileData);
        const gatewayUrl = storage.resolveScheme(uploadResult);
        
        res.json({ message: "File uploaded successfully to IPFS.", url: gatewayUrl });

        fs.unlinkSync(tempPath);
    } catch (error) {
        console.error('Upload to IPFS failed:', error);
        res.status(500).send("Failed to upload file to IPFS.");
    }
});

app.post('/upload_train_test_weights', upload.single('file'), async (req, res) => {
    try {
        const tempPath = req.file.path;
        
        const fileData = fs.readFileSync(tempPath);

        const uploadResult = await storage.upload(fileData);
        const gatewayUrl = storage.resolveScheme(uploadResult);
        
        res.json({ message: "File uploaded successfully to IPFS.", url: gatewayUrl });

        fs.unlinkSync(tempPath);
    } catch (error) {
        console.error('Upload to IPFS failed:', error);
        res.status(500).send("Failed to upload file to IPFS.");
    }
});

//FOR MULTIPLE FILES: not needed rn

app.post('/upload', upload.fields([{name: 'file', maxCount : 1}, { name: 'training', maxCount: 1 }, { name: 'testing', maxCount: 1 }]), async (req, res) => {
    try {
        const files = req.files;
        console.log(files); 


        const fileDataArray = [files.file[0], files.training[0], files.testing[0]].map(file => fs.readFileSync(file.path));
        const uploadResults = await storage.uploadBatch(fileDataArray);
        const gatewayUrls = uploadResults.map(upload => storage.resolveScheme(upload));

        res.json({
            message: "Files uploaded successfully to IPFS.",
            urls: gatewayUrls
        });


        fileDataArray.forEach(file => fs.unlinkSync(file.path));
    } catch (error) {
        console.error('Upload to IPFS failed:', error);
        res.status(500).send("Failed to upload files to IPFS.");
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on http://localhost:${PORT}`));

// IF IPFS DOES NOT WORK SWITCH TO HEILA
/*
const express = require('express');
const multer = require('multer');
const cors = require('cors');
const path = require('path');

const app = express();
const upload = multer();
app.use(cors()); // Enable CORS if client is on a different origin
app.use(express.json());
let hashMap = new Map

async function createNode(){
    const {createHelia} = await import('helia');
    const {unixfs} = await import('@helia/unixfs');
    const helia = await createHelia();
    const fs = unixfs(helia);
    return fs;
}

app.post('/upload', upload.single('file'), async (req, res) => {
    console.log('Uploaded file:', req.file);
    const fs = await createNode();
    const data = req.file.buffer;
    const cid = await fs.addBytes(data);
    hashMap.set(req.file.originalname, cid)
    res.status(201).send("successful")
    res.json({ message: 'File uploaded successfully', fileName: req.file.filename });
});

app.get('/fetch', async (req, res)=> {
    const fs = await createNode();
    const filename = req.body.filename;
    const cid = hashMap.get(filename);
    if (!cid) {
        res.status(404).send('no file')
    }
    let text;
    const decoder = new TextDecoder()

    for await(const chunks of fs.cat(cid)){
        text = decoder.decode(chunks, {stream: true})
    }

    res.status(200).send(text)
});
    

// Start the server
const PORT = 3000;
app.listen(PORT, () => console.log(`Server running on http://localhost:${PORT}`));

*/
